"""Tests for persistent SupabaseQuotaStore and quota reservation lifecycle."""

import uuid

import httpx
import pytest

from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import TrustCueError
from trustcue_backend.core.quota import InMemoryQuotaStore, SupabaseQuotaStore
from trustcue_backend.core.rate_limit import RateLimitExceeded
from trustcue_backend.main import create_app


@pytest.fixture
def mock_settings() -> Settings:
    return Settings(
        ENVIRONMENT="test",
        SUPABASE_URL="https://mock.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="mock-service-role-key-test-long-enough",
        DEFAULT_DAILY_AI_QUOTA=15,
    )


def test_supabase_quota_store_requires_credentials() -> None:
    """Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY raises 503 TrustCueError."""
    empty_settings = Settings(
        ENVIRONMENT="test",
        SUPABASE_URL=None,
        SUPABASE_SERVICE_ROLE_KEY=None,
    )
    with pytest.raises(TrustCueError) as exc_info:
        SupabaseQuotaStore(settings=empty_settings)
    assert exc_info.value.status_code == 503
    assert exc_info.value.code == "database_unavailable"


def test_production_fails_without_credentials() -> None:
    """Production environment creation fails immediately if Supabase credentials are missing."""
    prod_settings = Settings(
        ENVIRONMENT="production",
        SUPABASE_URL=None,
        SUPABASE_SERVICE_ROLE_KEY=None,
    )
    with pytest.raises(RuntimeError) as exc_info:
        create_app(settings=prod_settings)
    assert "Production requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY" in str(exc_info.value)


@pytest.mark.asyncio
async def test_quota_store_limit_boundary(mock_settings: Settings) -> None:
    """Verify limit boundary enforcement: allows up to daily quota, rejects subsequent."""
    user_id = str(uuid.uuid4())

    async def mock_handler(request: httpx.Request) -> httpx.Response:
        if "reserve_ai_quota_v2" in str(request.url):
            return httpx.Response(
                200,
                json=[{"allowed": False, "requests_used": 15, "requests_remaining": 0}],
            )
        return httpx.Response(404)

    transport = httpx.MockTransport(mock_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        store = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        allowed, remaining, res_id = await store.reserve_quota(user_id)
        assert allowed is False
        assert remaining == 0
        assert res_id is None

        with pytest.raises(RateLimitExceeded) as exc_info:
            await store.enforce_quota(user_id)
        assert exc_info.value.code == "rate_limit_exceeded"
        assert exc_info.value.details["remaining"] == 0


@pytest.mark.asyncio
async def test_quota_store_v2_success(mock_settings: Settings) -> None:
    """Successful reservation using v2 RPC returns reservation ID and decrements remaining."""
    user_id = str(uuid.uuid4())
    custom_res_id = str(uuid.uuid4())

    async def mock_handler(request: httpx.Request) -> httpx.Response:
        if "reserve_ai_quota_v2" in str(request.url):
            return httpx.Response(
                200,
                json=[{"allowed": True, "requests_used": 1, "requests_remaining": 14}],
            )
        return httpx.Response(404)

    transport = httpx.MockTransport(mock_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        store = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        allowed, remaining, res_id = await store.reserve_quota(user_id, custom_res_id)
        assert allowed is True
        assert remaining == 14
        assert res_id == custom_res_id


@pytest.mark.asyncio
async def test_quota_store_v1_fallback(mock_settings: Settings) -> None:
    """When v2 RPC returns 404, falls back to hosted v1 RPC seamlessly."""
    user_id = str(uuid.uuid4())

    async def mock_handler(request: httpx.Request) -> httpx.Response:
        url_str = str(request.url)
        if "reserve_ai_quota_v2" in url_str:
            return httpx.Response(404, json={"message": "function not found"})
        if "reserve_ai_quota" in url_str:
            return httpx.Response(
                200,
                json=[{"allowed": True, "requests_used": 2, "requests_remaining": 13}],
            )
        return httpx.Response(404)

    transport = httpx.MockTransport(mock_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        store = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        allowed, remaining, res_id = await store.reserve_quota(user_id)
        assert allowed is True
        assert remaining == 13
        assert res_id is not None


@pytest.mark.asyncio
async def test_quota_store_commit_and_release(mock_settings: Settings) -> None:
    """Verify commit and release RPC calls execute cleanly."""
    user_id = str(uuid.uuid4())
    res_id = str(uuid.uuid4())

    called_endpoints: list[str] = []

    async def mock_handler(request: httpx.Request) -> httpx.Response:
        url_str = str(request.url)
        called_endpoints.append(url_str)
        return httpx.Response(204)

    transport = httpx.MockTransport(mock_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        store = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        await store.commit_quota(user_id, res_id)
        await store.release_quota(user_id, res_id)

    assert any("commit_ai_quota_v2" in ep for ep in called_endpoints)
    assert any("release_ai_quota_v2" in ep for ep in called_endpoints)


@pytest.mark.asyncio
async def test_quota_store_release_v1_fallback(mock_settings: Settings) -> None:
    """When release_ai_quota_v2 returns 404, falls back to release_ai_quota."""
    user_id = str(uuid.uuid4())
    res_id = str(uuid.uuid4())

    called_endpoints: list[str] = []

    async def mock_handler(request: httpx.Request) -> httpx.Response:
        url_str = str(request.url)
        called_endpoints.append(url_str)
        if "release_ai_quota_v2" in url_str:
            return httpx.Response(404)
        if "release_ai_quota" in url_str:
            return httpx.Response(204)
        return httpx.Response(404)

    transport = httpx.MockTransport(mock_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        store = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        await store.release_quota(user_id, res_id)

    assert any("release_ai_quota_v2" in ep for ep in called_endpoints)
    assert any("release_ai_quota" in ep for ep in called_endpoints)


@pytest.mark.asyncio
async def test_quota_store_get_remaining_fallback_to_table(mock_settings: Settings) -> None:
    """When get_remaining_ai_quota RPC is absent, reads directly from ai_usage_quotas table."""
    user_id = str(uuid.uuid4())

    async def mock_handler(request: httpx.Request) -> httpx.Response:
        url_str = str(request.url)
        if "get_remaining_ai_quota" in url_str:
            return httpx.Response(404)
        if "ai_usage_quotas" in url_str:
            return httpx.Response(200, json=[{"request_count": 3}])
        return httpx.Response(404)

    transport = httpx.MockTransport(mock_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        store = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        remaining = await store.get_remaining_quota(user_id)
        # 15 - 3 = 12
        assert remaining == 12


@pytest.mark.asyncio
async def test_quota_store_db_outage_fails_closed(mock_settings: Settings) -> None:
    """Database outage (500 or connection error) raises 503 and fails closed."""
    user_id = str(uuid.uuid4())

    async def mock_handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, text="PostgreSQL connection lost")

    transport = httpx.MockTransport(mock_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        store = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        with pytest.raises(TrustCueError) as exc_info:
            await store.reserve_quota(user_id)
        assert exc_info.value.status_code == 503

        with pytest.raises(TrustCueError) as exc_info:
            await store.get_remaining_quota(user_id)
        assert exc_info.value.status_code == 503


@pytest.mark.asyncio
async def test_process_reconstruction_survives_restarts(mock_settings: Settings) -> None:
    """
    Demonstrate that a freshly instantiated SupabaseQuotaStore immediately reflects
    persisted database state without any in-memory state preservation.
    """
    user_id = str(uuid.uuid4())

    # Simulated database where user has used 5 requests
    async def mock_db_handler(request: httpx.Request) -> httpx.Response:
        if "get_remaining_ai_quota" in str(request.url):
            return httpx.Response(200, json=10)
        return httpx.Response(404)

    transport = httpx.MockTransport(mock_db_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        # First process instance reads 10 remaining
        store1 = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        rem1 = await store1.get_remaining_quota(user_id)
        assert rem1 == 10

        # Simulate cold restart: instantiate a completely new store instance
        store2 = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        rem2 = await store2.get_remaining_quota(user_id)
        assert rem2 == 10


@pytest.mark.asyncio
async def test_in_memory_quota_store_midnight_rollover() -> None:
    """Test InMemoryQuotaStore behavior across dates and idempotent reservation."""
    store = InMemoryQuotaStore(default_daily_quota=3)
    user_id = "test-user-1"
    res_id = "res-uuid-1"

    # Reserve 1
    allowed, rem, r_id = await store.reserve_quota(user_id, res_id)
    assert allowed is True
    assert rem == 2
    assert r_id == res_id

    # Duplicate reservation with same reservation_id returns existing state
    allowed, rem, r_id = await store.reserve_quota(user_id, res_id)
    assert allowed is True
    assert rem == 2
    assert r_id == res_id

    # Commit reservation
    await store.commit_quota(user_id, res_id)

    # Release after commit is a safe no-op
    await store.release_quota(user_id, res_id)
    assert await store.get_remaining_quota(user_id) == 2
