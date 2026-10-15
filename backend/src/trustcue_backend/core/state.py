"""Application lifecycle and operational readiness state management."""

import time
from typing import TYPE_CHECKING, Literal

from trustcue_backend.core.quota import InMemoryQuotaStore, QuotaStore
from trustcue_backend.core.rate_limit import ConcurrencyLimiter, SlidingWindowRateLimiter

if TYPE_CHECKING:
    from trustcue_backend.core.config import Settings
    from trustcue_backend.providers.base import AiProvider


class AppState:
    """Manages application runtime lifecycle, uptime, and readiness state."""

    def __init__(
        self,
        quota_store: QuotaStore | None = None,
        ai_provider: "AiProvider | None" = None,
    ) -> None:
        self.started_at_monotonic: float = time.monotonic()
        self.is_ready: bool = True
        self.is_shutting_down: bool = False
        self.rate_limiter = SlidingWindowRateLimiter()
        self.concurrency_limiter = ConcurrencyLimiter()
        self.quota_store = quota_store or InMemoryQuotaStore()
        self.ai_provider = ai_provider

    @property
    def uptime_seconds(self) -> int:
        """Calculate elapsed process uptime in whole seconds."""
        return int(time.monotonic() - self.started_at_monotonic)

    def is_operational(self) -> bool:
        """Check whether the application foundation is fully operational."""
        return self.is_ready and not self.is_shutting_down

    def mark_ready(self) -> None:
        """Mark application as ready."""
        self.is_ready = True
        self.is_shutting_down = False

    def mark_draining(self) -> None:
        """Transition application to draining / not-ready state during shutdown."""
        self.is_shutting_down = True
        self.is_ready = False

    def get_readiness_status(
        self, settings: "Settings | None" = None
    ) -> tuple[Literal["ready", "degraded"], dict[str, str]]:
        """
        Evaluate readiness for implemented foundation capabilities.

        Does not invent fake database or AI connections. Clearly reports
        foundation status and indicates configured/unconfigured state.
        Never makes paid network calls from routine readiness probes.
        """
        if self.is_operational():
            auth_status = (
                "ok"
                if (settings and (settings.SUPABASE_JWT_SECRET or settings.SUPABASE_JWKS_URL))
                else "unconfigured"
            )
            ai_status = "unconfigured"
            if settings:
                if not settings.ENABLE_CLOUD_AI:
                    ai_status = "disabled"
                elif settings.GROQ_API_KEY and settings.GROQ_API_KEY.strip():
                    ai_status = "ok"
                else:
                    ai_status = "unconfigured"

            return "ready", {
                "foundation": "ok",
                "authProvider": auth_status,
                "database": "unconfigured",
                "aiProvider": ai_status,
            }

        return "degraded", {
            "foundation": "degraded",
            "authProvider": "error",
            "database": "error",
            "aiProvider": "error",
        }
