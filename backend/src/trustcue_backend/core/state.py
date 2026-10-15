"""Application lifecycle and operational readiness state management."""

import time
from typing import TYPE_CHECKING, Literal

if TYPE_CHECKING:
    from trustcue_backend.core.config import Settings


class AppState:
    """Manages application runtime lifecycle, uptime, and readiness state."""

    def __init__(self) -> None:
        self.started_at_monotonic: float = time.monotonic()
        self.is_ready: bool = True
        self.is_shutting_down: bool = False

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
        """
        if self.is_operational():
            auth_status = (
                "ok"
                if (settings and (settings.SUPABASE_JWT_SECRET or settings.SUPABASE_JWKS_URL))
                else "unconfigured"
            )
            return "ready", {
                "foundation": "ok",
                "authProvider": auth_status,
                "database": "unconfigured",
                "aiProvider": "unconfigured",
            }

        return "degraded", {
            "foundation": "degraded",
            "authProvider": "error",
            "database": "error",
            "aiProvider": "error",
        }
