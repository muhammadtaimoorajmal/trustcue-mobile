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
        self.deleted_users: set[str] = set()
        self.profile_display_names: dict[str, str | None] = {}

    def mark_user_deleted(self, user_id: str) -> None:
        """Record user UUID as permanently deleted to immediately reject subsequent sessions."""
        self.deleted_users.add(str(user_id).strip().lower())
        self.profile_display_names.pop(str(user_id).strip(), None)

    def is_user_deleted(self, user_id: str) -> bool:
        """Check whether user UUID has been marked deleted."""
        return str(user_id).strip().lower() in self.deleted_users

    def get_display_name(self, user_id: str) -> str | None:
        """Retrieve local in-memory display name if set."""
        return self.profile_display_names.get(str(user_id).strip())

    def set_display_name(self, user_id: str, display_name: str | None) -> None:
        """Store local in-memory display name."""
        self.profile_display_names[str(user_id).strip()] = display_name


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

        Subsystem Field Semantics:
        - 'foundation': 'ok' when process is operational; 'degraded' during draining/shutdown.
        - 'authProvider': 'ok' when JWT secrets or JWKS URLs are configured; 'unconfigured' on defaults.
        - 'database': 'unconfigured' until persistent connection pooling is configured.
        - 'aiProvider':
            - 'disabled': ENABLE_CLOUD_AI feature flag is False.
            - 'unconfigured': ENABLE_CLOUD_AI is True but GROQ_API_KEY is not configured.
            - 'ok': ENABLE_CLOUD_AI is True and GROQ_API_KEY is configured (adapter initialized).
              NOTE: 'ok' denotes local configuration readiness; external network probes are
              intentionally omitted to avoid paid inference costs and probe latency.
            - 'error': Process is draining or experienced fatal initialization error.

        Does not invent fake database or AI connections. Never makes paid network calls from routine probes.
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
