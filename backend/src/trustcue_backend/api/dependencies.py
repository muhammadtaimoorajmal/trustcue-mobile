"""FastAPI dependency injection providers."""

from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from trustcue_backend.core.auth import AuthenticatedUser, JWTValidator
from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import AuthenticationError, TrustCueError
from trustcue_backend.core.quota import QuotaStore
from trustcue_backend.core.rate_limit import ConcurrencyLimiter, SlidingWindowRateLimiter
from trustcue_backend.core.state import AppState

bearer_scheme = HTTPBearer(auto_error=False)


def get_app_state(request: Request) -> AppState:
    """Retrieve the application lifecycle state singleton."""
    return request.app.state.app_state  # type: ignore[no-any-return]


def get_app_settings(request: Request) -> Settings:
    """Retrieve the application settings instance."""
    return request.app.state.settings  # type: ignore[no-any-return]


def get_rate_limiter(
    app_state: Annotated[AppState, Depends(get_app_state)],
) -> SlidingWindowRateLimiter:
    """Retrieve the sliding-window rate limiter singleton."""
    return app_state.rate_limiter


def get_concurrency_limiter(
    app_state: Annotated[AppState, Depends(get_app_state)],
) -> ConcurrencyLimiter:
    """Retrieve the concurrency limiter singleton."""
    return app_state.concurrency_limiter


def get_quota_store(
    app_state: Annotated[AppState, Depends(get_app_state)],
) -> QuotaStore:
    """Retrieve the user daily quota store singleton."""
    return app_state.quota_store


def get_jwt_validator(
    settings: Annotated[Settings, Depends(get_app_settings)],
) -> JWTValidator:
    """Retrieve or construct the configured JWTValidator instance."""
    return JWTValidator(settings=settings)


def enforce_user_ownership(resource_user_id: str, current_user: AuthenticatedUser) -> None:
    """
    Ensure the authenticated user strictly owns the target resource.

    Prevents Cross-Account Access (Insecure Direct Object Reference).
    """
    if str(resource_user_id).strip() != str(current_user.user_id).strip():
        raise TrustCueError(
            code="forbidden",
            message="You do not have permission to access or modify resources owned by another account.",
            status_code=403,
        )


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
