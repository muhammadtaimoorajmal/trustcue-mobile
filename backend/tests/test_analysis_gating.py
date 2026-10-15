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


def test_analysis_requires_explicit_upload_consent(test_jwt: str) -> None:
    """Verify 400 consent_required is returned without reserving quota when consent is omitted."""
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
        assert res.status_code == 400
        data = res.json()
        assert data["error"]["code"] == "consent_required"

        # Quota remains full (15) because consent validation occurs before quota reservation
        profile_res = client.get("/api/v1/account/profile", headers=headers)
        assert profile_res.status_code == 200
        assert profile_res.json()["quotaRemainingToday"] == 15


def test_analysis_rejects_consent_with_granted_false(test_jwt: str) -> None:
    """Verify 400 consent_required is returned when consent.granted is False."""
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
            "consent": {
                "granted": False,
                "disclosureVersion": "1.0.0",
                "timestamp": "2026-10-15T12:00:00Z",
                "recipient": "trustcue-backend",
                "provider": "groq-cloud",
            },
        }
        res = client.post("/api/v1/analysis/ai", headers=headers, json=payload)
        assert res.status_code == 400
        assert res.json()["error"]["code"] == "consent_required"


def test_analysis_rejects_unsupported_disclosure_version(test_jwt: str) -> None:
    """Verify 400 unsupported_disclosure_version is returned when disclosureVersion is unknown."""
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
            "consent": {
                "granted": True,
                "disclosureVersion": "99.0.0",
                "timestamp": "2026-10-15T12:00:00Z",
                "recipient": "trustcue-backend",
                "provider": "groq-cloud",
            },
        }
        res = client.post("/api/v1/analysis/ai", headers=headers, json=payload)
        assert res.status_code == 400
        assert res.json()["error"]["code"] == "unsupported_disclosure_version"


def test_analysis_rejects_invalid_recipient_and_provider(test_jwt: str) -> None:
    """Verify 400 is returned for unauthorized recipient or unsupported provider."""
    settings = Settings(
        SUPABASE_JWT_SECRET=JWT_SECRET,
        ENABLE_CLOUD_AI=True,
        GROQ_API_KEY="gsk_test_api_key_valid_placeholder",
    )
    app = create_app(settings=settings)
    with TestClient(app) as client:
        headers = {"Authorization": f"Bearer {test_jwt}"}
        # Invalid recipient
        res1 = client.post(
            "/api/v1/analysis/ai",
            headers=headers,
            json={
                "snapshotId": "snap-01",
                "text": "Normal text submitted for evaluation.",
                "source": "messageText",
                "sourceRevision": "rev-1",
                "clientTimestamp": "2026-10-15T12:00:00Z",
                "consent": {
                    "granted": True,
                    "disclosureVersion": "1.0.0",
                    "timestamp": "2026-10-15T12:00:00Z",
                    "recipient": "unauthorized-third-party",
                    "provider": "groq-cloud",
                },
            },
        )
        assert res1.status_code == 400
        assert res1.json()["error"]["code"] == "invalid_consent_recipient"

        # Unsupported provider
        res2 = client.post(
            "/api/v1/analysis/ai",
            headers=headers,
            json={
                "snapshotId": "snap-01",
                "text": "Normal text submitted for evaluation.",
                "source": "messageText",
                "sourceRevision": "rev-1",
                "clientTimestamp": "2026-10-15T12:00:00Z",
                "consent": {
                    "granted": True,
                    "disclosureVersion": "1.0.0",
                    "timestamp": "2026-10-15T12:00:00Z",
                    "recipient": "trustcue-backend",
                    "provider": "unknown-blackbox-ai",
                },
            },
        )
        assert res2.status_code == 400
        assert res2.json()["error"]["code"] == "unsupported_ai_provider"


def test_analysis_succeeds_with_valid_consent_and_commits_quota(test_jwt: str) -> None:
    """Verify endpoint is fully operational with valid consent, returning 200 and committing quota."""
    from unittest.mock import AsyncMock

    from trustcue_backend.api.schemas.analysis import FindingSeverity, IndicatorCategory
    from trustcue_backend.providers.models import (
        ProviderAnalysisResult,
        RawAiFinding,
        RawEvidenceReference,
        RawSuggestedAction,
    )

    settings = Settings(
        SUPABASE_JWT_SECRET=JWT_SECRET,
        ENABLE_CLOUD_AI=True,
        GROQ_API_KEY="gsk_test_api_key_valid_placeholder",
    )
    app = create_app(settings=settings)

    mock_provider = AsyncMock()
    mock_provider.analyze.return_value = ProviderAnalysisResult(
        provider="groq-cloud",
        model="llama-3.3-70b-versatile",
        factual_summary="Urgent credential request observed.",
        findings=[
            RawAiFinding(
                id="finding-1",
                category=IndicatorCategory.requests_for_credentials,
                severity=FindingSeverity.high,
                title="Direct credential request",
                explanation="Message requests password transmission.",
                evidence_references=[
                    RawEvidenceReference(excerpt="Send your password"),
                ],
            )
        ],
        uncertainty_notes=["Sender identity cannot be verified from text alone."],
        suggested_actions=[
            RawSuggestedAction(
                id="act-1",
                priority="immediate",
                title="Do not send password",
                detail="Never send passwords over messaging.",
            )
        ],
    )
    with TestClient(app) as client:
        app.state.app_state.ai_provider = mock_provider
        headers = {"Authorization": f"Bearer {test_jwt}"}
        payload = {
            "snapshotId": "snap-module35-success",
            "text": "URGENT: Send your password immediately.",
            "source": "messageText",
            "sourceRevision": "rev-1",
            "clientTimestamp": "2026-10-15T12:00:00Z",
            "consent": {
                "granted": True,
                "disclosureVersion": "1.0.0",
                "timestamp": "2026-10-15T12:00:00Z",
                "recipient": "trustcue-backend",
                "provider": "groq-cloud",
            },
        }

        res = client.post("/api/v1/analysis/ai", headers=headers, json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data["snapshotId"] == "snap-module35-success"
        assert len(data["findings"]) == 1
        assert data["findings"][0]["category"] == "requests_for_credentials"
        assert data["findings"][0]["evidenceReferences"][0]["excerpt"] == "Send your password"
        assert data["findings"][0]["evidenceReferences"][0]["startOffset"] == 8
        assert data["findings"][0]["evidenceReferences"][0]["endOffset"] == 26

        # Check quota remaining - committed from 15 to 14
        profile_res = client.get("/api/v1/account/profile", headers=headers)
        assert profile_res.status_code == 200
        assert profile_res.json()["quotaRemainingToday"] == 14
