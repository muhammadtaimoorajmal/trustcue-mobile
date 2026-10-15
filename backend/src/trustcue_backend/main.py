"""FastAPI application factory, lifecycle handling, and middleware registration."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from starlette.exceptions import HTTPException as StarletteHTTPException

from trustcue_backend import __version__
from trustcue_backend.api.routes import account, analysis, health
from trustcue_backend.core.body_limiter import RequestBodyLimitMiddleware
from trustcue_backend.core.config import Settings, get_settings
from trustcue_backend.core.errors import (
    TrustCueError,
    http_exception_handler,
    trustcue_error_handler,
    unhandled_exception_handler,
    validation_error_handler,
)
from trustcue_backend.core.logging import (
    PrivacySafeAccessMiddleware,
    configure_logging,
)
from trustcue_backend.core.state import AppState


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Manage application startup and graceful draining lifecycle."""
    # Initialize application lifecycle state
    app_state = AppState()
    app_state.mark_ready()
    app.state.app_state = app_state
    yield
    # Transition to draining state on graceful shutdown
    app_state.mark_draining()


def create_app(settings: Settings | None = None) -> FastAPI:
    """
    Application factory constructing a configured FastAPI service instance.

    Mounts only implemented routes, privacy-safe logging, and sanitized error handlers.
    Planned routes (auth, sync, remote AI) remain unmounted in Module 28 foundation.
    """
    app_settings = settings or get_settings()

    # Configure structured logging
    configure_logging(level=app_settings.LOG_LEVEL)

    # Initialize FastAPI instance
    app = FastAPI(
        title="TrustCue Backend API",
        description=(
            "TrustCue Backend Foundation Service. Provides liveness, readiness, and "
            "privacy-safe operational infrastructure. Local-first analysis remains "
            "operable without this service."
        ),
        version=__version__,
        docs_url="/docs" if app_settings.DOCS_ENABLED else None,
        redoc_url="/redoc" if app_settings.DOCS_ENABLED else None,
        openapi_url="/openapi.json" if app_settings.DOCS_ENABLED else None,
        lifespan=lifespan,
    )

    # Store settings in app state for dependency injection
    app.state.settings = app_settings
    # Default app_state before lifespan starts (useful for test clients)
    app.state.app_state = AppState()

    # 1. Privacy-Safe Request ID & Access Logging Middleware
    app.add_middleware(PrivacySafeAccessMiddleware)

    # 2. Request Body Size Limit Middleware
    app.add_middleware(RequestBodyLimitMiddleware, max_bytes=app_settings.MAX_REQUEST_BODY_BYTES)

    # 3. CORS Middleware (Applied only if explicit origins are configured)
    if app_settings.CORS_ALLOWED_ORIGINS:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=app_settings.CORS_ALLOWED_ORIGINS,
            allow_credentials=False,
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["*"],
        )

    # Register Exception Handlers
    app.add_exception_handler(TrustCueError, trustcue_error_handler)  # type: ignore[arg-type]
    app.add_exception_handler(RequestValidationError, validation_error_handler)  # type: ignore[arg-type]
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)  # type: ignore[arg-type]
    app.add_exception_handler(Exception, unhandled_exception_handler)

    # Mount Implemented Route Handlers
    app.include_router(health.router)
    app.include_router(account.router)
    app.include_router(analysis.router)

    return app


# Default ASGI application instance for Uvicorn
app = create_app()
