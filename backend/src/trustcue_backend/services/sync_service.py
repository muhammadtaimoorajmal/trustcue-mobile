"""Cloud report synchronization service for Module 39."""

import logging
from datetime import UTC, datetime
from typing import Any

import httpx

from trustcue_backend.api.schemas.sync import (
    SyncedReportRecord,
    SyncPurgeResponse,
    SyncReportsPullResponse,
    SyncReportsPushRequest,
    SyncReportsPushResponse,
)
from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import SyncOptInRequiredError
from trustcue_backend.core.state import AppState

logger = logging.getLogger("trustcue.sync")


class SyncService:
    """
    Manages optional, privacy-bounded cloud synchronization of report summaries.

    Invariants:
    - Rejects all upload and retrieval attempts unless user has sync_enabled=True.
    - Operates exclusively on privacy-bounded summaries; never stores raw message text.
    - Respects tombstones for reliable synchronization across client devices.
    """

    def __init__(
        self,
        settings: Settings,
        app_state: AppState,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.settings = settings
        self.app_state = app_state
        self._http_client = http_client

    def _get_auth_headers(self) -> dict[str, str]:
        key = self.settings.SUPABASE_SERVICE_ROLE_KEY or ""
        return {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    async def get_sync_profile_state(self, user_id: str) -> tuple[bool, datetime | None]:
        """Determine whether the user has opted into cloud sync and retrieve their last purge timestamp."""
        enabled = self.app_state.get_sync_enabled(user_id)
        purged_at = self.app_state.sync_purged_at.get(str(user_id).strip().lower())

        if self.settings.SUPABASE_URL and self.settings.SUPABASE_SERVICE_ROLE_KEY:
            client = self._http_client or httpx.AsyncClient(timeout=5.0)
            close_client = self._http_client is None
            try:
                base_url = self.settings.SUPABASE_URL.rstrip("/")
                resp = await client.get(
                    f"{base_url}/rest/v1/profiles?id=eq.{user_id}&select=sync_enabled,sync_purged_at",
                    headers=self._get_auth_headers(),
                )
                if resp.status_code == 200:
                    data = resp.json()
                    if isinstance(data, list) and len(data) > 0:
                        enabled = bool(data[0].get("sync_enabled", False))
                        self.app_state.set_sync_enabled(user_id, enabled)
                        raw_purged = data[0].get("sync_purged_at")
                        if raw_purged:
                            purged_at = datetime.fromisoformat(str(raw_purged).replace("Z", "+00:00"))
                            self.app_state.sync_purged_at[str(user_id).strip().lower()] = purged_at
            except Exception as exc:
                logger.warning("Error verifying sync profile state for user %s: %s", user_id, str(exc))
            finally:
                if close_client:
                    await client.aclose()

        return enabled, purged_at

    async def is_sync_enabled(self, user_id: str) -> bool:
        """Determine whether the user has explicitly opted into cloud synchronization."""
        enabled, _ = await self.get_sync_profile_state(user_id)
        return enabled

    async def push_reports(
        self, user_id: str, request: SyncReportsPushRequest
    ) -> SyncReportsPushResponse:
        """
        Batch-upload client-submitted report summaries.

        Requires sync_enabled opt-in on user profile, except for tombstones (owner deletion).
        Rejects stale uploads preceding the user's last cloud purge to prevent resurrection.
        """
        sync_enabled, purged_at = await self.get_sync_profile_state(user_id)
        if not sync_enabled:
            # Opt-out blocks new uploads but does not prevent owner deletion (tombstones)
            if not all(item.is_deleted for item in request.reports):
                raise SyncOptInRequiredError()

        # Filter out stale reports dated before the user's purge timestamp
        valid_items: list[Any] = []
        for item in request.reports:
            item_time = (
                item.client_updated_at
                if isinstance(item.client_updated_at, datetime)
                else datetime.fromisoformat(str(item.client_updated_at))
            )
            if purged_at is not None and item_time <= purged_at:
                logger.info(
                    "Skipping stale report %s for user %s: timestamp %s precedes purge %s",
                    item.client_report_id,
                    user_id,
                    item_time,
                    purged_at,
                )
                continue
            valid_items.append(item)

        raw_items: list[dict[str, Any]] = [
            item.model_dump(by_alias=True) for item in valid_items
        ]

        # 1. Update in-memory fallback state
        synced_ids = self.app_state.save_synced_reports(user_id, raw_items)

        # 2. Persist to PostgREST public.synced_reports if configured
        if self.settings.SUPABASE_URL and self.settings.SUPABASE_SERVICE_ROLE_KEY and valid_items:
            client = self._http_client or httpx.AsyncClient(timeout=10.0)
            close_client = self._http_client is None
            try:
                base_url = self.settings.SUPABASE_URL.rstrip("/")
                headers = self._get_auth_headers()
                headers["Prefer"] = "resolution=merge-duplicates"

                rows: list[dict[str, Any]] = []
                for item in valid_items:
                    rows.append({
                        "user_id": user_id,
                        "client_report_id": item.client_report_id,
                        "snapshot_id": item.snapshot_id,
                        "schema_version": item.schema_version,
                        "report_payload": item.report_payload,
                        "is_deleted": item.is_deleted,
                        "deleted_at": item.deleted_at.isoformat() if item.deleted_at else None,
                        "client_updated_at": item.client_updated_at.isoformat(),
                        "updated_at": datetime.now(UTC).isoformat(),
                    })

                resp = await client.post(
                    f"{base_url}/rest/v1/synced_reports?on_conflict=user_id,client_report_id",
                    headers=headers,
                    json=rows,
                )
                if resp.status_code not in (200, 201, 204):
                    logger.warning(
                        "PostgREST batch sync returned status %s for user %s: %s",
                        resp.status_code,
                        user_id,
                        resp.text,
                    )
            except Exception as exc:
                logger.warning("PostgREST batch sync failed for user %s: %s", user_id, str(exc))
            finally:
                if close_client:
                    await client.aclose()

        return SyncReportsPushResponse(
            acceptedCount=len(valid_items),
            syncedReportIds=synced_ids,
            serverTimestamp=datetime.now(UTC),
        )

    async def pull_reports(
        self,
        user_id: str,
        since: datetime | None = None,
        limit: int = 50,
        cursor: str | None = None,
    ) -> SyncReportsPullResponse:
        """
        Retrieve report summaries modified after `since`.

        Requires sync_enabled opt-in on user profile.
        """
        if not await self.is_sync_enabled(user_id):
            raise SyncOptInRequiredError()

        clamped_limit = min(max(limit, 1), 100)
        records: list[SyncedReportRecord] = []
        has_more = False

        if self.settings.SUPABASE_URL and self.settings.SUPABASE_SERVICE_ROLE_KEY:
            client = self._http_client or httpx.AsyncClient(timeout=8.0)
            close_client = self._http_client is None
            try:
                base_url = self.settings.SUPABASE_URL.rstrip("/")
                order_clause = "order=client_updated_at.asc,client_report_id.asc"
                if cursor and "|" in cursor:
                    c_ts, c_id = cursor.split("|", 1)
                    c_ts = c_ts.replace(" ", "+")
                    query = f"user_id=eq.{user_id}&or=(client_updated_at.gt.{c_ts},and(client_updated_at.eq.{c_ts},client_report_id.gt.{c_id}))&{order_clause}&limit={clamped_limit + 1}"
                elif since is not None:
                    query = f"user_id=eq.{user_id}&client_updated_at.gt.{since.isoformat()}&{order_clause}&limit={clamped_limit + 1}"
                else:
                    query = f"user_id=eq.{user_id}&{order_clause}&limit={clamped_limit + 1}"

                resp = await client.get(
                    f"{base_url}/rest/v1/synced_reports?{query}",
                    headers=self._get_auth_headers(),
                )
                if resp.status_code == 200:
                    rows = resp.json()
                    if isinstance(rows, list):
                        if len(rows) > clamped_limit:
                            has_more = True
                            rows = rows[:clamped_limit]

                        for row in rows:
                            records.append(
                                SyncedReportRecord(
                                    id=row["id"],
                                    clientReportId=row["client_report_id"],
                                    snapshotId=row["snapshot_id"],
                                    schemaVersion=row.get("schema_version", 1),
                                    revision=row.get("revision", 1),
                                    reportPayload=row["report_payload"],
                                    isDeleted=row.get("is_deleted", False),
                                    deletedAt=row.get("deleted_at"),
                                    clientUpdatedAt=row["client_updated_at"],
                                    createdAt=row["created_at"],
                                    updatedAt=row["updated_at"],
                                )
                            )
                        next_cursor = (
                            f"{records[-1].client_updated_at.isoformat()}|{records[-1].client_report_id}"
                            if (has_more and records)
                            else None
                        )
                        return SyncReportsPullResponse(
                            reports=records,
                            nextCursor=next_cursor,
                            hasMore=has_more,
                            serverTimestamp=datetime.now(UTC),
                        )
            except Exception as exc:
                logger.warning("PostgREST pull_reports query failed for user %s: %s", user_id, str(exc))
            finally:
                if close_client:
                    await client.aclose()

        # Fallback to in-memory state
        in_mem_records, has_more = self.app_state.list_synced_reports(
            user_id, since=since, limit=clamped_limit, cursor=cursor
        )
        for r in in_mem_records:
            records.append(
                SyncedReportRecord(
                    id=r["id"],
                    clientReportId=r["clientReportId"],
                    snapshotId=r["snapshotId"],
                    schemaVersion=r.get("schemaVersion", 1),
                    revision=r.get("revision", 1),
                    reportPayload=r["reportPayload"],
                    isDeleted=r.get("isDeleted", False),
                    deletedAt=r.get("deletedAt"),
                    clientUpdatedAt=r["clientUpdatedAt"],
                    createdAt=r["createdAt"],
                    updatedAt=r["updatedAt"],
                )
            )

        next_cursor = (
            f"{records[-1].client_updated_at.isoformat()}|{records[-1].client_report_id}"
            if (has_more and records)
            else None
        )
        return SyncReportsPullResponse(
            reports=records,
            nextCursor=next_cursor,
            hasMore=has_more,
            serverTimestamp=datetime.now(UTC),
        )

    async def purge_reports(self, user_id: str) -> SyncPurgeResponse:
        """Purge all cloud synced reports for the specified user and disable cloud sync."""
        in_mem_purged = self.app_state.purge_synced_reports(user_id)
        db_purged = 0

        if self.settings.SUPABASE_URL and self.settings.SUPABASE_SERVICE_ROLE_KEY:
            client = self._http_client or httpx.AsyncClient(timeout=8.0)
            close_client = self._http_client is None
            try:
                base_url = self.settings.SUPABASE_URL.rstrip("/")
                resp = await client.post(
                    f"{base_url}/rest/v1/rpc/purge_synced_reports",
                    headers=self._get_auth_headers(),
                    json={"target_user_id": user_id},
                )
                if resp.status_code == 200:
                    try:
                        db_purged = int(resp.json())
                    except Exception:
                        pass
                else:
                    # Fallback to direct DELETE if RPC fails or not deployed yet
                    del_resp = await client.delete(
                        f"{base_url}/rest/v1/synced_reports?user_id=eq.{user_id}",
                        headers=self._get_auth_headers(),
                    )
                    if del_resp.status_code in (200, 204):
                        db_purged = in_mem_purged

                # Explicitly disable sync_enabled on profile
                await client.patch(
                    f"{base_url}/rest/v1/profiles?id=eq.{user_id}",
                    headers=self._get_auth_headers(),
                    json={"sync_enabled": False},
                )
            except Exception as exc:
                logger.warning("PostgREST purge_reports failed for user %s: %s", user_id, str(exc))
            finally:
                if close_client:
                    await client.aclose()

        effective_count = max(in_mem_purged, db_purged)
        return SyncPurgeResponse(
            purgedCount=effective_count,
            message="Cloud synced reports successfully purged.",
            serverTimestamp=datetime.now(UTC),
        )
