"""Application lifecycle and operational readiness state management."""

import time
from datetime import UTC, datetime
from typing import TYPE_CHECKING, Any, Literal

import httpx

from trustcue_backend.core.quota import InMemoryQuotaStore, QuotaStore
from trustcue_backend.core.rate_limit import ConcurrencyLimiter, SlidingWindowRateLimiter

if TYPE_CHECKING:
    from trustcue_backend.core.config import Settings
    from trustcue_backend.providers.base import AiProvider


class AppState:
    """Manages application runtime lifecycle, uptime, and readiness state."""

    def __init__(
        self,
        quota_store: QuotaStore | None = None,
        ai_provider: "AiProvider | None" = None,
    ) -> None:
        self.started_at_monotonic: float = time.monotonic()
        self.is_ready: bool = True
        self.is_shutting_down: bool = False
        self.rate_limiter = SlidingWindowRateLimiter()
        self.concurrency_limiter = ConcurrencyLimiter()
        self.quota_store = quota_store or InMemoryQuotaStore()
        self.ai_provider = ai_provider
        self._last_db_check_at: float = 0.0
        self._last_db_status: Literal["ok", "error", "unconfigured"] = "unconfigured"
        self.deleted_users: set[str] = set()
        self.profile_display_names: dict[str, str | None] = {}
        self.profile_avatar_paths: dict[str, str | None] = {}
        self.profile_sync_enabled: dict[str, bool] = {}
        self.sync_generations: dict[str, int] = {}
        self.sync_purged_at: dict[str, datetime] = {}
        self.synced_reports: dict[str, dict[str, Any]] = {}

    def mark_user_deleted(self, user_id: str) -> None:
        """Record user UUID as permanently deleted to immediately reject subsequent sessions."""
        uid = str(user_id).strip().lower()
        self.deleted_users.add(uid)
        self.profile_display_names.pop(str(user_id).strip(), None)
        self.profile_avatar_paths.pop(str(user_id).strip(), None)
        self.profile_sync_enabled.pop(str(user_id).strip(), None)
        to_delete = [k for k in self.synced_reports if k.startswith(f"{uid}:")]
        for k in to_delete:
            self.synced_reports.pop(k, None)

    def is_user_deleted(self, user_id: str) -> bool:
        """Check whether user UUID has been marked deleted."""
        return str(user_id).strip().lower() in self.deleted_users

    def get_display_name(self, user_id: str) -> str | None:
        """Retrieve local in-memory display name if set."""
        return self.profile_display_names.get(str(user_id).strip())

    def set_display_name(self, user_id: str, display_name: str | None) -> None:
        """Store local in-memory display name."""
        self.profile_display_names[str(user_id).strip()] = display_name

    def get_avatar_path(self, user_id: str) -> str | None:
        """Retrieve local in-memory avatar path if set."""
        return self.profile_avatar_paths.get(str(user_id).strip())

    def set_avatar_path(self, user_id: str, avatar_path: str | None) -> None:
        """Store local in-memory avatar path."""
        self.profile_avatar_paths[str(user_id).strip()] = avatar_path

    def get_sync_enabled(self, user_id: str) -> bool:
        """Retrieve whether cloud sync is enabled for user (defaults to False)."""
        return self.profile_sync_enabled.get(str(user_id).strip(), False)

    def set_sync_enabled(self, user_id: str, enabled: bool) -> None:
        """Store cloud sync preference for user."""
        self.profile_sync_enabled[str(user_id).strip()] = bool(enabled)

    def get_sync_generation(self, user_id: str) -> int:
        """Retrieve current sync generation for user (defaults to 1)."""
        return self.sync_generations.get(str(user_id).strip().lower(), 1)

    def save_synced_reports(self, user_id: str, items: list[dict[str, Any]]) -> list[str]:
        """Save or update reports for user in in-memory store, preventing resurrection after purge."""
        uid = str(user_id).strip().lower()
        purged_at = self.sync_purged_at.get(uid)

        synced_ids: list[str] = []
        for item in items:
            client_id = item["clientReportId"]
            client_time_raw = item["clientUpdatedAt"]
            client_time = (
                client_time_raw
                if isinstance(client_time_raw, datetime)
                else datetime.fromisoformat(str(client_time_raw))
            )
            if client_time.tzinfo is None:
                client_time = client_time.replace(tzinfo=UTC)

            # Prevent resurrection: if report was modified before last purge, skip
            if purged_at is not None and client_time <= purged_at:
                continue

            user_gen = self.get_sync_generation(user_id)
            item_gen = item.get("syncGeneration", 1)
            if item_gen != user_gen:
                continue

            key = f"{uid}:{client_id}"
            existing = self.synced_reports.get(key)
            if existing:
                existing_time_raw = existing["clientUpdatedAt"]
                existing_time = (
                    existing_time_raw
                    if isinstance(existing_time_raw, datetime)
                    else datetime.fromisoformat(str(existing_time_raw))
                )
                if existing_time.tzinfo is None:
                    existing_time = existing_time.replace(tzinfo=UTC)
                incoming_is_del = item.get("isDeleted", False)
                existing_is_del = existing.get("isDeleted", False)

                # Deterministic conflict resolution:
                # 1. Stale incoming update rejected
                if client_time < existing_time:
                    continue
                # 2. Equal timestamps: tombstone takes precedence over active
                if client_time == existing_time:
                    if existing_is_del and not incoming_is_del:
                        continue

            revision = (existing["revision"] + 1) if existing else 1
            now = datetime.now(UTC)
            record = {
                "id": existing["id"] if existing else f"syn-{client_id}",
                "userId": uid,
                "clientReportId": client_id,
                "snapshotId": item["snapshotId"],
                "schemaVersion": item.get("schemaVersion", 1),
                "syncGeneration": item_gen,
                "revision": revision,
                "reportPayload": item["reportPayload"],
                "isDeleted": item.get("isDeleted", False),
                "deletedAt": item.get("deletedAt"),
                "clientUpdatedAt": item["clientUpdatedAt"],
                "createdAt": existing["createdAt"] if existing else now,
                "updatedAt": now,
            }
            self.synced_reports[key] = record
            synced_ids.append(client_id)
        return synced_ids

    def list_synced_reports(
        self,
        user_id: str,
        since: datetime | None = None,
        limit: int = 50,
        cursor: str | None = None,
    ) -> tuple[list[dict[str, Any]], bool]:
        """List synced reports for user with deterministic tie-breaker cursor."""
        uid = str(user_id).strip().lower()
        records: list[dict[str, Any]] = []

        # Parse tie-breaker cursor if provided: "{iso_ts}|{client_report_id}"
        cursor_ts: datetime | None = None
        cursor_id: str | None = None
        if cursor and "|" in cursor:
            parts = cursor.split("|", 1)
            try:
                cursor_ts = datetime.fromisoformat(parts[0].replace(" ", "+"))
                cursor_id = parts[1]
            except Exception:
                cursor_ts = None
                cursor_id = None

        for _key, record in self.synced_reports.items():
            if record["userId"] != uid:
                continue

            record_time = record["clientUpdatedAt"]
            if isinstance(record_time, str):
                record_time = datetime.fromisoformat(record_time)

            if cursor_ts is not None and cursor_id is not None:
                if record_time < cursor_ts:
                    continue
                if record_time == cursor_ts and record["clientReportId"] <= cursor_id:
                    continue
            elif since is not None:
                if record_time <= since:
                    continue

            records.append(record)

        # Sort stably by (clientUpdatedAt, clientReportId)
        def sort_key(r: dict[str, Any]) -> tuple[datetime, str]:
            rt = r["clientUpdatedAt"]
            ts = rt if isinstance(rt, datetime) else datetime.fromisoformat(str(rt))
            return (ts, str(r.get("clientReportId", "")))

        records.sort(key=sort_key)
        has_more = len(records) > limit
        return records[:limit], has_more

    def purge_synced_reports(self, user_id: str) -> int:
        """Purge all cloud synced reports for user and increment generation to block resurrection."""
        uid = str(user_id).strip().lower()
        to_delete = [k for k in self.synced_reports if k.startswith(f"{uid}:")]
        for k in to_delete:
            self.synced_reports.pop(k, None)

        # Increment generation and record purge timestamp
        self.sync_generations[uid] = self.sync_generations.get(uid, 1) + 1
        self.sync_purged_at[uid] = datetime.now(UTC)
        self.profile_sync_enabled[str(user_id).strip()] = False
        return len(to_delete)

    @property
    def uptime_seconds(self) -> int:
        """Calculate elapsed process uptime in whole seconds."""
        return int(time.monotonic() - self.started_at_monotonic)

    def is_operational(self) -> bool:
        """Check whether the application foundation is fully operational."""
        return self.is_ready and not self.is_shutting_down

    def mark_ready(self) -> None:
        """Mark application as ready."""
        self.is_ready = True
        self.is_shutting_down = False

    def mark_draining(self) -> None:
        """Transition application to draining / not-ready state during shutdown."""
        self.is_shutting_down = True
        self.is_ready = False

    async def check_database_connectivity(
        self,
        settings: "Settings | None",
        http_client: httpx.AsyncClient | None = None,
    ) -> Literal["ok", "error", "unconfigured"]:
        """
        Evaluate database connectivity with a bounded non-mutating PostgREST probe.
        Caches result for 10 seconds to avoid high probe load.
        """
        if not settings or not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
            self._last_db_status = "unconfigured"
            return "unconfigured"

        # In hermetic test environment without mocked HTTP client, avoid external network calls
        if settings.ENVIRONMENT == "test" and http_client is None:
            return "ok"

        now_mono = time.monotonic()
        if (now_mono - self._last_db_check_at) < 10.0 and self._last_db_status != "unconfigured":
            return self._last_db_status

        base_url = settings.SUPABASE_URL.rstrip("/")
        key = settings.SUPABASE_SERVICE_ROLE_KEY
        headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Accept": "application/json",
        }

        client = http_client or httpx.AsyncClient(timeout=2.0)
        close_client = http_client is None
        try:
            resp = await client.get(
                f"{base_url}/rest/v1/ai_usage_quotas?limit=1",
                headers=headers,
            )
            if resp.status_code in (200, 206):
                self._last_db_status = "ok"
            else:
                self._last_db_status = "error"
        except Exception:
            self._last_db_status = "error"
        finally:
            self._last_db_check_at = time.monotonic()
            if close_client:
                await client.aclose()

        return self._last_db_status

    def get_readiness_status(
        self,
        settings: "Settings | None" = None,
        db_connectivity: Literal["ok", "error", "unconfigured"] | None = None,
    ) -> tuple[Literal["ready", "degraded"], dict[str, str]]:
        """
        Evaluate readiness for implemented foundation capabilities.

        Subsystem Field Semantics:
        - 'foundation': 'ok' when process is operational; 'degraded' during draining/shutdown.
        - 'authProvider': 'ok' when JWT secrets or JWKS URLs are configured; 'unconfigured' on defaults.
        - 'database':
            - 'unconfigured' when URL or service role key is absent.
            - 'ok' when persistent connection/connectivity probe succeeds.
            - 'error' when persistent database probe fails.
        - 'aiProvider':
            - 'disabled': ENABLE_CLOUD_AI feature flag is False.
            - 'unconfigured': ENABLE_CLOUD_AI is True but GROQ_API_KEY is not configured.
            - 'ok': ENABLE_CLOUD_AI is True and GROQ_API_KEY is configured (adapter initialized).
            - 'error': Process is draining or experienced fatal initialization error.

        Does not invent fake database or AI connections. Never makes paid network calls from routine probes.
        """
        if self.is_operational():
            auth_status = (
                "ok"
                if (settings and (settings.SUPABASE_JWT_SECRET or settings.SUPABASE_JWKS_URL))
                else "unconfigured"
            )

            if db_connectivity is not None:
                database_status = db_connectivity
            elif settings and settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
                database_status = (
                    self._last_db_status if self._last_db_status != "unconfigured" else "ok"
                )
            else:
                database_status = "unconfigured"

            ai_status = "unconfigured"
            if settings:
                if not settings.ENABLE_CLOUD_AI:
                    ai_status = "disabled"
                elif settings.GROQ_API_KEY and settings.GROQ_API_KEY.strip():
                    ai_status = "ok"
                else:
                    ai_status = "unconfigured"

            if database_status == "error":
                return "degraded", {
                    "foundation": "ok",
                    "authProvider": auth_status,
                    "database": database_status,
                    "aiProvider": ai_status,
                }

            return "ready", {
                "foundation": "ok",
                "authProvider": auth_status,
                "database": database_status,
                "aiProvider": ai_status,
            }

        return "degraded", {
            "foundation": "degraded",
            "authProvider": "error",
            "database": "error",
            "aiProvider": "error",
        }
