"""In-memory sliding-window rate limiter, concurrency controls, and abuse prevention."""

import asyncio
import math
import time
from collections import defaultdict, deque
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from trustcue_backend.core.errors import TrustCueError


class RateLimitExceeded(TrustCueError):
    """Exception raised when a client exceeds rate or quota limits (HTTP 429)."""

    def __init__(
        self,
        message: str = "Too many requests. Please wait before retrying.",
        retry_after: int = 60,
        code: str = "rate_limit_exceeded",
        details: dict | None = None,
    ) -> None:
        self.retry_after = max(1, retry_after)
        super().__init__(
            code=code,
            message=message,
            status_code=429,
            details=details,
        )


class SlidingWindowRateLimiter:
    """
    In-memory sliding-window rate limiter.

    Tracks request timestamps within a moving time window per client key (user UUID or IP address).
    Automatically prunes stale entries to maintain bounded memory consumption.
    """

    def __init__(self, max_tracked_keys: int = 10_000) -> None:
        self._windows: dict[str, deque[float]] = defaultdict(deque)
        self._max_tracked_keys = max_tracked_keys
        self._lock = asyncio.Lock()
        self._last_prune = time.monotonic()

    async def check_rate_limit(
        self,
        key: str,
        max_requests: int = 10,
        window_seconds: int = 60,
    ) -> int:
        """
        Record a request attempt for `key` and check if the limit is exceeded.

        Returns remaining requests allowed within the window.
        Raises RateLimitExceeded if the limit is exceeded.
        """
        now = time.monotonic()

        async with self._lock:
            # Periodic cleanup every 60 seconds
            if now - self._last_prune > 60:
                self._prune(now, window_seconds)
                self._last_prune = now

            timestamps = self._windows[key]

            # Drop timestamps outside the sliding window
            cutoff = now - window_seconds
            while timestamps and timestamps[0] <= cutoff:
                timestamps.popleft()

            if len(timestamps) >= max_requests:
                oldest = timestamps[0]
                retry_after = int(math.ceil(window_seconds - (now - oldest)))
                raise RateLimitExceeded(
                    message=f"Rate limit exceeded. Maximum {max_requests} requests per {window_seconds}s.",
                    retry_after=max(1, retry_after),
                )

            timestamps.append(now)
            return max_requests - len(timestamps)

    def _prune(self, now: float, window_seconds: int) -> None:
        """Prune empty keys or evict keys if capacity is reached."""
        cutoff = now - window_seconds
        stale_keys = [k for k, dq in self._windows.items() if not dq or dq[-1] <= cutoff]
        for k in stale_keys:
            del self._windows[k]

        # Guard against unbounded key accumulation
        if len(self._windows) > self._max_tracked_keys:
            # Evict oldest inactive keys
            excess = len(self._windows) - self._max_tracked_keys
            keys_to_remove = list(self._windows.keys())[:excess]
            for k in keys_to_remove:
                del self._windows[k]

    async def reset(self) -> None:
        """Clear all rate limit state (useful in test teardown)."""
        async with self._lock:
            self._windows.clear()


class ConcurrencyLimiter:
    """
    Limits the number of concurrent in-flight operations per user key and globally.
    """

    def __init__(self, max_per_user: int = 1, max_global: int = 20) -> None:
        self.max_per_user = max_per_user
        self.max_global = max_global
        self._user_counts: dict[str, int] = defaultdict(int)
        self._global_count = 0
        self._lock = asyncio.Lock()

    @asynccontextmanager
    async def acquire(self, key: str) -> AsyncIterator[None]:
        """
        Acquire a concurrency slot for the specified key.

        Raises RateLimitExceeded if concurrent capacity is reached.
        """
        async with self._lock:
            if self._global_count >= self.max_global:
                raise RateLimitExceeded(
                    message="Server is processing maximum concurrent analysis requests. Please try again shortly.",
                    retry_after=5,
                )
            if self._user_counts[key] >= self.max_per_user:
                raise RateLimitExceeded(
                    message="Another analysis request is already in progress for this account.",
                    retry_after=3,
                )

            self._user_counts[key] += 1
            self._global_count += 1

        try:
            yield
        finally:
            async with self._lock:
                self._user_counts[key] -= 1
                if self._user_counts[key] <= 0:
                    self._user_counts.pop(key, None)
                self._global_count = max(0, self._global_count - 1)
