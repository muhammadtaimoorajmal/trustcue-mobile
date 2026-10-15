"""Protected server-assisted AI scam-indicator analysis endpoints."""

import logging
import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, status

from trustcue_backend.api.dependencies import (
    get_app_settings,
    get_concurrency_limiter,
    get_current_user,
    get_protected_ai_service,
    get_quota_store,
    get_rate_limiter,
)
from trustcue_backend.api.schemas.analysis import (
    AnalysisAiRequest,
    AnalysisAiResponse,
)
from trustcue_backend.core.auth import AuthenticatedUser
from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import TrustCueError
from trustcue_backend.core.quota import QuotaStore
from trustcue_backend.core.rate_limit import (
    ConcurrencyLimiter,
    RateLimitExceeded,
    SlidingWindowRateLimiter,
)
from trustcue_backend.providers.service import ProtectedAiService

logger = logging.getLogger("trustcue.analysis")

router = APIRouter(prefix="/api/v1/analysis", tags=["Analysis"])

SUPPORTED_DISCLOSURE_VERSIONS = {"1.0.0"}
SUPPORTED_CONSENT_RECIPIENTS = {"trustcue-backend"}
SUPPORTED_CONSENT_PROVIDERS = {"groq-cloud", "google-gemini", "mock-provider"}


def _seconds_until_midnight_utc() -> int:
    """Calculate remaining seconds until 00:00 UTC."""
    now = datetime.now(UTC)
    tomorrow = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    return max(1, int((tomorrow - now).total_seconds()))


@router.post(
    "/ai",
    response_model=AnalysisAiResponse,
    summary="Protected Server-Assisted AI Analysis",
    description=(
        "Evaluates a user-reviewed, user-consented text snapshot for potential scam "
        "warning indicators using a server-side AI model. "
        "User text is treated strictly as untrusted data."
    ),
    operation_id="analyzeTextWithAi",
    responses={
        200: {
            "model": AnalysisAiResponse,
            "description": "Analysis completed successfully.",
        },
        400: {
            "description": "Text snapshot failed validation or missing/invalid upload consent.",
        },
        401: {
            "description": "Unauthorized. Missing, expired, or invalid JWT bearer token.",
        },
        413: {
            "description": "Payload Too Large. Request exceeds body size limit.",
        },
        429: {
            "description": "Too Many Requests. Per-user rate limit or daily quota exceeded.",
        },
        502: {
            "description": "Bad Gateway. AI provider returned untrusted, ungrounded, or invalid output.",
        },
        503: {
            "description": "AI provider service unavailable or not enabled.",
        },
    },
)
async def analyze_text_with_ai(
    payload: AnalysisAiRequest,
    current_user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    settings: Annotated[Settings, Depends(get_app_settings)],
    rate_limiter: Annotated[SlidingWindowRateLimiter, Depends(get_rate_limiter)],
    concurrency_limiter: Annotated[ConcurrencyLimiter, Depends(get_concurrency_limiter)],
    quota_store: Annotated[QuotaStore, Depends(get_quota_store)],
    ai_service: Annotated[ProtectedAiService, Depends(get_protected_ai_service)],
) -> AnalysisAiResponse:
    """
    Validate reviewed text snapshot and explicit upload consent, enforce rate limits, and dispatch to AI provider.

    In Module 35, the endpoint is fully operational when:
    1. The client supplies explicit per-request upload consent (granted=True, supported disclosure version).
    2. Cloud AI is enabled and an AI provider adapter is configured.
    3. User has remaining daily quota and does not exceed rate/concurrency limits.
    Consent validation occurs BEFORE quota reservation or external provider calls.
    """
    user_key = f"user:{current_user.user_id}"

    # 1. Abuse prevention: Sliding-window rate limit (10 requests/minute per user)
    await rate_limiter.check_rate_limit(user_key, max_requests=10, window_seconds=60)

    # 2. Gate check: Check feature flag and provider configuration
    if not settings.ENABLE_CLOUD_AI:
        raise TrustCueError(
            code="ai_provider_unavailable",
            message="Server-assisted AI analysis is not enabled in this environment.",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    if ai_service.provider is None:
        raise TrustCueError(
            code="ai_provider_unavailable",
            message="AI provider adapter is not configured or disabled.",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    # 3. Explicit per-request upload consent validation (Module 35)
    # Evaluated BEFORE quota reservation, locks, or external provider calls.
    if payload.consent is None or not payload.consent.granted:
        raise TrustCueError(
            code="consent_required",
            message="Explicit user upload consent is required to transmit text for server-assisted AI analysis.",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    if payload.consent.disclosureVersion not in SUPPORTED_DISCLOSURE_VERSIONS:
        raise TrustCueError(
            code="unsupported_disclosure_version",
            message=f"Consent disclosure version '{payload.consent.disclosureVersion}' is not supported.",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    if payload.consent.recipient not in SUPPORTED_CONSENT_RECIPIENTS:
        raise TrustCueError(
            code="invalid_consent_recipient",
            message=f"Consent recipient '{payload.consent.recipient}' is invalid.",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    if payload.consent.provider not in SUPPORTED_CONSENT_PROVIDERS:
        raise TrustCueError(
            code="unsupported_ai_provider",
            message=f"Consent provider '{payload.consent.provider}' is not supported.",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    # 4. Atomic daily quota reservation
    allowed, remaining, reservation_id = await quota_store.reserve_quota(str(current_user.user_id))
    if not allowed:
        raise RateLimitExceeded(
            code="daily_quota_exceeded",
            message="Daily AI analysis request quota exceeded. Resets at 00:00 UTC.",
            retry_after=_seconds_until_midnight_utc(),
        )

    # 5. Concurrency limit (max in-flight operations per user)
    request_id = str(uuid.uuid4())
    async with concurrency_limiter.acquire(user_key):
        return await ai_service.execute_analysis(
            payload=payload,
            current_user=current_user,
            request_id=request_id,
            reservation_id=reservation_id,
        )
