"""Tests for privacy-safe error handling and sanitized envelopes."""

from fastapi import APIRouter
from pydantic import BaseModel
from starlette.testclient import TestClient

from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import TrustCueError
from trustcue_backend.main import create_app


class SampleValidatedModel(BaseModel):
    """Model used for validation error testing."""

    age: int
    secret_token: str


def test_validation_error_strips_sensitive_inputs() -> None:
    """Verify that validation errors NEVER echo submitted sensitive values back to clients."""
    app = create_app()
    router = APIRouter()

    @router.post("/test-validation")
    async def sample_endpoint(payload: SampleValidatedModel) -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(router)

    client = TestClient(app)
    sensitive_token_value = "HIGHLY_CONFIDENTIAL_USER_PASSWORD_12345"

    response = client.post(
        "/test-validation",
        json={"age": "not-an-integer", "secret_token": sensitive_token_value},
    )

    assert response.status_code == 422
    data = response.json()

    assert "error" in data
    assert data["error"]["code"] == "VALIDATION_ERROR"
    assert "requestId" in data["error"]
    assert "timestamp" in data["error"]

    # Crucial assertion: the sensitive token value must NEVER be present anywhere in the response text
    assert sensitive_token_value not in response.text
    assert "not-an-integer" not in response.text

    # Verify sanitized field structure
    fields = data["error"]["details"]["fields"]
    assert any(f["field"] == "age" for f in fields)


def test_404_not_found_does_not_echo_arbitrary_urls_or_queries(client: TestClient) -> None:
    """Verify 404 handler returns sanitized envelope without reflecting user-controlled queries."""
    sensitive_query = "super_private_auth_query_parameter"
    response = client.get(f"/nonexistent-path-probe?leak={sensitive_query}")

    assert response.status_code == 404
    data = response.json()

    assert data["error"]["code"] == "NOT_FOUND"
    assert data["error"]["message"] == "The requested endpoint does not exist."
    assert "requestId" in data["error"]
    assert sensitive_query not in response.text


def test_405_method_not_allowed(client: TestClient) -> None:
    """Verify 405 Method Not Allowed returns sanitized error envelope."""
    response = client.post("/health")

    assert response.status_code == 405
    data = response.json()

    assert data["error"]["code"] == "METHOD_NOT_ALLOWED"
    assert data["error"]["message"] == "The HTTP method is not allowed for this endpoint."
    assert "requestId" in data["error"]


def test_unexpected_exception_sanitizes_internal_errors() -> None:
    """Verify 500 handler suppresses internal stack traces and internal secrets."""
    app = create_app()
    router = APIRouter()

    @router.get("/test-internal-failure")
    async def failing_endpoint() -> None:
        raise RuntimeError("Database connection string: postgresql://admin:SECRET_PASSWORD@localhost:5432/db")

    app.include_router(router)
    client = TestClient(app, raise_server_exceptions=False)

    response = client.get("/test-internal-failure")
    assert response.status_code == 500

    data = response.json()
    assert data["error"]["code"] == "INTERNAL_ERROR"
    assert data["error"]["message"] == "An unexpected internal server error occurred."
    assert "requestId" in data["error"]

    # Sensitive strings, database credentials, and stack trace details must be completely absent
    assert "SECRET_PASSWORD" not in response.text
    assert "postgresql://" not in response.text
    assert "Traceback" not in response.text


def test_payload_too_large_rejection() -> None:
    """Verify request size middleware rejects payloads exceeding byte threshold."""
    settings = Settings(MAX_REQUEST_BODY_BYTES=500)
    app = create_app(settings=settings)
    client = TestClient(app)

    # Send payload exceeding 500 bytes
    large_payload = "A" * 600
    response = client.post("/health", content=large_payload, headers={"content-length": "600"})

    assert response.status_code == 413
    data = response.json()
    assert data["error"]["code"] == "PAYLOAD_TOO_LARGE"
    assert "500 bytes" in data["error"]["message"]


def test_custom_trustcue_error_handling() -> None:
    """Verify domain TrustCueError exceptions map to typed status codes and envelopes."""
    app = create_app()
    router = APIRouter()

    @router.get("/test-domain-error")
    async def domain_error_endpoint() -> None:
        raise TrustCueError(
            code="QUOTA_EXCEEDED",
            message="User quota limit reached.",
            status_code=429,
            details={"remaining": 0},
        )

    app.include_router(router)
    client = TestClient(app)

    response = client.get("/test-domain-error")
    assert response.status_code == 429

    data = response.json()
    assert data["error"]["code"] == "QUOTA_EXCEEDED"
    assert data["error"]["message"] == "User quota limit reached."
    assert data["error"]["details"]["remaining"] == 0
