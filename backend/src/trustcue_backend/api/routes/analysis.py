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
from trustcue_backend.core.quota import InMemoryQuotaStore, QuotaStore
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

    In Module 33, validates the payload and abuse controls strictly, wiring the
    internal provider execution path. Preserves the Module 34 evidence-grounding
    gate: public client responses return 503 until server-side evidence verification
    is implemented, preventing raw or ungrounded model outputs from reaching mobile clients.
    """
    user_key = f"user:{current_user.user_id}"

    # 1. Abuse prevention: Sliding-window rate limit (10 requests/minute per user)
    await rate_limiter.check_rate_limit(user_key, max_requests=10, window_seconds=60)

    # 2. Concurrency limiting: Max 1 in-flight analysis request per user
    async with concurrency_limiter.acquire(user_key):
        # 3. Quota reservation: Daily limit check
        if isinstance(quota_store, InMemoryQuotaStore):
            res_id = await quota_store.enforce_quota(current_user.user_id)
        else:
            success, remaining, res_id = await quota_store.reserve_quota(current_user.user_id)
            if not success or res_id is None:
                raise TrustCueError(
                    code="rate_limit_exceeded",
                    message="Daily AI analysis quota exhausted.",
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                )

        try:
            # 4. Feature flag gating: Return factual 503 if not enabled
            if not settings.ENABLE_CLOUD_AI:
                await quota_store.release_quota(current_user.user_id, res_id)
                raise TrustCueError(
                    code="ai_provider_unavailable",
                    message="Server-assisted AI analysis is not enabled in this environment.",
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                )

            # 5. Module 34 & 35 Gate: Raw provider output must NOT be returned to clients
            # without deterministic server-side evidence grounding and mobile consent.
            # Refund reserved quota unit and return honest 503 indicating grounding status.
            await quota_store.release_quota(current_user.user_id, res_id)
            raise TrustCueError(
                code="ai_provider_unavailable",
                message="Server-assisted AI analysis is temporarily unavailable pending evidence grounding validation (Module 34).",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except Exception:
            # Re-raise without logging user text
            logger.info("AI analysis request completed/aborted for user UUID: %s", current_user.user_id)
            raise

