"""Tests for CORS configuration and browser origin policies."""

from starlette.testclient import TestClient

from trustcue_backend.core.config import Settings
from trustcue_backend.main import create_app


def test_cors_disabled_by_default() -> None:
    """Ensure that with empty origins, CORS headers are not emitted."""
    app = create_app(settings=Settings(CORS_ALLOWED_ORIGINS=[]))
    client = TestClient(app)

    response = client.get("/health", headers={"Origin": "https://malicious.test"})
    assert response.status_code == 200
    assert "Access-Control-Allow-Origin" not in response.headers


def test_cors_allowed_explicit_origin() -> None:
    """Ensure configured origins receive CORS headers, while unauthorized origins do not."""
    allowed = "https://admin.trustcue.test"
    app = create_app(settings=Settings(CORS_ALLOWED_ORIGINS=[allowed]))
    client = TestClient(app)

    # Valid origin
    res_allowed = client.get("/health", headers={"Origin": allowed})
    assert res_allowed.status_code == 200
    assert res_allowed.headers.get("Access-Control-Allow-Origin") == allowed
    # Credentials must be false
    assert res_allowed.headers.get("Access-Control-Allow-Credentials") is None

    # Invalid origin
    res_rejected = client.get("/health", headers={"Origin": "https://unauthorized.test"})
    assert res_rejected.status_code == 200
    assert "Access-Control-Allow-Origin" not in res_rejected.headers
