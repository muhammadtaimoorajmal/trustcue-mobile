"""Integration tests for protected account profile and deletion endpoints."""

import uuid
from datetime import datetime
from typing import Any

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
    assert data["syncGeneration"] == 1
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
                json=[
                    {
                        "id": "11111111-1111-1111-1111-111111111111",
                        "display_name": "Supabase User",
                        "sync_enabled": False,
                    }
                ],
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
    svc = AccountService(
        settings=settings, app_state=app_state, quota_store=quota_store, http_client=mock_client
    )

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


def test_patch_profile_avatar_path_lifecycle(auth_client: TestClient) -> None:
    """Ensure PATCH /api/v1/account/profile supports avatarPath updates and clearing."""
    user_uuid = str(uuid.uuid4())
    token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    # 1. Initial state has null avatarPath
    res1 = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res1.status_code == 200
    assert res1.json()["avatarPath"] is None

    # 2. Patch with valid avatar path
    valid_avatar = f"{user_uuid}/avatar_20261102.png"
    res2 = auth_client.patch(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={"avatarPath": valid_avatar},
    )
    assert res2.status_code == 200
    assert res2.json()["avatarPath"] == valid_avatar

    # 3. Subsequent GET returns persisted avatarPath
    res3 = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res3.status_code == 200
    assert res3.json()["avatarPath"] == valid_avatar

    # 4. Clear avatar via clearAvatar=True
    res4 = auth_client.patch(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={"clearAvatar": True},
    )
    assert res4.status_code == 200
    assert res4.json()["avatarPath"] is None

    # 5. Subsequent GET confirms avatarPath is null
    res5 = auth_client.get(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res5.status_code == 200
    assert res5.json()["avatarPath"] is None


def test_patch_profile_rejects_malformed_avatar_path(auth_client: TestClient) -> None:
    """Ensure PATCH rejects paths without user prefix or containing invalid characters."""
    user_uuid = str(uuid.uuid4())
    token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    # Path containing spaces / forbidden chars
    res = auth_client.patch(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={"avatarPath": "invalid path with spaces.exe"},
    )
    assert res.status_code == 422


def test_patch_profile_rejects_cross_user_avatar_path(auth_client: TestClient) -> None:
    """Ensure PATCH rejects avatar paths pointing to another user's prefix with 403."""
    user_uuid = str(uuid.uuid4())
    other_user_uuid = str(uuid.uuid4())
    token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    res = auth_client.patch(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={"avatarPath": f"{other_user_uuid}/avatar.png"},
    )
    assert res.status_code == 403
    data = res.json()
    assert data["error"]["code"] == "forbidden"
    assert "user namespace" in data["error"]["message"].lower()


def test_patch_profile_rejects_directory_traversal(auth_client: TestClient) -> None:
    """Ensure PATCH rejects avatar paths attempting directory traversal with 422."""
    user_uuid = str(uuid.uuid4())
    token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    for invalid_path in [
        f"{user_uuid}/../other.png",
        f"{user_uuid}/...png",
        f"{user_uuid}//double_slash.png",
        f"{user_uuid}\\backslash.png",
        f"{user_uuid}/.hidden.png",
    ]:
        res = auth_client.patch(
            "/api/v1/account/profile",
            headers={"Authorization": f"Bearer {token}"},
            json={"avatarPath": invalid_path},
        )
        assert res.status_code == 422, f"Expected 422 for path: {invalid_path}"


def test_patch_profile_rejects_conflicting_clear_avatar_and_avatar_path(
    auth_client: TestClient,
) -> None:
    """Ensure PATCH rejects payloads providing both clearAvatar=True and an avatarPath with 422."""
    user_uuid = str(uuid.uuid4())
    token = create_test_jwt(user_id=user_uuid, secret=TEST_SECRET)

    res = auth_client.patch(
        "/api/v1/account/profile",
        headers={"Authorization": f"Bearer {token}"},
        json={"clearAvatar": True, "avatarPath": f"{user_uuid}/avatar.png"},
    )
    assert res.status_code == 422


@pytest.mark.asyncio
async def test_account_service_profile_update_failure_does_not_pollute_cache() -> None:
    """Ensure that if PostgREST profile write fails, an error is raised and in-memory cache is NOT mutated."""
    from datetime import UTC

    import httpx

    from trustcue_backend.core.errors import TrustCueError
    from trustcue_backend.core.quota import InMemoryQuotaStore
    from trustcue_backend.core.state import AppState
    from trustcue_backend.services.account_service import AccountService

    def mock_failure_handler(request: httpx.Request) -> httpx.Response:
        url_str = str(request.url)
        if "rpc/ensure_profile_exists" in url_str:
            return httpx.Response(200, json=None)
        if "rest/v1/profiles" in url_str and request.method == "PATCH":
            # Simulate column missing (400) or DB error (500)
            return httpx.Response(
                400, json={"code": "42703", "message": "column profiles.avatar_path does not exist"}
            )
        return httpx.Response(404)

    mock_client = httpx.AsyncClient(transport=httpx.MockTransport(mock_failure_handler))
    settings = Settings(
        SUPABASE_URL="https://example.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="test-service-key",
        ENVIRONMENT="test",
    )
    app_state = AppState()
    quota_store = InMemoryQuotaStore()
    svc = AccountService(
        settings=settings, app_state=app_state, quota_store=quota_store, http_client=mock_client
    )

    test_uid = "22222222-2222-2222-2222-222222222222"

    with pytest.raises(TrustCueError) as exc_info:
        await svc.update_profile(
            user_id=test_uid,
            display_name="Never Persisted",
            email="test@example.com",
            email_verified=True,
            fallback_created_at=datetime.now(UTC),
            avatar_path=f"{test_uid}/photo.jpg",
        )
    assert exc_info.value.status_code == 503

    # Assert local AppState was NOT corrupted with the failed update
    assert app_state.get_display_name(test_uid) is None
    assert app_state.get_avatar_path(test_uid) is None


@pytest.mark.asyncio
async def test_account_deletion_cleans_up_avatar_storage() -> None:
    """Ensure account deletion cleans up files from the avatars bucket."""
    import httpx

    from trustcue_backend.core.quota import InMemoryQuotaStore
    from trustcue_backend.core.state import AppState
    from trustcue_backend.services.account_service import AccountService

    recorded_actions: list[tuple[str, str, Any]] = []
    test_uid = "33333333-3333-3333-3333-333333333333"

    def mock_storage_handler(request: httpx.Request) -> httpx.Response:
        url_str = str(request.url)
        import json

        body = json.loads(request.content.decode("utf-8")) if request.content else None
        recorded_actions.append((request.method, url_str, body))

        if "storage/v1/object/list/avatars" in url_str:
            return httpx.Response(200, json=[{"name": "profile_1.jpg"}, {"name": "profile_2.jpg"}])
        if "storage/v1/object/avatars" in url_str and request.method == "DELETE":
            return httpx.Response(200, json=[{"message": "Deleted"}])
        if "auth/v1/admin/users" in url_str and request.method == "DELETE":
            return httpx.Response(200, json={})
        return httpx.Response(404)

    mock_client = httpx.AsyncClient(transport=httpx.MockTransport(mock_storage_handler))
    settings = Settings(
        SUPABASE_URL="https://example.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="test-service-key",
        ENVIRONMENT="test",
    )
    app_state = AppState()
    quota_store = InMemoryQuotaStore()
    svc = AccountService(
        settings=settings, app_state=app_state, quota_store=quota_store, http_client=mock_client
    )

    del_resp = await svc.delete_account(user_id=test_uid)
    assert del_resp.status == "deleted"

    # Verify list call prefix
    list_call = next(call for call in recorded_actions if "object/list/avatars" in call[1])
    assert list_call[2]["prefix"] == f"{test_uid}/"

    # Verify delete call prefixes
    delete_call = next(
        call for call in recorded_actions if "object/avatars" in call[1] and call[0] == "DELETE"
    )
    assert f"{test_uid}/profile_1.jpg" in delete_call[2]["prefixes"]
    assert f"{test_uid}/profile_2.jpg" in delete_call[2]["prefixes"]
