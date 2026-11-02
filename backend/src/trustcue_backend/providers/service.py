"""Protected AI orchestration service coordinating provider execution, validation, and quota accounting."""

import logging
import time

from trustcue_backend.api.schemas.analysis import (
    AnalysisAiRequest,
    AnalysisAiResponse,
)
from trustcue_backend.core.auth import AuthenticatedUser
from trustcue_backend.core.config import Settings
from trustcue_backend.core.quota import QuotaStore
from trustcue_backend.core.telemetry import record_stage_duration
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
       - Inference completed -> permanently commit quota; commit failure must NEVER refund.
       - Validation or grounding failure after inference -> retain quota (tokens were consumed;
         prevents adversarial free inference loops).
    4. Measures monotonic durations for each discrete operational stage via telemetry.
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
        Execute protected AI analysis against the configured provider with strict output validation.
        """
        user_id = str(current_user.user_id)

        # 1. Enforce feature flag and provider readiness
        if not self.settings.ENABLE_CLOUD_AI:
            if reservation_id:
                try:
                    await self.quota_store.release_quota(user_id, reservation_id)
                except Exception as rel_err:
                    logger.warning("Failed to release quota on disabled cloud AI: %s", rel_err)
            raise ProviderConfigurationError("Cloud AI analysis feature is not enabled.")

        if self.provider is None:
            if reservation_id:
                try:
                    await self.quota_store.release_quota(user_id, reservation_id)
                except Exception as rel_err:
                    logger.warning("Failed to release quota on missing provider: %s", rel_err)
            raise ProviderConfigurationError("Cloud AI provider is unconfigured or unavailable.")

        # Construct bounded internal provider request preserving exact reviewed text
        provider_request = ProviderAnalysisRequest(
            snapshot_id=payload.snapshotId,
            text=payload.text,  # Exact approved text preserved without alteration
            request_id=request_id,
        )

        # 2. Mark reservation as dispatched prior to external network call
        if reservation_id:
            t_disp = time.perf_counter()
            try:
                disp_ok = await self.quota_store.dispatch_quota(user_id, reservation_id)
                disp_ms = round((time.perf_counter() - t_disp) * 1000, 2)
                record_stage_duration(
                    stage="quota_dispatch",
                    duration_ms=disp_ms,
                    outcome="success" if disp_ok else "database_error",
                )
            except Exception as disp_err:
                disp_ms = round((time.perf_counter() - t_disp) * 1000, 2)
                record_stage_duration(
                    stage="quota_dispatch",
                    duration_ms=disp_ms,
                    outcome="database_error",
                )
                logger.warning("Failed to dispatch quota reservation %s: %s", reservation_id, disp_err)

        # 3. Execute upstream provider inference
        t_infer = time.perf_counter()
        try:
            result = await self.provider.analyze(provider_request)
            infer_ms = round((time.perf_counter() - t_infer) * 1000, 2)
            record_stage_duration(
                stage="provider_inference",
                duration_ms=infer_ms,
                outcome="success",
            )
        except ProviderTimeoutError as exc:
            infer_ms = round((time.perf_counter() - t_infer) * 1000, 2)
            if exc.is_connect_timeout:
                # Connection was not established; safe to refund quota
                record_stage_duration(
                    stage="provider_inference",
                    duration_ms=infer_ms,
                    outcome="provider_timeout_connect",
                )
                if reservation_id:
                    try:
                        await self.quota_store.release_quota(user_id, reservation_id)
                        logger.info(
                            "Refunded quota reservation %s after connect timeout for user %s",
                            reservation_id,
                            user_id,
                        )
                    except Exception as rel_err:
                        logger.warning("Failed to release quota after connect timeout: %s", rel_err)
            else:
                # Ambiguous read timeout: provider may have consumed inference resources.
                # Per documented accounting policy, ambiguous read timeouts are NOT refunded.
                record_stage_duration(
                    stage="provider_inference",
                    duration_ms=infer_ms,
                    outcome="provider_timeout_read",
                )
                logger.info(
                    "Retained quota reservation %s on ambiguous read timeout for user %s",
                    reservation_id,
                    user_id,
                )
            raise

        except OutputValidationError as exc:
            # The provider completed inference, but generated output failed schema parsing.
            # Upstream compute was expended, so quota remains committed.
            infer_ms = round((time.perf_counter() - t_infer) * 1000, 2)
            record_stage_duration(
                stage="provider_inference",
                duration_ms=infer_ms,
                outcome="malformed_output",
            )
            if reservation_id:
                try:
                    await self.quota_store.commit_quota(user_id, reservation_id)
                except Exception as commit_err:
                    logger.error(
                        "Quota commit failed after OutputValidationError for reservation %s: %s",
                        reservation_id,
                        commit_err,
                    )
            logger.warning(
                "AI output schema validation failed after inference for user %s (quota retained): %s",
                user_id,
                type(exc).__name__,
            )
            raise

        except Exception as exc:
            # Deterministic upstream failures (e.g. 401 auth, 429 rate limit, 503 unavailable, network drop):
            # Safe to release quota reservation.
            infer_ms = round((time.perf_counter() - t_infer) * 1000, 2)
            record_stage_duration(
                stage="provider_inference",
                duration_ms=infer_ms,
                outcome="provider_error",
            )
            if reservation_id:
                try:
                    await self.quota_store.release_quota(user_id, reservation_id)
                    logger.info(
                        "Released quota reservation %s after provider failure for user %s: %s",
                        reservation_id,
                        user_id,
                        type(exc).__name__,
                    )
                except Exception as rel_err:
                    logger.warning("Failed to release quota after provider failure: %s", rel_err)
            raise

        # 4. Provider inference completed successfully: compute was expended!
        # Settle quota reservation permanently. Commit failure must NEVER trigger quota refund.
        if reservation_id:
            t_settle = time.perf_counter()
            try:
                commit_ok = await self.quota_store.commit_quota(user_id, reservation_id)
                settle_ms = round((time.perf_counter() - t_settle) * 1000, 2)
                record_stage_duration(
                    stage="quota_settle",
                    duration_ms=settle_ms,
                    outcome="success" if commit_ok else "database_error",
                )
                if not commit_ok:
                    logger.warning(
                        "Quota reservation %s commit returned False for user %s (already settled or missing)",
                        reservation_id,
                        user_id,
                    )
            except Exception as commit_err:
                settle_ms = round((time.perf_counter() - t_settle) * 1000, 2)
                record_stage_duration(
                    stage="quota_settle",
                    duration_ms=settle_ms,
                    outcome="database_error",
                )
                logger.error(
                    "Quota commit failed for reservation %s for user %s: %s",
                    reservation_id,
                    user_id,
                    commit_err,
                )

        # 5. Now ground the validated raw output against the exact submitted text
        t_ground = time.perf_counter()
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
            ground_ms = round((time.perf_counter() - t_ground) * 1000, 2)
            record_stage_duration(
                stage="grounding",
                duration_ms=ground_ms,
                outcome="success",
            )
            return grounded_response

        except (OutputValidationError, EvidenceGroundingError) as exc:
            ground_ms = round((time.perf_counter() - t_ground) * 1000, 2)
            outcome = "grounding_failed" if isinstance(exc, EvidenceGroundingError) else "malformed_output"
            record_stage_duration(
                stage="grounding",
                duration_ms=ground_ms,
                outcome=outcome,
            )
            # Per documented accounting policy: provider inference was already executed,
            # so quota remains committed to prevent free inference abuse loops.
            logger.warning(
                "AI output validation/grounding failed after inference for user %s (quota retained): %s",
                user_id,
                type(exc).__name__,
            )
            raise
