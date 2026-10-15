"""Pytest fixtures for TrustCue backend test suite."""

from collections.abc import Generator

import pytest
from starlette.testclient import TestClient

from trustcue_backend.core.config import Settings
from trustcue_backend.main import create_app


@pytest.fixture
def default_settings() -> Settings:
    """Return default settings instance."""
    return Settings(
        ENVIRONMENT="test",
        HOST="127.0.0.1",
        PORT=8000,
        DEBUG=False,
        DOCS_ENABLED=True,
        CORS_ALLOWED_ORIGINS=[],
        LOG_LEVEL="DEBUG",
        ENABLE_CLOUD_AI=False,
        ENABLE_CLOUD_AUTH=False,
        ENABLE_CLOUD_SYNC=False,
    )


@pytest.fixture
def client(default_settings: Settings) -> Generator[TestClient, None, None]:
    """Provide a TestClient with lifespan context active."""
    app = create_app(settings=default_settings)
    with TestClient(app) as test_client:
        yield test_client
