"""User quota management, atomic reservations, and quota store abstractions."""

import asyncio
import uuid
from abc import ABC, abstractmethod
from datetime import UTC, datetime, timedelta

from trustcue_backend.core.rate_limit import RateLimitExceeded


class QuotaStore(ABC):
    """Abstract interface for managing per-user daily AI analysis quotas."""

    @abstractmethod
    async def reserve_quota(self, user_id: str) -> tuple[bool, int, str | None]:
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

    @staticmethod
    def _seconds_until_midnight_utc() -> int:
        now = datetime.now(UTC)
        midnight = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        return max(1, int((midnight - now).total_seconds()))

    async def reserve_quota(self, user_id: str) -> tuple[bool, int, str | None]:
        today = self._get_today_utc()
        key = (user_id, today)

        async with self._lock:
            current_used = self._usage.get(key, 0)
            if current_used >= self.default_daily_quota:
                remaining = 0
                return False, remaining, None

            res_id = str(uuid.uuid4())
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

    async def enforce_quota(self, user_id: str) -> str:
        """
        Helper method to reserve quota or raise RateLimitExceeded with accurate Retry-After.
        """
        success, remaining, res_id = await self.reserve_quota(user_id)
        if not success or res_id is None:
            retry_after = self._seconds_until_midnight_utc()
            raise RateLimitExceeded(
                message=f"Daily AI analysis quota of {self.default_daily_quota} requests reached. Quota resets at 00:00 UTC.",
                retry_after=retry_after,
                code="rate_limit_exceeded",
                details={
                    "dailyQuota": self.default_daily_quota,
                    "remaining": 0,
                    "resetsAt": "00:00:00Z",
                },
            )
        return res_id

