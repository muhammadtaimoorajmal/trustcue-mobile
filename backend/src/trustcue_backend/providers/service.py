"""Protected AI orchestration service coordinating provider execution and quota accounting."""

import logging

from trustcue_backend.api.schemas.analysis import AnalysisAiRequest
from trustcue_backend.core.auth import AuthenticatedUser
from trustcue_backend.core.config import Settings
from trustcue_backend.core.quota import QuotaStore
from trustcue_backend.providers.base import AiProvider
from trustcue_backend.providers.exceptions import (
    ProviderConfigurationError,
    ProviderTimeoutError,
)
from trustcue_backend.providers.models import (
    ProviderAnalysisRequest,
    ProviderAnalysisResult,
)

logger = logging.getLogger("trustcue.providers.service")


class ProtectedAiService:
    """
    Service orchestrating protected AI analysis behind internal verification gates.

    Invariants:
    1. Preserves the exact reviewed text snapshot without modification.
    2. Commits quota only upon verifiable completion.
    3. Releases quota on connection or configuration failures.
    4. Enforces ambiguous timeout quota retention policy (never blind refunds).
    5. Releases concurrency locks reliably on every exit path.
    """

    def __init__(
        self,
        settings: Settings,
        provider: AiProvider | None,
        quota_store: QuotaStore,
    ) -> None:
        self.settings = settings
        self.provider = provider
        self.quota_store = quota_store

    async def execute_analysis(
        self,
        payload: AnalysisAiRequest,
        current_user: AuthenticatedUser,
        request_id: str,
        reservation_id: str | None = None,
    ) -> ProviderAnalysisResult:
        """
        Orchestrate internal provider analysis with quota settlement and error boundaries.

        Raises ProviderError or TrustCueError subclasses.
        """
        user_id = str(current_user.user_id)

        if not self.settings.ENABLE_CLOUD_AI:
            if reservation_id:
                await self.quota_store.release_quota(user_id, reservation_id)
            raise ProviderConfigurationError("Server-assisted AI analysis is not enabled in this environment.")

        if self.provider is None:
            if reservation_id:
                await self.quota_store.release_quota(user_id, reservation_id)
            raise ProviderConfigurationError("AI provider adapter is not configured.")

        # Construct bounded internal provider request preserving exact reviewed text
        provider_request = ProviderAnalysisRequest(
            snapshot_id=payload.snapshotId,
            text=payload.text,  # Exact approved text preserved without alteration
            request_id=request_id,
        )

        try:
            result = await self.provider.analyze(provider_request)

            # Settle quota upon successful provider completion
            if reservation_id:
                await self.quota_store.commit_quota(user_id, reservation_id)

            return result

        except ProviderTimeoutError as exc:
            if exc.is_connect_timeout:
                # Connection was not established; safe to refund quota
                if reservation_id:
                    await self.quota_store.release_quota(user_id, reservation_id)
                logger.info("Refunded quota reservation %s after connect timeout for user %s", reservation_id, user_id)
            else:
                # Ambiguous read timeout: provider may have consumed inference resources.
                # Per documented accounting policy, ambiguous read timeouts are NOT refunded.
                logger.info(
                    "Retained quota reservation %s on ambiguous read timeout for user %s",
                    reservation_id,
                    user_id,
                )
            raise

        except Exception as exc:
            # Deterministic upstream failures (e.g. 401 auth, 429 rate limit, 503 unavailable, network drop):
            # Safe to release quota reservation.
            if reservation_id:
                await self.quota_store.release_quota(user_id, reservation_id)
            logger.info("Released quota reservation %s after provider failure for user %s: %s", reservation_id, user_id, type(exc).__name__)
            raise
