"""Integration and unit tests for Module 39 and Module 40 Cloud Report Synchronization."""

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


def make_summary_payload(
    format_version: int = 1,
    outcome_state: str = "indicatorsDetected",
    has_ai_analysis: bool = False,
    indicator_count: int = 1,
    categories: list[str] | None = None,
    source: str = "messageText",
) -> dict:
    """Create a strictly allowlisted report summary payload."""
    return {
        "formatVersion": format_version,
        "outcomeState": outcome_state,
        "hasAiAnalysis": has_ai_analysis,
        "indicatorCount": indicator_count,
        "categories": categories or ["urgency"],
        "source": source,
    }


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
                "reportPayload": make_summary_payload(outcome_state="suspicious"),
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

    # Pull reports now succeeds
    pull_res = auth_client.get("/api/v1/sync/reports", headers=headers)
    assert pull_res.status_code == 200
    assert pull_res.json()["reports"] == []


def test_sync_privacy_validation_rejects_raw_text_and_excerpts(auth_client: TestClient) -> None:
    """Verify that any attempt to push forbidden keys like text, excerpt, screenshot is rejected with 422."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})

    forbidden_payloads = [
        {"formatVersion": 1, "text": "sensitive account number 1234", "outcomeState": "suspicious", "hasAiAnalysis": False, "indicatorCount": 1, "categories": ["payment"], "source": "messageText"},
        {"formatVersion": 1, "rawText": "hello world", "outcomeState": "cautious", "hasAiAnalysis": False, "indicatorCount": 1, "categories": ["urgency"], "source": "messageText"},
        {"formatVersion": 1, "excerpt": "click here immediately", "outcomeState": "cautious", "hasAiAnalysis": False, "indicatorCount": 1, "categories": ["urgency"], "source": "messageText"},
        {"formatVersion": 1, "screenshot": "base64bytes...", "outcomeState": "cautious", "hasAiAnalysis": False, "indicatorCount": 1, "categories": ["urgency"], "source": "messageText"},
        {"formatVersion": 1, "hash": "abc12345", "outcomeState": "cautious", "hasAiAnalysis": False, "indicatorCount": 1, "categories": ["urgency"], "source": "messageText"},
        {"formatVersion": 1, "unauthorized_extra_field": "leak", "outcomeState": "cautious", "hasAiAnalysis": False, "indicatorCount": 1, "categories": ["urgency"], "source": "messageText"},
    ]

    for bad_payload in forbidden_payloads:
        req = {
            "reports": [
                {
                    "clientReportId": "rep-privacy-test",
                    "snapshotId": "snap-privacy-test",
                    "clientUpdatedAt": datetime.now(UTC).isoformat(),
                    "reportPayload": bad_payload,
                }
            ]
        }
        res = auth_client.post("/api/v1/sync/reports", headers=headers, json=req)
        assert res.status_code == 422, f"Expected 422 for payload {bad_payload}, got {res.status_code}"


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
                "reportPayload": make_summary_payload(
                    outcome_state="suspicious",
                    has_ai_analysis=False,
                    indicator_count=2,
                    categories=["urgency", "credential_harvesting"],
                    source="messageText",
                ),
            },
            {
                "clientReportId": "rep-002",
                "snapshotId": "snap-002",
                "clientUpdatedAt": t2.isoformat(),
                "reportPayload": make_summary_payload(
                    outcome_state="cautious",
                    has_ai_analysis=True,
                    indicator_count=1,
                    categories=["job_offer"],
                    source="screenshot",
                ),
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
                    "reportPayload": make_summary_payload(outcome_state="suspicious"),
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
                "reportPayload": {},
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
                    "reportPayload": make_summary_payload(outcome_state="cautious"),
                },
                {
                    "clientReportId": "rep-purge-2",
                    "snapshotId": "snap-2",
                    "clientUpdatedAt": now.isoformat(),
                    "reportPayload": make_summary_payload(outcome_state="suspicious"),
                },
            ]
        },
    )

    # Purge reports
    del_res = auth_client.delete("/api/v1/sync/reports", headers=headers)
    assert del_res.status_code == 200
    del_data = del_res.json()
    assert del_data["purgedCount"] == 2

    # Pull reports now yields empty list (note: user must re-enable sync to pull)
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})
    pull_res = auth_client.get("/api/v1/sync/reports", headers=headers)
    assert pull_res.status_code == 200
    assert pull_res.json()["reports"] == []


def test_purge_available_when_sync_is_disabled(auth_client: TestClient) -> None:
    """Verify cloud purge works even when user has sync disabled."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)

    # Enable sync and upload 1 report
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})
    now = datetime.now(UTC)
    auth_client.post(
        "/api/v1/sync/reports",
        headers=headers,
        json={
            "reports": [
                {
                    "clientReportId": "rep-dis-1",
                    "snapshotId": "snap-dis-1",
                    "clientUpdatedAt": now.isoformat(),
                    "reportPayload": make_summary_payload(),
                }
            ]
        },
    )

    # User disables sync
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": False})

    # User purges while sync is disabled -> succeeds!
    del_res = auth_client.delete("/api/v1/sync/reports", headers=headers)
    assert del_res.status_code == 200
    assert del_res.json()["purgedCount"] == 1


def test_resurrection_prevention_after_purge(auth_client: TestClient) -> None:
    """Verify that stale uploads created before purge cannot resurrect purged reports."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)

    # Enable sync and upload report 1
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})
    t_old = datetime.now(UTC) - timedelta(minutes=10)
    auth_client.post(
        "/api/v1/sync/reports",
        headers=headers,
        json={
            "reports": [
                {
                    "clientReportId": "rep-stale-1",
                    "snapshotId": "snap-stale-1",
                    "clientUpdatedAt": t_old.isoformat(),
                    "syncGeneration": 1,
                    "reportPayload": make_summary_payload(),
                }
            ]
        },
    )

    # Purge reports
    auth_client.delete("/api/v1/sync/reports", headers=headers)

    # Re-enable sync
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})

    # Stale second client attempts to push old report with generation 1 and old timestamp
    stale_res = auth_client.post(
        "/api/v1/sync/reports",
        headers=headers,
        json={
            "reports": [
                {
                    "clientReportId": "rep-stale-1",
                    "snapshotId": "snap-stale-1",
                    "clientUpdatedAt": t_old.isoformat(),
                    "syncGeneration": 1,
                    "reportPayload": make_summary_payload(),
                }
            ]
        },
    )
    assert stale_res.status_code == 200

    # Pull reports: the stale report must NOT have been resurrected!
    pull_res = auth_client.get("/api/v1/sync/reports", headers=headers)
    assert pull_res.status_code == 200
    assert len(pull_res.json()["reports"]) == 0


def test_pull_cursor_tie_breaker_with_identical_timestamps(auth_client: TestClient) -> None:
    """Verify pagination with identical timestamps using cursor tie-breaker."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})

    shared_time = datetime.now(UTC)

    # Push two reports with the exact same timestamp
    auth_client.post(
        "/api/v1/sync/reports",
        headers=headers,
        json={
            "reports": [
                {
                    "clientReportId": "rep-aaa",
                    "snapshotId": "snap-1",
                    "clientUpdatedAt": shared_time.isoformat(),
                    "reportPayload": make_summary_payload(),
                },
                {
                    "clientReportId": "rep-bbb",
                    "snapshotId": "snap-2",
                    "clientUpdatedAt": shared_time.isoformat(),
                    "reportPayload": make_summary_payload(),
                },
            ]
        },
    )

    # Pull page 1 with limit=1
    page1 = auth_client.get("/api/v1/sync/reports?limit=1", headers=headers)
    assert page1.status_code == 200
    data1 = page1.json()
    assert len(data1["reports"]) == 1
    assert data1["reports"][0]["clientReportId"] == "rep-aaa"
    assert data1["hasMore"] is True
    cursor = data1["nextCursor"]
    assert cursor is not None
    assert "|" in cursor

    # Pull page 2 using cursor
    page2 = auth_client.get(f"/api/v1/sync/reports?limit=1&cursor={cursor}", headers=headers)
    assert page2.status_code == 200
    data2 = page2.json()
    assert len(data2["reports"]) == 1
    assert data2["reports"][0]["clientReportId"] == "rep-bbb"


def test_sync_push_allows_tombstone_when_opted_out(auth_client: TestClient) -> None:
    """Verify that a user who has opted out (syncEnabled=False) CAN still push deletion tombstones."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)

    # User profile has syncEnabled=False by default
    res = auth_client.post(
        "/api/v1/sync/reports",
        headers=headers,
        json={
            "reports": [
                {
                    "clientReportId": "rep-tombstone-opted-out",
                    "snapshotId": "snap-tomb",
                    "clientUpdatedAt": datetime.now(UTC).isoformat(),
                    "isDeleted": True,
                    "deletedAt": datetime.now(UTC).isoformat(),
                    "reportPayload": make_summary_payload(),
                }
            ]
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["acceptedCount"] == 1
    assert "rep-tombstone-opted-out" in data["syncedReportIds"]


def test_sync_push_skips_stale_reports_preceding_purge(auth_client: TestClient) -> None:
    """Verify that reports dated before a purge cannot resurrect purged records."""
    user_id = str(uuid.uuid4())
    headers = get_auth_headers(user_id)

    # 1. Enable sync and push report
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})
    now = datetime.now(UTC)
    stale_time = now - timedelta(hours=2)

    auth_client.post(
        "/api/v1/sync/reports",
        headers=headers,
        json={
            "reports": [
                {
                    "clientReportId": "rep-initial",
                    "snapshotId": "snap-1",
                    "clientUpdatedAt": stale_time.isoformat(),
                    "reportPayload": make_summary_payload(),
                }
            ]
        },
    )

    # 2. Purge reports -> increments generation, sets sync_purged_at, syncEnabled=False
    purge_res = auth_client.delete("/api/v1/sync/reports", headers=headers)
    assert purge_res.status_code == 200

    # 3. Re-enable sync
    auth_client.patch("/api/v1/account/profile", headers=headers, json={"syncEnabled": True})

    # 4. Attempt to push stale report dated BEFORE purge
    stale_push = auth_client.post(
        "/api/v1/sync/reports",
        headers=headers,
        json={
            "reports": [
                {
                    "clientReportId": "rep-stale-resurrect",
                    "snapshotId": "snap-stale",
                    "clientUpdatedAt": (now - timedelta(hours=1)).isoformat(),  # Precedes purge
                    "reportPayload": make_summary_payload(),
                }
            ]
        },
    )
    assert stale_push.status_code == 200
    # Accepted count should be 0 because stale report preceding purge was skipped!
    assert stale_push.json()["acceptedCount"] == 0

    # 5. Pull reports to confirm nothing was resurrected
    pull = auth_client.get("/api/v1/sync/reports", headers=headers)
    assert pull.status_code == 200
    assert len(pull.json()["reports"]) == 0

