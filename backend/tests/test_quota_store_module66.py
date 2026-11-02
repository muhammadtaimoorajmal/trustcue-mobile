"""Tests for Module 66 quota store dispatch lifecycle and settlement safety."""

import uuid
from unittest.mock import AsyncMock

import httpx
import pytest

from trustcue_backend.api.schemas.analysis import AnalysisAiRequest, InputSource
from trustcue_backend.core.auth import AuthenticatedUser
from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import TrustCueError
from trustcue_backend.core.quota import InMemoryQuotaStore, SupabaseQuotaStore
from trustcue_backend.providers.base import AiProvider
from trustcue_backend.providers.exceptions import ProviderTimeoutError
from trustcue_backend.providers.models import ProviderAnalysisResult
from trustcue_backend.providers.service import ProtectedAiService
from trustcue_backend.validation.exceptions import OutputValidationError


@pytest.fixture
def mock_settings() -> Settings:
    return Settings(
        ENVIRONMENT="test",
        SUPABASE_URL="https://mock-supabase.test",
        SUPABASE_SERVICE_ROLE_KEY="mock-service-role-key-test-long-enough",
        ENABLE_CLOUD_AI=True,
        GROQ_API_KEY="gsk_mock_api_key_test_value",
    )


def _make_user() -> AuthenticatedUser:
    uid = str(uuid.uuid4())
    return AuthenticatedUser(
        user_id=uid,
        email="user@test.com",
        email_verified=True,
        role="authenticated",
        claims={"sub": uid, "role": "authenticated"},
    )


def _make_request() -> AnalysisAiRequest:
    return AnalysisAiRequest(
        snapshotId="snap-test-123",
        text="Sample text for scam analysis.",
        source=InputSource.messageText,
        sourceRevision="rev-1",
        clientTimestamp="2026-11-02T12:00:00Z",
    )


@pytest.mark.asyncio
async def test_in_memory_quota_store_dispatch_lifecycle() -> None:
    """Validates dispatch_quota in InMemoryQuotaStore."""
    store = InMemoryQuotaStore(default_daily_quota=5)
    user_id = str(uuid.uuid4())

    # Reserve
    allowed, remaining, res_id = await store.reserve_quota(user_id)
    assert allowed is True
    assert res_id is not None

    # Dispatch existing reservation
    dispatch_ok = await store.dispatch_quota(user_id, res_id)
    assert dispatch_ok is True

    # Dispatch unknown reservation
    dispatch_unknown = await store.dispatch_quota(user_id, str(uuid.uuid4()))
    assert dispatch_unknown is False

    # Commit clears reservation
    commit_ok = await store.commit_quota(user_id, res_id)
    assert commit_ok is True

    # Dispatch after commit is False
    dispatch_after = await store.dispatch_quota(user_id, res_id)
    assert dispatch_after is False


@pytest.mark.asyncio
async def test_supabase_quota_store_dispatch_ai_quota_v2(mock_settings: Settings) -> None:
    """Validates SupabaseQuotaStore dispatches to rpc/dispatch_ai_quota_v2."""
    user_id = str(uuid.uuid4())
    res_id = str(uuid.uuid4())
    called_endpoints: list[str] = []

    async def mock_handler(request: httpx.Request) -> httpx.Response:
        url_str = str(request.url)
        called_endpoints.append(url_str)
        if "dispatch_ai_quota_v2" in url_str:
            return httpx.Response(200, json=True)
        return httpx.Response(404)

    transport = httpx.MockTransport(mock_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        store = SupabaseQuotaStore(settings=mock_settings, http_client=client)
        dispatched = await store.dispatch_quota(user_id, res_id)
        assert dispatched is True

    assert any("dispatch_ai_quota_v2" in ep for ep in called_endpoints)


@pytest.mark.asyncio
async def test_supabase_quota_store_rejects_malformed_rpc_responses(mock_settings: Settings) -> None:
    """Validates that non-boolean or corrupt JSON RPC responses raise 503 database_error."""
    user_id = str(uuid.uuid4())
    res_id = str(uuid.uuid4())

    async def mock_handler(request: httpx.Request) -> httpx.Response:
        # Returns dictionary instead of expected boolean scalar
        return httpx.Response(200, json={"unexpected": "corrupt_data"})

    transport = httpx.MockTransport(mock_handler)
    async with httpx.AsyncClient(transport=transport) as client:
        store = SupabaseQuotaStore(settings=mock_settings, http_client=client)

        with pytest.raises(TrustCueError) as commit_exc:
            await store.commit_quota(user_id, res_id)
        assert commit_exc.value.status_code == 503
        assert commit_exc.value.code == "database_error"

        with pytest.raises(TrustCueError) as release_exc:
            await store.release_quota(user_id, res_id)
        assert release_exc.value.status_code == 503
        assert release_exc.value.code == "database_error"


@pytest.mark.asyncio
async def test_protected_ai_service_dispatches_before_provider_inference(mock_settings: Settings) -> None:
    """Verifies that ProtectedAiService marks reservation as dispatched prior to provider call."""
    mock_provider = AsyncMock(spec=AiProvider)
    mock_provider.analyze.return_value = ProviderAnalysisResult(
        provider="mock-provider",
        model="mock-model",
        factual_summary="Summary",
        findings=[],
        uncertainty_notes=[],
        suggested_actions=[],
    )

    mock_quota_store = AsyncMock(spec=InMemoryQuotaStore)
    mock_quota_store.dispatch_quota.return_value = True
    mock_quota_store.commit_quota.return_value = True

    service = ProtectedAiService(
        settings=mock_settings,
        provider=mock_provider,
        quota_store=mock_quota_store,
    )

    user = _make_user()
    request_payload = _make_request()
    res_id = str(uuid.uuid4())

    await service.execute_analysis(
        payload=request_payload,
        current_user=user,
        request_id="req_12345678",
        reservation_id=res_id,
    )

    # Prove dispatch_quota was awaited
    mock_quota_store.dispatch_quota.assert_awaited_once_with(str(user.user_id), res_id)
    # Prove commit_quota was awaited after successful inference
    mock_quota_store.commit_quota.assert_awaited_once_with(str(user.user_id), res_id)


@pytest.mark.asyncio
async def test_ambiguous_read_timeout_retains_quota(mock_settings: Settings) -> None:
    """
    On ambiguous read timeout (is_connect_timeout=False), provider may have processed inference;
    quota reservation must be retained (NEVER refunded).
    """
    mock_provider = AsyncMock(spec=AiProvider)
    mock_provider.analyze.side_effect = ProviderTimeoutError(
        is_connect_timeout=False,
    )

    mock_quota_store = AsyncMock(spec=InMemoryQuotaStore)
    mock_quota_store.dispatch_quota.return_value = True

    service = ProtectedAiService(
        settings=mock_settings,
        provider=mock_provider,
        quota_store=mock_quota_store,
    )

    user = _make_user()
    request_payload = _make_request()
    res_id = str(uuid.uuid4())

    with pytest.raises(ProviderTimeoutError):
        await service.execute_analysis(
            payload=request_payload,
            current_user=user,
            request_id="req_12345678",
            reservation_id=res_id,
        )

    # Prove release_quota was NOT called
    mock_quota_store.release_quota.assert_not_called()


@pytest.mark.asyncio
async def test_connect_timeout_refunds_quota(mock_settings: Settings) -> None:
    """
    On connect timeout (is_connect_timeout=True), connection was never established;
    quota reservation is safely refunded.
    """
    mock_provider = AsyncMock(spec=AiProvider)
    mock_provider.analyze.side_effect = ProviderTimeoutError(
        is_connect_timeout=True,
    )

    mock_quota_store = AsyncMock(spec=InMemoryQuotaStore)
    mock_quota_store.dispatch_quota.return_value = True
    mock_quota_store.release_quota.return_value = True

    service = ProtectedAiService(
        settings=mock_settings,
        provider=mock_provider,
        quota_store=mock_quota_store,
    )

    user = _make_user()
    request_payload = _make_request()
    res_id = str(uuid.uuid4())

    with pytest.raises(ProviderTimeoutError):
        await service.execute_analysis(
            payload=request_payload,
            current_user=user,
            request_id="req_12345678",
            reservation_id=res_id,
        )

    # Prove release_quota was called
    mock_quota_store.release_quota.assert_awaited_once_with(str(user.user_id), res_id)


@pytest.mark.asyncio
async def test_output_validation_failure_commits_quota(mock_settings: Settings) -> None:
    """
    When provider executes inference but returns malformed schema output,
    upstream compute was expended; quota must be permanently committed.
    """
    mock_provider = AsyncMock(spec=AiProvider)
    mock_provider.analyze.side_effect = OutputValidationError("Malformed model output JSON.")

    mock_quota_store = AsyncMock(spec=InMemoryQuotaStore)
    mock_quota_store.dispatch_quota.return_value = True
    mock_quota_store.commit_quota.return_value = True

    service = ProtectedAiService(
        settings=mock_settings,
        provider=mock_provider,
        quota_store=mock_quota_store,
    )

    user = _make_user()
    request_payload = _make_request()
    res_id = str(uuid.uuid4())

    with pytest.raises(OutputValidationError):
        await service.execute_analysis(
            payload=request_payload,
            current_user=user,
            request_id="req_12345678",
            reservation_id=res_id,
        )

    # Prove commit_quota was called, NOT release_quota
    mock_quota_store.commit_quota.assert_awaited_once_with(str(user.user_id), res_id)
    mock_quota_store.release_quota.assert_not_called()
