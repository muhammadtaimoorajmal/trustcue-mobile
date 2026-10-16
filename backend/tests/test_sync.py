"""Integration and unit tests for Module 39 Optional Cloud Report Synchronization."""

import uuid
from datetime import UTC, datetime, timedelta

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


def get_auth_headers(user_id: str, email: str = "sync_user@example.com") -> dict[str, str]:
    """Generate valid Bearer authorization header for a test user."""
    token = create_test_jwt(
        secret=TEST_SECRET,
        user_id=user_id,
        email=email,
        audience="authenticated",
        issuer="https://supabase.local/auth/v1",
        expires_in_seconds=3600,
    )
    return {"Authorization": f"Bearer {token}"}


def test_sync_routes_require_authorization(auth_client: TestClient) -> None:
    """Ensure GET, POST, and DELETE /api/v1/sync/reports require valid Bearer token."""
    res_get = auth_client.get("/api/v1/sync/reports")
    assert res_get.status_code == 401
    assert res_get.json()["error"]["code"] == "unauthorized"

    res_post = auth_client.post("/api/v1/sync/reports", json={"reports": []})
    assert res_post.status_code == 401
    assert res_post.json()["error"]["code"] == "unauthorized"

    res_del = auth_client.delete("/api/v1/sync/reports")
    assert res_del.status_code == 401
    assert res_del.json()["error"]["code"] == "unauthorized"


def test_sync_gated_on_sync_opt_in(auth_client: TestClient) -> None:
    """Ensure user with syncEnabled=False receives 403 sync_opt_in_required."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)

    # 1. Profile initially has syncEnabled=False
    res_prof = auth_client.get("/api/v1/account/profile", headers=headers)
    assert res_prof.status_code == 200
    assert res_prof.json()["syncEnabled"] is False

    # 2. Attempt to pull reports -> 403 Forbidden
    res_pull = auth_client.get("/api/v1/sync/reports", headers=headers)
    assert res_pull.status_code == 403
    assert res_pull.json()["error"]["code"] == "sync_opt_in_required"

    # 3. Attempt to push reports -> 403 Forbidden
    payload = {
        "reports": [
            {
                "clientReportId": "rep-001",
                "snapshotId": "snap-001",
                "clientUpdatedAt": datetime.now(UTC).isoformat(),
                "reportPayload": {
                    "formatVersion": 1,
                    "outcomeState": "suspicious",
                    "hasAiAnalysis": False,
                },
            }
        ]
    }
    res_push = auth_client.post("/api/v1/sync/reports", headers=headers, json=payload)
    assert res_push.status_code == 403
    assert res_push.json()["error"]["code"] == "sync_opt_in_required"


def test_enabling_sync_in_profile_allows_sync_operations(auth_client: TestClient) -> None:
    """Verify enabling syncEnabled via PATCH /api/v1/account/profile un-gates sync."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)

    # Enable sync
    patch_res = auth_client.patch(
        "/api/v1/account/profile",
        headers=headers,
        json={"syncEnabled": True},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["syncEnabled"] is True

    # Now GET /api/v1/sync/reports succeeds with empty list
    get_res = auth_client.get("/api/v1/sync/reports", headers=headers)
    assert get_res.status_code == 200
    data = get_res.json()
    assert data["reports"] == []
    assert data["hasMore"] is False


def test_sync_rejects_forbidden_content_keys(auth_client: TestClient) -> None:
    """Verify sync payload rejects raw text, excerpts, screenshots, and hashes."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})

    forbidden_payloads = [
        {"formatVersion": 1, "text": "Your bank account has been locked!"},
        {"formatVersion": 1, "rawText": "Urgent verification needed"},
        {"formatVersion": 1, "excerpt": "Call this number immediately"},
        {"formatVersion": 1, "evidence": ["suspicious text excerpt"]},
        {"formatVersion": 1, "screenshot": "base64encodedbytes..."},
        {"formatVersion": 1, "hash": "sha256hashofrawmessage"},
        {"formatVersion": 1, "nested": {"excerpt": "leaked string"}},
    ]

    for bad_payload in forbidden_payloads:
        push_body = {
            "reports": [
                {
                    "clientReportId": "rep-privacy-test",
                    "snapshotId": "snap-privacy-test",
                    "clientUpdatedAt": datetime.now(UTC).isoformat(),
                    "reportPayload": bad_payload,
                }
            ]
        }
        res = auth_client.post("/api/v1/sync/reports", headers=headers, json=push_body)
        assert res.status_code in (400, 422), f"Expected rejection for payload with key in {bad_payload.keys()}"


def test_sync_push_and_pull_lifecycle(auth_client: TestClient) -> None:
    """Test full cycle of pushing report summaries, pulling them, and pagination/filtering."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})

    t1 = datetime.now(UTC) - timedelta(hours=2)
    t2 = datetime.now(UTC) - timedelta(hours=1)

    push_payload = {
        "reports": [
            {
                "clientReportId": "rep-001",
                "snapshotId": "snap-001",
                "clientUpdatedAt": t1.isoformat(),
                "reportPayload": {
                    "formatVersion": 1,
                    "outcomeState": "suspicious",
                    "hasAiAnalysis": False,
                    "indicatorCount": 2,
                    "categories": ["urgency", "credential_harvesting"],
                },
            },
            {
                "clientReportId": "rep-002",
                "snapshotId": "snap-002",
                "clientUpdatedAt": t2.isoformat(),
                "reportPayload": {
                    "formatVersion": 1,
                    "outcomeState": "cautious",
                    "hasAiAnalysis": True,
                    "indicatorCount": 1,
                    "categories": ["job_offer"],
                },
            },
        ]
    }

    push_res = auth_client.post("/api/v1/sync/reports", headers=headers, json=push_payload)
    assert push_res.status_code == 200
    push_data = push_res.json()
    assert push_data["acceptedCount"] == 2
    assert "rep-001" in push_data["syncedReportIds"]
    assert "rep-002" in push_data["syncedReportIds"]

    # Pull all
    pull_all = auth_client.get("/api/v1/sync/reports", headers=headers)
    assert pull_all.status_code == 200
    all_reports = pull_all.json()["reports"]
    assert len(all_reports) == 2
    assert all_reports[0]["clientReportId"] == "rep-001"
    assert all_reports[0]["revision"] == 1
    assert all_reports[0]["reportPayload"]["outcomeState"] == "suspicious"
    assert all_reports[1]["clientReportId"] == "rep-002"

    # Pull with `since` filter strictly after t1
    since_filter = (t1 + timedelta(minutes=10)).isoformat()
    pull_since = auth_client.get(f"/api/v1/sync/reports?since={since_filter}", headers=headers)
    assert pull_since.status_code == 200
    filtered_reports = pull_since.json()["reports"]
    assert len(filtered_reports) == 1
    assert filtered_reports[0]["clientReportId"] == "rep-002"


def test_sync_tombstone_and_revisions(auth_client: TestClient) -> None:
    """Verify that updating a report increments revision, and pushing a tombstone marks isDeleted."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})

    # Initial report upload
    now = datetime.now(UTC)
    auth_client.post(
        "/api/v1/sync/reports",
        headers=headers,
        json={
            "reports": [
                {
                    "clientReportId": "rep-tombstone-test",
                    "snapshotId": "snap-tombstone",
                    "clientUpdatedAt": now.isoformat(),
                    "reportPayload": {
                        "formatVersion": 1,
                        "outcomeState": "suspicious",
                    },
                }
            ]
        },
    )

    # Tombstone the report
    del_time = now + timedelta(minutes=5)
    tombstone_payload = {
        "reports": [
            {
                "clientReportId": "rep-tombstone-test",
                "snapshotId": "snap-tombstone",
                "clientUpdatedAt": del_time.isoformat(),
                "isDeleted": True,
                "deletedAt": del_time.isoformat(),
                "reportPayload": {
                    "formatVersion": 1,
                    "outcomeState": "deleted",
                },
            }
        ]
    }
    tomb_res = auth_client.post("/api/v1/sync/reports", headers=headers, json=tombstone_payload)
    assert tomb_res.status_code == 200

    # Pull and verify tombstone record has revision 2 and isDeleted=True
    pull_res = auth_client.get("/api/v1/sync/reports", headers=headers)
    assert pull_res.status_code == 200
    reports = pull_res.json()["reports"]
    assert len(reports) == 1
    assert reports[0]["clientReportId"] == "rep-tombstone-test"
    assert reports[0]["revision"] == 2
    assert reports[0]["isDeleted"] is True
    assert reports[0]["deletedAt"] is not None


def test_purge_synced_reports(auth_client: TestClient) -> None:
    """Verify DELETE /api/v1/sync/reports purges cloud backup reports."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})

    # Upload two reports
    now = datetime.now(UTC)
    auth_client.post(
        "/api/v1/sync/reports",
        headers=headers,
        json={
            "reports": [
                {
                    "clientReportId": "rep-purge-1",
                    "snapshotId": "snap-1",
                    "clientUpdatedAt": now.isoformat(),
                    "reportPayload": {"formatVersion": 1, "outcomeState": "cautious"},
                },
                {
                    "clientReportId": "rep-purge-2",
                    "snapshotId": "snap-2",
                    "clientUpdatedAt": now.isoformat(),
                    "reportPayload": {"formatVersion": 1, "outcomeState": "suspicious"},
                },
            ]
        },
    )

    # Purge reports
    del_res = auth_client.delete("/api/v1/sync/reports", headers=headers)
    assert del_res.status_code == 200
    del_data = del_res.json()
    assert del_data["purgedCount"] == 2

    # Pull reports now yields empty list
    pull_res = auth_client.get("/api/v1/sync/reports", headers=headers)
    assert pull_res.status_code == 200
    assert pull_res.json()["reports"] == []
