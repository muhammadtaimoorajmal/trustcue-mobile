"""Protected server-assisted AI scam-indicator analysis endpoints."""

import logging
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
from trustcue_backend.core.rate_limit import ConcurrencyLimiter, SlidingWindowRateLimiter
from trustcue_backend.providers.service import ProtectedAiService

logger = logging.getLogger("trustcue.analysis")

router = APIRouter(prefix="/api/v1/analysis", tags=["Analysis"])


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
            "description": "Text snapshot failed validation (too long, malformed Unicode, empty).",
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
    Validate reviewed text snapshot, enforce rate limits, and dispatch to AI provider.

    In Module 34, the internal analysis pipeline with strict untrusted-output validation and
    exact evidence grounding is fully operational in ProtectedAiService.
    Preserves the public real-user gate (Module 35): public client requests return honest 503
    before acquiring quota reservations or concurrency locks, ensuring zero side effects until
    mobile upload consent and client UX are implemented.
    """
    user_key = f"user:{current_user.user_id}"

    # 1. Abuse prevention: Sliding-window rate limit (10 requests/minute per user)
    await rate_limiter.check_rate_limit(user_key, max_requests=10, window_seconds=60)

    # 2. Gate check: Check feature flag and public consent gate BEFORE side effects
    # (no quota reservation, no concurrency locks, no external network calls).
    if not settings.ENABLE_CLOUD_AI:
        raise TrustCueError(
            code="ai_provider_unavailable",
            message="Server-assisted AI analysis is not enabled in this environment.",
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    # 3. Module 35 Gate: Public real-user cloud AI workflow requires explicit mobile upload consent
    # and consent-audit verification (to be implemented in Module 35).
    # The internal pipeline (validation, evidence grounding, and provider adapter) is fully implemented
    # and verified internally via ProtectedAiService, but public exposure is gated until consent is complete.
    raise TrustCueError(
        code="ai_provider_unavailable",
        message="Server-assisted AI analysis is temporarily unavailable pending mobile upload consent and client workflow implementation (Module 35).",
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
    )
