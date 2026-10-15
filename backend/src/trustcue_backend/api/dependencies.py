"""FastAPI dependency injection providers."""

from fastapi import Request

from trustcue_backend.core.config import Settings
from trustcue_backend.core.state import AppState


def get_app_state(request: Request) -> AppState:
    """Retrieve the application lifecycle state singleton."""
    return request.app.state.app_state  # type: ignore[no-any-return]


def get_app_settings(request: Request) -> Settings:
    """Retrieve the application settings instance."""
    return request.app.state.settings  # type: ignore[no-any-return]
