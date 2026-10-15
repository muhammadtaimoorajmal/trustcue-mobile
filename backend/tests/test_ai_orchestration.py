"""Tests for the ProtectedAiService orchestration, quota accounting, and error handling."""

import uuid
from unittest.mock import AsyncMock

import pytest

from trustcue_backend.api.schemas.analysis import AnalysisAiRequest, InputSource
from trustcue_backend.core.auth import AuthenticatedUser
from trustcue_backend.core.config import Settings
from trustcue_backend.core.quota import InMemoryQuotaStore
from trustcue_backend.providers.base import AiProvider
from trustcue_backend.providers.exceptions import (
    ProviderAuthenticationError,
    ProviderConfigurationError,
    ProviderTimeoutError,
)
from trustcue_backend.providers.models import (
    ProviderAnalysisResult,
)
from trustcue_backend.providers.service import ProtectedAiService


def _create_test_user(user_id: str | None = None) -> AuthenticatedUser:
    """Helper to construct an AuthenticatedUser."""
    uid = user_id or str(uuid.uuid4())
    return AuthenticatedUser(
        user_id=uid,
        email="user@example.com",
        email_verified=True,
        role="authenticated",
        claims={"sub": uid, "role": "authenticated"},
    )


def _create_test_request(text: str = "Test message to evaluate") -> AnalysisAiRequest:
    """Helper to construct a valid AnalysisAiRequest."""
    return AnalysisAiRequest(
        snapshotId="snap-12345",
        text=text,
        source=InputSource.messageText,
        sourceRevision="rev-1",
        clientTimestamp="2026-10-15T12:00:00Z",
    )


@pytest.mark.asyncio
async def test_orchestration_success_commits_quota() -> None:
    """Verify successful AI analysis commits the reserved quota slot."""
    settings = Settings(ENABLE_CLOUD_AI=True, GROQ_API_KEY="gsk_test")
    quota_store = InMemoryQuotaStore(default_daily_quota=15)
    user = _create_test_user()
    user_id = str(user.user_id)

    # Reserve quota upfront
    success, remaining_before, res_id = await quota_store.reserve_quota(user_id)
    assert success is True
    assert remaining_before == 14
    assert res_id is not None

    mock_provider = AsyncMock(spec=AiProvider)
    mock_provider.analyze.return_value = ProviderAnalysisResult(
        provider="groq-cloud",
        model="llama-3.3-70b-versatile",
        factual_summary="Analysis completed successfully.",
        findings=[],
        uncertainty_notes=[],
        suggested_actions=[],
    )

    service = ProtectedAiService(
        settings=settings,
        provider=mock_provider,
        quota_store=quota_store,
    )

    req = _create_test_request("Suspicious payment message")
    result = await service.execute_analysis(
        payload=req,
        current_user=user,
        request_id="req-orch-1",
        reservation_id=res_id,
    )

    assert result.provider == "groq-cloud"
    # Quota was committed (not released)
    remaining_after = await quota_store.get_remaining_quota(user_id)
    assert remaining_after == 14  # Remains consumed

    # Releasing committed reservation should have no effect (already committed)
    await quota_store.release_quota(user_id, res_id)
    assert await quota_store.get_remaining_quota(user_id) == 14


@pytest.mark.asyncio
async def test_orchestration_disabled_feature_refunds_quota() -> None:
    """Verify that disabled cloud AI feature immediately refunds reserved quota."""
    settings = Settings(ENABLE_CLOUD_AI=False)
    quota_store = InMemoryQuotaStore(default_daily_quota=15)
    user = _create_test_user()
    user_id = str(user.user_id)

    _, remaining_before, res_id = await quota_store.reserve_quota(user_id)
    assert remaining_before == 14

    service = ProtectedAiService(
        settings=settings,
        provider=None,
        quota_store=quota_store,
    )

    req = _create_test_request()
    with pytest.raises(ProviderConfigurationError) as exc_info:
        await service.execute_analysis(
            payload=req,
            current_user=user,
            request_id="req-orch-2",
            reservation_id=res_id,
        )

    assert "not enabled" in str(exc_info.value)
    # Quota must be refunded back to 15
    remaining_after = await quota_store.get_remaining_quota(user_id)
    assert remaining_after == 15


@pytest.mark.asyncio
async def test_orchestration_missing_provider_refunds_quota() -> None:
    """Verify missing provider adapter refunds reserved quota."""
    settings = Settings(ENABLE_CLOUD_AI=True, GROQ_API_KEY="gsk_test")
    quota_store = InMemoryQuotaStore(default_daily_quota=15)
    user = _create_test_user()
    user_id = str(user.user_id)

    _, remaining_before, res_id = await quota_store.reserve_quota(user_id)
    assert remaining_before == 14

    service = ProtectedAiService(
        settings=settings,
        provider=None,
        quota_store=quota_store,
    )

    req = _create_test_request()
    with pytest.raises(ProviderConfigurationError):
        await service.execute_analysis(
            payload=req,
            current_user=user,
            request_id="req-orch-3",
            reservation_id=res_id,
        )

    assert await quota_store.get_remaining_quota(user_id) == 15


@pytest.mark.asyncio
async def test_orchestration_connection_timeout_refunds_quota() -> None:
    """Verify connect timeout (pre-transmission) refunds reserved quota."""
    settings = Settings(ENABLE_CLOUD_AI=True, GROQ_API_KEY="gsk_test")
    quota_store = InMemoryQuotaStore(default_daily_quota=15)
    user = _create_test_user()
    user_id = str(user.user_id)

    _, _, res_id = await quota_store.reserve_quota(user_id)

    mock_provider = AsyncMock(spec=AiProvider)
    mock_provider.analyze.side_effect = ProviderTimeoutError(is_connect_timeout=True)

    service = ProtectedAiService(
        settings=settings,
        provider=mock_provider,
        quota_store=quota_store,
    )

    req = _create_test_request()
    with pytest.raises(ProviderTimeoutError):
        await service.execute_analysis(
            payload=req,
            current_user=user,
            request_id="req-orch-4",
            reservation_id=res_id,
        )

    # Connect timeout: refunded
    assert await quota_store.get_remaining_quota(user_id) == 15


@pytest.mark.asyncio
async def test_orchestration_read_timeout_preserves_quota_accounting() -> None:
    """Verify ambiguous read timeout (post-transmission) does NOT refund quota."""
    settings = Settings(ENABLE_CLOUD_AI=True, GROQ_API_KEY="gsk_test")
    quota_store = InMemoryQuotaStore(default_daily_quota=15)
    user = _create_test_user()
    user_id = str(user.user_id)

    _, remaining_before, res_id = await quota_store.reserve_quota(user_id)
    assert remaining_before == 14

    mock_provider = AsyncMock(spec=AiProvider)
    # Ambiguous read timeout: data was already sent to provider LPUs
    mock_provider.analyze.side_effect = ProviderTimeoutError(is_connect_timeout=False)

    service = ProtectedAiService(
        settings=settings,
        provider=mock_provider,
        quota_store=quota_store,
    )

    req = _create_test_request()
    with pytest.raises(ProviderTimeoutError):
        await service.execute_analysis(
            payload=req,
            current_user=user,
            request_id="req-orch-5",
            reservation_id=res_id,
        )

    # Per policy, ambiguous read timeout is NOT refunded
    remaining_after = await quota_store.get_remaining_quota(user_id)
    assert remaining_after == 14


@pytest.mark.asyncio
async def test_orchestration_upstream_failure_refunds_quota() -> None:
    """Verify upstream provider auth/network error refunds reserved quota."""
    settings = Settings(ENABLE_CLOUD_AI=True, GROQ_API_KEY="gsk_test")
    quota_store = InMemoryQuotaStore(default_daily_quota=15)
    user = _create_test_user()
    user_id = str(user.user_id)

    _, _, res_id = await quota_store.reserve_quota(user_id)

    mock_provider = AsyncMock(spec=AiProvider)
    mock_provider.analyze.side_effect = ProviderAuthenticationError()

    service = ProtectedAiService(
        settings=settings,
        provider=mock_provider,
        quota_store=quota_store,
    )

    req = _create_test_request()
    with pytest.raises(ProviderAuthenticationError):
        await service.execute_analysis(
            payload=req,
            current_user=user,
            request_id="req-orch-6",
            reservation_id=res_id,
        )

    assert await quota_store.get_remaining_quota(user_id) == 15
