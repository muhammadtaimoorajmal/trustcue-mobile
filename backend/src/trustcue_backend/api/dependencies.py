"""FastAPI dependency injection providers."""

from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from trustcue_backend.core.auth import AuthenticatedUser, JWTValidator
from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import AuthenticationError
from trustcue_backend.core.state import AppState

bearer_scheme = HTTPBearer(auto_error=False)


def get_app_state(request: Request) -> AppState:
    """Retrieve the application lifecycle state singleton."""
    return request.app.state.app_state  # type: ignore[no-any-return]


def get_app_settings(request: Request) -> Settings:
    """Retrieve the application settings instance."""
    return request.app.state.settings  # type: ignore[no-any-return]


def get_jwt_validator(
    settings: Annotated[Settings, Depends(get_app_settings)],
) -> JWTValidator:
    """Retrieve or construct the configured JWTValidator instance."""
    return JWTValidator(settings=settings)


async def get_current_user(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    validator: Annotated[JWTValidator, Depends(get_jwt_validator)],
) -> AuthenticatedUser:
    """
    Extract and cryptographically validate the Bearer token from the Authorization header.

    Attaches the verified AuthenticatedUser to request.state.current_user.
    Raises AuthenticationError on missing, malformed, or invalid tokens.
    """
    auth_header = request.headers.get("authorization")

    if not auth_header or not auth_header.strip():
        raise AuthenticationError(
            code="unauthorized",
            message="Missing Authorization header.",
        )

    if not credentials or credentials.scheme.lower() != "bearer":
        raise AuthenticationError(
            code="unauthorized",
            message="Invalid authorization scheme; Bearer token required.",
        )

    token = credentials.credentials.strip()
    if not token:
        raise AuthenticationError(
            code="unauthorized",
            message="Bearer token is missing or empty.",
        )

    user = validator.validate_token(token)
    request.state.current_user = user
    return user
