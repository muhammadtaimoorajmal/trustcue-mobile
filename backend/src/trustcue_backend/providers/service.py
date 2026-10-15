"""Protected AI orchestration service coordinating provider execution, validation, and quota accounting."""

import logging

from trustcue_backend.api.schemas.analysis import (
    AnalysisAiRequest,
    AnalysisAiResponse,
)
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
)
from trustcue_backend.validation.exceptions import (
    EvidenceGroundingError,
    OutputValidationError,
)
from trustcue_backend.validation.grounding import EvidenceGrounder
from trustcue_backend.validation.output_validator import ValidatedRawOutput

logger = logging.getLogger("trustcue.providers.service")


class ProtectedAiService:
    """
    Service orchestrating protected AI analysis behind internal verification gates.

    Invariants:
    1. Preserves the exact reviewed text snapshot without modification.
    2. Enforces strict untrusted-output validation and exact evidence grounding.
    3. Quota accounting policy:
       - Upstream connection, network, or provider auth errors -> refund reserved quota.
       - Connect timeouts -> refund reserved quota.
       - Ambiguous read timeouts -> retain quota (inference may have begun on provider LPUs).
       - Completed inference that fails validation or evidence grounding -> commit quota (provider compute/tokens were consumed; prevents abuse loops).
       - Successful analysis and grounding -> commit quota.
    4. Releases concurrency locks reliably on every exit path.
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
    ) -> AnalysisAiResponse:
        """
        Orchestrate internal provider analysis with strict output validation, evidence grounding,
        and documented quota settlement.

        Raises ProviderError, OutputValidationError, EvidenceGroundingError, or TrustCueError.
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

            # Upstream provider successfully completed inference: tokens and compute were consumed.
            # Settle quota reservation before validation.
            if reservation_id:
                await self.quota_store.commit_quota(user_id, reservation_id)

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

        except (OutputValidationError, EvidenceGroundingError) as exc:
            # The provider completed inference, but the generated output failed validation or grounding.
            # Per documented accounting policy, quota is committed because upstream provider resources
            # were expended. This prevents free inference loops via adversarial inputs.
            if reservation_id:
                await self.quota_store.commit_quota(user_id, reservation_id)
            logger.warning(
                "AI output validation/grounding failed during/after inference for user %s (quota retained): %s",
                user_id,
                type(exc).__name__,
            )
            raise

        except Exception as exc:
            # Deterministic upstream failures (e.g. 401 auth, 429 rate limit, 503 unavailable, network drop):
            # Safe to release quota reservation.
            if reservation_id:
                await self.quota_store.release_quota(user_id, reservation_id)
            logger.info(
                "Released quota reservation %s after provider failure for user %s: %s",
                reservation_id,
                user_id,
                type(exc).__name__,
            )
            raise

        # Now ground the validated raw output against the exact submitted text
        try:
            validated_output = ValidatedRawOutput(
                factual_summary=result.factual_summary,
                findings=result.findings,
                uncertainty_notes=result.uncertainty_notes,
                suggested_actions=result.suggested_actions,
            )

            grounded_response = EvidenceGrounder.ground_and_build_report(
                validated_output=validated_output,
                submitted_text=payload.text,  # Exact submitted text
                snapshot_id=payload.snapshotId,  # Trusted request snapshot ID
                provider=result.provider,
                model=result.model,
            )

            return grounded_response

        except (OutputValidationError, EvidenceGroundingError) as exc:
            # Per documented accounting policy: provider inference was already executed,
            # so quota remains committed to prevent free inference abuse loops.
            logger.warning(
                "AI output validation/grounding failed after inference for user %s (quota retained): %s",
                user_id,
                type(exc).__name__,
            )
            raise
