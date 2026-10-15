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


def test_patch_profile_success(auth_client: TestClient) -> None:
    """Ensure PATCH /api/v1/account/profile updates displayName and persists for subsequent calls."""
    user_uuid = str(uuid.uuid4())
    token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    # 1. Initial state has null displayName
    get_res = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert get_res.status_code == 200
    assert get_res.json()["displayName"] is None

    # 2. Patch displayName
    patch_res = auth_client.patch(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={"displayName": "Alice Cooper"},
    )
    assert patch_res.status_code == 200
    data = patch_res.json()
    assert data["displayName"] == "Alice Cooper"
    assert data["userId"] == user_uuid

    # 3. Subsequent GET returns updated displayName
    get_res2 = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert get_res2.status_code == 200
    assert get_res2.json()["displayName"] == "Alice Cooper"


def test_patch_profile_trims_whitespace(auth_client: TestClient) -> None:
    """Ensure PATCH /api/v1/account/profile trims leading and trailing whitespace."""
    user_uuid = str(uuid.uuid4())
    token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    patch_res = auth_client.patch(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={"displayName": "   TrimmedName   "},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["displayName"] == "TrimmedName"


def test_patch_profile_rejects_excessive_length(auth_client: TestClient) -> None:
    """Ensure PATCH /api/v1/account/profile rejects display names exceeding 64 characters."""
    user_uuid = str(uuid.uuid4())
    token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    patch_res = auth_client.patch(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={"displayName": "A" * 65},
    )
    assert patch_res.status_code == 422 or patch_res.status_code == 400


def test_patch_profile_rejects_extra_fields(auth_client: TestClient) -> None:
    """Ensure non-editable fields (such as quotaRemainingToday or syncEnabled) are rejected."""
    user_uuid = str(uuid.uuid4())
    token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    patch_res = auth_client.patch(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={"displayName": "Bob", "quotaRemainingToday": 9999},
    )
    assert patch_res.status_code == 422 or patch_res.status_code == 400


def test_patch_profile_requires_authorization(auth_client: TestClient) -> None:
    """Ensure PATCH /api/v1/account/profile returns 401 without Bearer token."""
    patch_res = auth_client.patch(
        "/api/v1/account/profile",
        json={"displayName": "Bob"},
    )
    assert patch_res.status_code == 401


def test_deleted_account_rejects_subsequent_requests(auth_client: TestClient) -> None:
    """Ensure that after account deletion, unexpired JWTs from that account are immediately rejected."""
    user_uuid = str(uuid.uuid4())
    valid_token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    # 1. Profile accessible before deletion
    res1 = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {valid_token}"},
    )
    assert res1.status_code == 200

    # 2. Delete account
    del_res = auth_client.delete(
        "/api/v1/account",
        headers={"Authorization": f"Bearer {valid_token}"},
    )
    assert del_res.status_code == 200
    assert del_res.json()["status"] == "deleted"

    # 3. Subsequent profile retrieval with unexpired JWT rejected with 401
    res2 = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {valid_token}"},
    )
    assert res2.status_code == 401
    assert "deleted" in res2.json()["error"]["message"].lower()

    # 4. Subsequent AI analysis request with unexpired JWT also rejected with 401
    ai_res = auth_client.post(
        "/api/v1/analysis/ai",
        headers={"Authorization": f"Bearer {valid_token}"},
        json={
            "snapshotId": "snap-test-01",
            "reviewedText": "Suspicious urgent payment request",
            "source": "messageText",
            "consentGranted": True,
        },
    )
    assert ai_res.status_code == 401
    assert "deleted" in ai_res.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_account_service_supabase_integration() -> None:
    """Ensure AccountService interacts with Supabase PostgREST and Auth Admin API correctly."""
    from datetime import UTC

    import httpx

    from trustcue_backend.core.quota import InMemoryQuotaStore
    from trustcue_backend.core.state import AppState
    from trustcue_backend.services.account_service import AccountService

    recorded_calls: list[tuple[str, str]] = []

    def mock_handler(request: httpx.Request) -> httpx.Response:
        recorded_calls.append((request.method, str(request.url)))
        url_str = str(request.url)
        assert request.headers.get("apikey") == "test-service-key"
        assert request.headers.get("authorization") == "Bearer test-service-key"

        if "rpc/ensure_profile_exists" in url_str:
            return httpx.Response(200, json=None)
        if "rest/v1/profiles" in url_str and request.method == "GET":
            return httpx.Response(
                200,
                json=[{"id": "11111111-1111-1111-1111-111111111111", "display_name": "Supabase User", "sync_enabled": False}],
            )
        if "rest/v1/profiles" in url_str and request.method == "PATCH":
            return httpx.Response(204)
        if "auth/v1/admin/users" in url_str and request.method == "DELETE":
            return httpx.Response(200, json={})
        return httpx.Response(404)

    mock_client = httpx.AsyncClient(transport=httpx.MockTransport(mock_handler))
    settings = Settings(
        SUPABASE_URL="https://example.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="test-service-key",
        ENVIRONMENT="test",
    )
    app_state = AppState()
    quota_store = InMemoryQuotaStore()
    svc = AccountService(settings=settings, app_state=app_state, quota_store=quota_store, http_client=mock_client)

    profile = await svc.get_profile(
        user_id="11111111-1111-1111-1111-111111111111",
        email="test@example.com",
        email_verified=True,
        fallback_created_at=datetime.now(UTC),
    )
    assert profile.display_name == "Supabase User"

    patched = await svc.update_profile(
        user_id="11111111-1111-1111-1111-111111111111",
        display_name="Updated Remote Name",
        email="test@example.com",
        email_verified=True,
        fallback_created_at=datetime.now(UTC),
    )
    assert patched.display_name == "Updated Remote Name"

    del_resp = await svc.delete_account(user_id="11111111-1111-1111-1111-111111111111")
    assert del_resp.status == "deleted"
    assert app_state.is_user_deleted("11111111-1111-1111-1111-111111111111")

    # Assert that PostgREST queries, patch, and Admin API DELETE endpoints were called
    endpoints = [call[1] for call in recorded_calls]
    assert any("rest/v1/profiles" in ep for ep in endpoints)
    assert any("auth/v1/admin/users/11111111-1111-1111-1111-111111111111" in ep for ep in endpoints)


