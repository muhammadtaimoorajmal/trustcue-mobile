"""User quota management, atomic reservations, and quota store abstractions."""

import asyncio
import logging
import uuid
from abc import ABC, abstractmethod
from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING

import httpx

from trustcue_backend.core.errors import TrustCueError
from trustcue_backend.core.rate_limit import RateLimitExceeded

if TYPE_CHECKING:
    from trustcue_backend.core.config import Settings

logger = logging.getLogger("trustcue.quota")


class QuotaStore(ABC):
    """Abstract interface for managing per-user daily AI analysis quotas."""

    @staticmethod
    def _seconds_until_midnight_utc() -> int:
        now = datetime.now(UTC)
        midnight = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        return max(1, int((midnight - now).total_seconds()))

    @abstractmethod
    async def reserve_quota(
        self, user_id: str, reservation_id: str | None = None
    ) -> tuple[bool, int, str | None]:
        """
        Attempt to reserve 1 quota unit for the given user.

        Returns (success: bool, remaining_quota: int, reservation_id: str | None).
        """
        pass

    @abstractmethod
    async def release_quota(self, user_id: str, reservation_id: str) -> None:
        """Release an unused quota reservation back to the user's daily balance."""
        pass

    @abstractmethod
    async def commit_quota(self, user_id: str, reservation_id: str) -> None:
        """Permanently commit a consumed quota reservation."""
        pass

    @abstractmethod
    async def get_remaining_quota(self, user_id: str) -> int:
        """Return the current remaining daily quota for the user."""
        pass

    async def enforce_quota(self, user_id: str) -> str:
        """
        Helper method to reserve quota or raise RateLimitExceeded with accurate Retry-After.
        """
        success, remaining, res_id = await self.reserve_quota(user_id)
        if not success or res_id is None:
            retry_after = self._seconds_until_midnight_utc()
            quota_limit = getattr(self, "default_daily_quota", 15)
            raise RateLimitExceeded(
                message=f"Daily AI analysis quota of {quota_limit} requests reached. Quota resets at 00:00 UTC.",
                retry_after=retry_after,
                code="rate_limit_exceeded",
                details={
                    "dailyQuota": quota_limit,
                    "remaining": 0,
                    "resetsAt": "00:00:00Z",
                },
            )
        return res_id


class InMemoryQuotaStore(QuotaStore):
    """
    In-memory daily quota store for testing and standalone operation.

    Tracks daily consumption per user UUID. Daily resets occur at 00:00:00 UTC.
    """

    def __init__(self, default_daily_quota: int = 15) -> None:
        self.default_daily_quota = default_daily_quota
        # Map: (user_id, "YYYY-MM-DD") -> used_count
        self._usage: dict[tuple[str, str], int] = {}
        # Map: reservation_id -> (user_id, "YYYY-MM-DD")
        self._active_reservations: dict[str, tuple[str, str]] = {}
        self._lock = asyncio.Lock()

    @staticmethod
    def _get_today_utc() -> str:
        return datetime.now(UTC).strftime("%Y-%m-%d")

    async def reserve_quota(
        self, user_id: str, reservation_id: str | None = None
    ) -> tuple[bool, int, str | None]:
        today = self._get_today_utc()
        key = (user_id, today)
        res_id = reservation_id or str(uuid.uuid4())

        async with self._lock:
            # Idempotency check: if reservation already exists, return current state
            if res_id in self._active_reservations:
                current_used = self._usage.get(key, 0)
                remaining = max(0, self.default_daily_quota - current_used)
                return True, remaining, res_id

            current_used = self._usage.get(key, 0)
            if current_used >= self.default_daily_quota:
                remaining = 0
                return False, remaining, None

            self._usage[key] = current_used + 1
            self._active_reservations[res_id] = key
            remaining = self.default_daily_quota - self._usage[key]
            return True, remaining, res_id

    async def release_quota(self, user_id: str, reservation_id: str) -> None:
        async with self._lock:
            key = self._active_reservations.pop(reservation_id, None)
            if key and key in self._usage:
                self._usage[key] = max(0, self._usage[key] - 1)

    async def commit_quota(self, user_id: str, reservation_id: str) -> None:
        async with self._lock:
            self._active_reservations.pop(reservation_id, None)

    async def get_remaining_quota(self, user_id: str) -> int:
        today = self._get_today_utc()
        key = (user_id, today)
        async with self._lock:
            used = self._usage.get(key, 0)
            return max(0, self.default_daily_quota - used)


class SupabaseQuotaStore(QuotaStore):
    """
    Persistent per-user daily AI analysis quota store communicating with Supabase PostgREST.

    Invariants:
    1. Directs all quota queries and state mutations to PostgreSQL / PostgREST.
    2. Zero in-memory caching of counts: prevents stale counts and survives process restarts/redeploys.
    3. Uses reserve_ai_quota_v2 (with fallback to reserve_ai_quota) for atomic row-level reservation.
    4. Durable reservation tracking ensures idempotency, retry safety, and midnight rollover refunds.
    5. Fails closed: database errors raise TrustCueError (503), preventing unmetered inference.
    6. Never stores prompts, text excerpts, or tokens in reservation records.
    """

    def __init__(
        self,
        settings: "Settings",
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.settings = settings
        self.default_daily_quota = settings.DEFAULT_DAILY_AI_QUOTA
        self._http_client = http_client

        if not self.settings.SUPABASE_URL or not self.settings.SUPABASE_SERVICE_ROLE_KEY:
            raise TrustCueError(
                code="database_unavailable",
                message="Supabase URL and Service Role Key are required for persistent quota storage.",
                status_code=503,
            )

    def _get_headers(self) -> dict[str, str]:
        key = self.settings.SUPABASE_SERVICE_ROLE_KEY or ""
        return {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    async def reserve_quota(
        self, user_id: str, reservation_id: str | None = None
    ) -> tuple[bool, int, str | None]:
        """
        Attempt to reserve 1 quota unit for the given user using atomic row-level reservation.
        """
        res_id = reservation_id or str(uuid.uuid4())
        base_url = (self.settings.SUPABASE_URL or "").rstrip("/")
        client = self._http_client or httpx.AsyncClient(timeout=5.0)
        close_client = self._http_client is None

        try:
            # 1. Attempt v2 durable reservation RPC
            v2_payload = {
                "p_user_id": user_id,
                "p_reservation_id": res_id,
                "p_max_daily_requests": self.default_daily_quota,
            }
            resp = await client.post(
                f"{base_url}/rest/v1/rpc/reserve_ai_quota_v2",
                headers=self._get_headers(),
                json=v2_payload,
            )

            if resp.status_code == 200:
                rows = resp.json()
                if isinstance(rows, list) and len(rows) > 0:
                    r = rows[0]
                    allowed = bool(r.get("allowed", False))
                    return (
                        allowed,
                        int(r.get("requests_remaining", 0)),
                        res_id if allowed else None,
                    )
                return False, 0, None

            # 2. Fallback to v1 reservation RPC if v2 migration is not yet applied
            if resp.status_code == 404:
                v1_payload = {
                    "p_user_id": user_id,
                    "p_max_daily_requests": self.default_daily_quota,
                    "p_tokens_requested": 0,
                }
                v1_resp = await client.post(
                    f"{base_url}/rest/v1/rpc/reserve_ai_quota",
                    headers=self._get_headers(),
                    json=v1_payload,
                )
                if v1_resp.status_code == 200:
                    rows = v1_resp.json()
                    if isinstance(rows, list) and len(rows) > 0:
                        r = rows[0]
                        allowed = bool(r.get("allowed", False))
                        return (
                            allowed,
                            int(r.get("requests_remaining", 0)),
                            res_id if allowed else None,
                        )
                    return False, 0, None

                logger.error(
                    "reserve_ai_quota fallback returned status %s: %s",
                    v1_resp.status_code,
                    v1_resp.text,
                )
                raise TrustCueError(
                    code="database_error",
                    message="Failed to reserve quota slot in database.",
                    status_code=503,
                )

            logger.error("reserve_ai_quota_v2 returned status %s: %s", resp.status_code, resp.text)
            raise TrustCueError(
                code="database_error",
                message="Failed to reserve quota slot in database.",
                status_code=503,
            )

        except TrustCueError:
            raise
        except Exception as exc:
            logger.error(
                "Exception during quota reservation for user %s: %s", user_id, str(exc)
            )
            raise TrustCueError(
                code="database_error",
                message="Persistent quota storage is unreachable or failed.",
                status_code=503,
            ) from exc
        finally:
            if close_client:
                await client.aclose()

    async def commit_quota(self, user_id: str, reservation_id: str) -> None:
        """
        Permanently commit a consumed quota reservation.
        """
        base_url = (self.settings.SUPABASE_URL or "").rstrip("/")
        client = self._http_client or httpx.AsyncClient(timeout=5.0)
        close_client = self._http_client is None

        try:
            resp = await client.post(
                f"{base_url}/rest/v1/rpc/commit_ai_quota_v2",
                headers=self._get_headers(),
                json={"p_user_id": user_id, "p_reservation_id": reservation_id},
            )
            # 404 denotes v1 schema where commit is a durable no-op
            if resp.status_code not in (200, 204, 404):
                logger.warning(
                    "commit_ai_quota_v2 returned status %s for user %s: %s",
                    resp.status_code,
                    user_id,
                    resp.text,
                )
        except Exception as exc:
            logger.warning(
                "Exception during commit_quota for user %s: %s", user_id, str(exc)
            )
        finally:
            if close_client:
                await client.aclose()

    async def release_quota(self, user_id: str, reservation_id: str) -> None:
        """
        Release an unused quota reservation back to the user's balance.
        """
        base_url = (self.settings.SUPABASE_URL or "").rstrip("/")
        client = self._http_client or httpx.AsyncClient(timeout=5.0)
        close_client = self._http_client is None

        try:
            resp = await client.post(
                f"{base_url}/rest/v1/rpc/release_ai_quota_v2",
                headers=self._get_headers(),
                json={"p_user_id": user_id, "p_reservation_id": reservation_id},
            )
            if resp.status_code == 404:
                # Fallback to v1 release
                v1_resp = await client.post(
                    f"{base_url}/rest/v1/rpc/release_ai_quota",
                    headers=self._get_headers(),
                    json={"p_user_id": user_id, "p_tokens_to_refund": 0},
                )
                if v1_resp.status_code not in (200, 204):
                    logger.warning(
                        "release_ai_quota v1 fallback returned status %s: %s",
                        v1_resp.status_code,
                        v1_resp.text,
                    )
            elif resp.status_code not in (200, 204):
                logger.warning(
                    "release_ai_quota_v2 returned status %s: %s",
                    resp.status_code,
                    resp.text,
                )
        except Exception as exc:
            logger.warning(
                "Exception during release_quota for user %s: %s", user_id, str(exc)
            )
        finally:
            if close_client:
                await client.aclose()

    async def get_remaining_quota(self, user_id: str) -> int:
        """
        Return the current remaining daily quota for the user from persistent storage.
        """
        base_url = (self.settings.SUPABASE_URL or "").rstrip("/")
        client = self._http_client or httpx.AsyncClient(timeout=5.0)
        close_client = self._http_client is None

        try:
            # 1. Attempt get_remaining_ai_quota RPC
            resp = await client.post(
                f"{base_url}/rest/v1/rpc/get_remaining_ai_quota",
                headers=self._get_headers(),
                json={
                    "p_user_id": user_id,
                    "p_max_daily_requests": self.default_daily_quota,
                },
            )
            if resp.status_code == 200:
                data = resp.json()
                if isinstance(data, int):
                    return max(0, data)
                if (
                    isinstance(data, list)
                    and len(data) > 0
                    and isinstance(data[0], int)
                ):
                    return max(0, data[0])

            # 2. Fallback to direct query on ai_usage_quotas
            today = datetime.now(UTC).strftime("%Y-%m-%d")
            table_resp = await client.get(
                f"{base_url}/rest/v1/ai_usage_quotas?user_id=eq.{user_id}&quota_date=eq.{today}&select=request_count",
                headers=self._get_headers(),
            )
            if table_resp.status_code == 200:
                rows = table_resp.json()
                if isinstance(rows, list) and len(rows) > 0:
                    used = int(rows[0].get("request_count", 0))
                    return max(0, self.default_daily_quota - used)
                return self.default_daily_quota

            logger.error(
                "get_remaining_quota PostgREST read returned status %s: %s",
                table_resp.status_code,
                table_resp.text,
            )
            raise TrustCueError(
                code="database_error",
                message="Failed to read persistent quota from database.",
                status_code=503,
            )
        except TrustCueError:
            raise
        except Exception as exc:
            logger.error(
                "Exception reading persistent quota for user %s: %s", user_id, str(exc)
            )
            raise TrustCueError(
                code="database_error",
                message="Persistent quota storage is unreachable.",
                status_code=503,
            ) from exc
        finally:
            if close_client:
                await client.aclose()
