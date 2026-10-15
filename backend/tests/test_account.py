"""Integration tests for protected account profile and deletion endpoints."""

import uuid
from datetime import datetime

import pytest
from starlette.testclient import TestClient

from trustcue_backend.core.auth import create_test_jwt
from trustcue_backend.core.config import Settings
from trustcue_backend.main import create_app

TEST_SECRET = "test-jwt-secret-key-32-chars-long!"


@pytest.fixture
def test_settings() -> Settings:
    """Settings configured with test JWT signing key."""
    return Settings(
        SUPABASE_JWT_SECRET=TEST_SECRET,
        SUPABASE_JWT_AUDIENCE="authenticated",
        DEFAULT_DAILY_AI_QUOTA=15,
        ENVIRONMENT="test",
    )


@pytest.fixture
def auth_client(test_settings: Settings) -> TestClient:
    """Test client for FastAPI instance with test settings."""
    app = create_app(settings=test_settings)
    return TestClient(app)


def test_profile_requires_authorization(auth_client: TestClient) -> None:
    """Ensure GET /api/v1/account/profile returns 401 ErrorEnvelope when Authorization header is absent."""
    response = auth_client.get("/api/v1/account/profile")

    assert response.status_code == 401
    data = response.json()
    assert "error" in data
    assert data["error"]["code"] == "unauthorized"
    assert "Authorization header" in data["error"]["message"]
    assert "requestId" in data["error"]
    assert "timestamp" in data["error"]
    assert "X-Request-ID" in response.headers


def test_profile_rejects_non_bearer_scheme(auth_client: TestClient) -> None:
    """Ensure non-Bearer authorization schemes return 401."""
    response = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": "Basic dXNlcm5hbWU6cGFzc3dvcmQ="},
    )

    assert response.status_code == 401
    data = response.json()
    assert data["error"]["code"] == "unauthorized"
    assert "Bearer token required" in data["error"]["message"]


def test_profile_rejects_expired_token(auth_client: TestClient) -> None:
    """Ensure expired JWT returns 401 with code 'token_expired'."""
    user_uuid = str(uuid.uuid4())
    expired_token = create_test_jwt(
        user_id=user_uuid,
        secret=TEST_SECRET,
        expires_in_seconds=-10,
    )

    response = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {expired_token}"},
    )

    assert response.status_code == 401
    data = response.json()
    assert data["error"]["code"] == "token_expired"
    assert "expired" in data["error"]["message"].lower()


def test_profile_rejects_tampered_signature(auth_client: TestClient) -> None:
    """Ensure JWT with wrong signature returns 401 without leaking server key details."""
    user_uuid = str(uuid.uuid4())
    forged_token = create_test_jwt(
        user_id=user_uuid,
        secret="attacker-wrong-secret-32-chars-long!",
    )

    response = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {forged_token}"},
    )

    assert response.status_code == 401
    data = response.json()
    assert data["error"]["code"] == "unauthorized"
    # Never leak secret keys in response
    assert TEST_SECRET not in response.text
    assert "attacker-wrong-secret" not in response.text


def test_profile_rejects_anon_role_token(auth_client: TestClient) -> None:
    """Ensure Supabase public anon token cannot access user profile."""
    user_uuid = str(uuid.uuid4())
    anon_token = create_test_jwt(
        user_id=user_uuid,
        secret=TEST_SECRET,
        role="anon",
    )

    response = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {anon_token}"},
    )

    assert response.status_code == 401
    data = response.json()
    assert data["error"]["code"] == "unauthorized"
    assert "anonymous" in data["error"]["message"].lower()


def test_profile_retrieval_success(auth_client: TestClient) -> None:
    """Ensure valid JWT returns 200 with UserProfileResponse adhering to OpenAPI contract."""
    user_uuid = str(uuid.uuid4())
    email = "investigator@trustcue.test"
    valid_token = create_test_jwt(
        user_id=user_uuid,
        email=email,
        secret=TEST_SECRET,
    )

    response = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {valid_token}"},
    )

    assert response.status_code == 200
    data = response.json()

    # Exact field names matching OpenAPI 3.1.0 UserProfileResponse
    assert data["userId"] == user_uuid
    assert data["email"] == email
    assert data["emailVerified"] is True
    assert data["syncEnabled"] is False
    assert data["quotaRemainingToday"] == 15

    # Check valid ISO 8601 UTC timestamp
    parsed_created_at = datetime.fromisoformat(data["createdAt"])
    assert parsed_created_at is not None
    assert "X-Request-ID" in response.headers


def test_account_deletion_requires_authorization(auth_client: TestClient) -> None:
    """Ensure DELETE /api/v1/account requires valid authentication."""
    response = auth_client.delete("/api/v1/account")

    assert response.status_code == 401
    data = response.json()
    assert data["error"]["code"] == "unauthorized"


def test_account_deletion_success(auth_client: TestClient) -> None:
    """Ensure DELETE /api/v1/account returns 200 with AccountDeletionResponse."""
    user_uuid = str(uuid.uuid4())
    valid_token = create_test_jwt(
        user_id=user_uuid,
        secret=TEST_SECRET,
    )

    response = auth_client.delete(
        "/api/v1/account",
        headers={"Authorization": f"Bearer {valid_token}"},
    )

    assert response.status_code == 200
    data = response.json()

    # Exact field names matching OpenAPI 3.1.0 AccountDeletionResponse
    assert data["status"] == "deleted"
    assert data["userId"] == user_uuid
    parsed_deleted_at = datetime.fromisoformat(data["deletedAt"])
    assert parsed_deleted_at is not None
    assert "X-Request-ID" in response.headers
