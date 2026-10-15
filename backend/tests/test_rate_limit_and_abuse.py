"""Tests for rate limiting, concurrency controls, quota reservations, and abuse prevention."""

import pytest
from starlette.testclient import TestClient

from trustcue_backend.api.dependencies import enforce_user_ownership
from trustcue_backend.core.auth import AuthenticatedUser, create_test_jwt
from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import TrustCueError
from trustcue_backend.core.quota import InMemoryQuotaStore
from trustcue_backend.core.rate_limit import (
    ConcurrencyLimiter,
    RateLimitExceeded,
    SlidingWindowRateLimiter,
)
from trustcue_backend.main import create_app


@pytest.mark.asyncio
async def test_sliding_window_rate_limiter_enforces_threshold() -> None:
    """Sliding-window limiter allows up to max_requests and rejects excess requests."""
    limiter = SlidingWindowRateLimiter()
    key = "test-user-1"

    # 3 requests allowed in 10s window
    for _ in range(3):
        remaining = await limiter.check_rate_limit(key, max_requests=3, window_seconds=10)
        assert remaining >= 0

    # 4th request must be rejected with RateLimitExceeded
    with pytest.raises(RateLimitExceeded) as exc_info:
        await limiter.check_rate_limit(key, max_requests=3, window_seconds=10)

    assert exc_info.value.status_code == 429
    assert exc_info.value.code == "rate_limit_exceeded"
    assert exc_info.value.retry_after >= 1


@pytest.mark.asyncio
async def test_concurrency_limiter_rejects_parallel_operations() -> None:
    """Concurrency limiter rejects overlapping active operations for the same account."""
    limiter = ConcurrencyLimiter(max_per_user=1, max_global=5)
    user_key = "user:00000000-0000-0000-0000-000000000001"

    async with limiter.acquire(user_key):
        # Nested attempt for the same user while first operation is still running
        with pytest.raises(RateLimitExceeded) as exc_info:
            async with limiter.acquire(user_key):
                pass
        assert exc_info.value.status_code == 429
        assert "already in progress" in exc_info.value.message

    # Once released, a new operation can proceed
    async with limiter.acquire(user_key):
        pass


@pytest.mark.asyncio
async def test_in_memory_quota_store_lifecycle() -> None:
    """Quota store correctly tracks reservations, releases, commits, and exhausts."""
    store = InMemoryQuotaStore(default_daily_quota=2)
    user_id = "00000000-0000-0000-0000-000000000002"

    assert await store.get_remaining_quota(user_id) == 2

    # Reserve 1
    ok1, rem1, res1 = await store.reserve_quota(user_id)
    assert ok1 is True
    assert rem1 == 1
    assert res1 is not None

    # Release 1
    await store.release_quota(user_id, res1)
    assert await store.get_remaining_quota(user_id) == 2

    # Reserve 2 to exhaust
    ok_a, rem_a, res_a = await store.reserve_quota(user_id)
    ok_b, rem_b, res_b = await store.reserve_quota(user_id)
    assert ok_a and ok_b
    assert rem_b == 0

    # 3rd reservation should fail
    ok_c, rem_c, res_c = await store.reserve_quota(user_id)
    assert ok_c is False
    assert rem_c == 0
    assert res_c is None

    # Commit reservation
    await store.commit_quota(user_id, res_a)


def test_cross_account_ownership_enforcement() -> None:
    """Cross-account access attempts are strictly rejected with HTTP 403 Forbidden."""
    user = AuthenticatedUser(user_id="11111111-1111-1111-1111-111111111111")

    # Own account passes
    enforce_user_ownership("11111111-1111-1111-1111-111111111111", user)

    # Different account fails
    with pytest.raises(TrustCueError) as exc_info:
        enforce_user_ownership("22222222-2222-2222-2222-222222222222", user)

    assert exc_info.value.status_code == 403
    assert exc_info.value.code == "forbidden"


def test_api_rate_limit_exceeded_returns_429_with_header() -> None:
    """Analysis route enforces sliding-window limit and returns 429 with Retry-After header."""
    settings = Settings(SUPABASE_JWT_SECRET="test-jwt-secret-key-32-chars-long!", ENVIRONMENT="test")
    app = create_app(settings=settings)
    client = TestClient(app)

    user_id = "00000000-0000-0000-0000-000000000005"
    token = create_test_jwt(user_id=user_id)
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "snapshotId": "snap-rate-test",
        "text": "Legitimate text message for rate limiting test.",
        "source": "messageText",
        "sourceRevision": "rev-1",
        "clientTimestamp": "2026-10-15T12:00:00Z",
    }

    # Default per-user rate limit is 10 requests per minute
    # First 10 requests will return 503 (cloud AI unconfigured) or succeed through rate limiter
    for _ in range(10):
        resp = client.post("/api/v1/analysis/ai", headers=headers, json=payload)
        assert resp.status_code == 503

    # 11th request must trigger 429
    resp_limited = client.post("/api/v1/analysis/ai", headers=headers, json=payload)
    assert resp_limited.status_code == 429
    assert "Retry-After" in resp_limited.headers
    data = resp_limited.json()
    assert data["error"]["code"] == "rate_limit_exceeded"
    assert "requestId" in data["error"]
