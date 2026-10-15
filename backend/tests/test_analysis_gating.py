"""Tests verifying that public cloud AI analysis remains securely gated behind Module 34."""


import pytest
from starlette.testclient import TestClient

from trustcue_backend.core.auth import create_test_jwt
from trustcue_backend.core.config import Settings
from trustcue_backend.main import create_app

JWT_SECRET = "mock-super-secret-jwt-signing-key-for-gating-tests-32ch!"


@pytest.fixture
def test_jwt() -> str:
    return create_test_jwt(
        user_id="a1b2c3d4-e5f6-4789-abcd-ef0123456789",
        secret=JWT_SECRET,
    )


def test_unauthenticated_request_rejected_without_quota_or_provider_call() -> None:
    """Verify unauthenticated requests fail with 401 before any quota check."""
    settings = Settings(SUPABASE_JWT_SECRET=JWT_SECRET)
    app = create_app(settings=settings)
    with TestClient(app) as client:
        payload = {
            "snapshotId": "snap-01",
            "text": "Suspicious urgent payment request.",
            "source": "messageText",
            "sourceRevision": "rev-1",
            "clientTimestamp": "2026-10-15T12:00:00Z",
        }
        res = client.post("/api/v1/analysis/ai", json=payload)
        assert res.status_code == 401
        data = res.json()
        assert data["error"]["code"] == "unauthorized"


def test_invalid_text_rejected_with_400(test_jwt: str) -> None:
    """Verify semantically invalid text fails with 400 before provider calls."""
    settings = Settings(SUPABASE_JWT_SECRET=JWT_SECRET)
    app = create_app(settings=settings)
    with TestClient(app) as client:
        headers = {"Authorization": f"Bearer {test_jwt}"}
        # Only whitespace text
        res = client.post(
            "/api/v1/analysis/ai",
            headers=headers,
            json={
                "snapshotId": "snap-01",
                "text": "   \n\t  ",
                "source": "messageText",
                "sourceRevision": "rev-1",
                "clientTimestamp": "2026-10-15T12:00:00Z",
            },
        )
        assert res.status_code == 400
        assert res.json()["error"]["code"] == "only_whitespace"

        # Disallowed control character (NULL byte)
        res_ctrl = client.post(
            "/api/v1/analysis/ai",
            headers=headers,
            json={
                "snapshotId": "snap-01",
                "text": "Valid text with hidden \x00 null byte",
                "source": "messageText",
                "sourceRevision": "rev-1",
                "clientTimestamp": "2026-10-15T12:00:00Z",
            },
        )
        assert res_ctrl.status_code == 400
        assert res_ctrl.json()["error"]["code"] == "malformed_unicode"


def test_public_endpoint_gated_when_cloud_ai_disabled(test_jwt: str) -> None:
    """Verify 503 is returned and quota is refunded when ENABLE_CLOUD_AI=False."""
    settings = Settings(
        SUPABASE_JWT_SECRET=JWT_SECRET,
        ENABLE_CLOUD_AI=False,
    )
    app = create_app(settings=settings)
    with TestClient(app) as client:
        headers = {"Authorization": f"Bearer {test_jwt}"}
        payload = {
            "snapshotId": "snap-01",
            "text": "Normal text submitted for evaluation.",
            "source": "messageText",
            "sourceRevision": "rev-1",
            "clientTimestamp": "2026-10-15T12:00:00Z",
        }
        res = client.post("/api/v1/analysis/ai", headers=headers, json=payload)
        assert res.status_code == 503
        data = res.json()
        assert data["error"]["code"] == "ai_provider_unavailable"
        assert "not enabled in this environment" in data["error"]["message"]

        # Check quota remaining - must be full (15) because unused quota was refunded
        profile_res = client.get("/api/v1/account/profile", headers=headers)
        assert profile_res.status_code == 200
        assert profile_res.json()["quotaRemainingToday"] == 15


def test_public_endpoint_gated_with_module34_grounding_notice(test_jwt: str) -> None:
    """Verify 503 is returned and quota is refunded when ENABLE_CLOUD_AI=True pending Module 34."""
    settings = Settings(
        SUPABASE_JWT_SECRET=JWT_SECRET,
        ENABLE_CLOUD_AI=True,
        GROQ_API_KEY="gsk_test_api_key_valid_placeholder",
    )
    app = create_app(settings=settings)
    with TestClient(app) as client:
        headers = {"Authorization": f"Bearer {test_jwt}"}
        payload = {
            "snapshotId": "snap-01",
            "text": "Normal text submitted for evaluation.",
            "source": "messageText",
            "sourceRevision": "rev-1",
            "clientTimestamp": "2026-10-15T12:00:00Z",
        }
        res = client.post("/api/v1/analysis/ai", headers=headers, json=payload)
        assert res.status_code == 503
        data = res.json()
        assert data["error"]["code"] == "ai_provider_unavailable"
        assert "pending evidence grounding validation (Module 34)" in data["error"]["message"]

        # Check quota remaining - must be full (15) because unused quota was refunded
        profile_res = client.get("/api/v1/account/profile", headers=headers)
        assert profile_res.status_code == 200
        assert profile_res.json()["quotaRemainingToday"] == 15
