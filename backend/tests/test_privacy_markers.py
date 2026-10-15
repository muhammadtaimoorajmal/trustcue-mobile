"""Security tests verifying that user text, tokens, and secrets are never emitted in logs."""

import io
import logging

from starlette.testclient import TestClient

from trustcue_backend.core.auth import create_test_jwt
from trustcue_backend.core.config import Settings
from trustcue_backend.main import create_app


def test_logging_never_emits_secrets_or_user_text() -> None:
    """
    Synthetic marker verification:
    Inject distinct high-entropy synthetic secret markers into headers, query params,
    and analysis body text. Verify 0 occurrences appear in server logs or error envelopes.
    """
    log_capture_stream = io.StringIO()
    handler = logging.StreamHandler(log_capture_stream)
    handler.setLevel(logging.DEBUG)

    # Attach handler to trustcue loggers
    trustcue_logger = logging.getLogger("trustcue")
    trustcue_logger.addHandler(handler)

    try:
        settings = Settings(SUPABASE_JWT_SECRET="test-jwt-secret-key-32-chars-long!", ENVIRONMENT="test")
        app = create_app(settings=settings)
        client = TestClient(app)

        MARKER_SECRET_TOKEN = "SYNTHETIC_BEARER_TOKEN_XYZ_987654321"
        MARKER_USER_TEXT = "CONFIDENTIAL_FINANCIAL_MESSAGE_BODY_DO_NOT_LOG_999"
        MARKER_QUERY_PARAM = "SUPER_SECRET_QUERY_TOKEN_VALUE_456"

        user_id = "00000000-0000-0000-0000-000000000099"
        token = create_test_jwt(user_id=user_id)

        # 1. Hit analysis route with confidential message text
        resp1 = client.post(
            "/api/v1/analysis/ai",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "snapshotId": "snap-synth-marker",
                "text": MARKER_USER_TEXT,
                "source": "messageText",
                "sourceRevision": "rev-1",
                "clientTimestamp": "2026-10-15T12:00:00Z",
            },
        )
        assert resp1.status_code in (429, 503)

        # 2. Hit non-existent endpoint with secret query param
        resp2 = client.get(f"/nonexistent-probe?secret_marker={MARKER_QUERY_PARAM}")
        assert resp2.status_code == 404

        # 3. Hit account profile with synthetic token in auth header
        resp3 = client.get(
            "/api/v1/account/profile",
            headers={"Authorization": f"Bearer {MARKER_SECRET_TOKEN}"},
        )
        assert resp3.status_code == 401

        # Retrieve all captured logs
        captured_logs = log_capture_stream.getvalue()

        # Assert no sensitive markers are present in server logs
        assert MARKER_SECRET_TOKEN not in captured_logs
        assert MARKER_USER_TEXT not in captured_logs
        assert MARKER_QUERY_PARAM not in captured_logs

        # Assert no sensitive markers are present in response text
        assert MARKER_SECRET_TOKEN not in resp1.text
        assert MARKER_SECRET_TOKEN not in resp2.text
        assert MARKER_SECRET_TOKEN not in resp3.text
        assert MARKER_USER_TEXT not in resp1.text
        assert MARKER_QUERY_PARAM not in resp2.text
    finally:
        trustcue_logger.removeHandler(handler)
