"""Unit and integration tests for strict text validation, boundaries, and Unicode policies."""

import pytest
from starlette.testclient import TestClient

from trustcue_backend.core.auth import create_test_jwt
from trustcue_backend.core.config import Settings
from trustcue_backend.core.validation import ValidationError, validate_analysis_text
from trustcue_backend.main import create_app


def test_validate_text_within_limits() -> None:
    """Standard text within 10,000 code points and 40,000 bytes is accepted."""
    valid_text = "Standard message text with legitimate content."
    result = validate_analysis_text(valid_text)
    assert result == valid_text


def test_validate_text_whitespace_only_rejected() -> None:
    """Whitespace-only text is rejected with only_whitespace code."""
    with pytest.raises(ValidationError) as exc_info:
        validate_analysis_text("   \n\t\r   ")
    assert exc_info.value.code == "only_whitespace"
    assert exc_info.value.status_code == 400


def test_validate_text_code_point_limit_enforced() -> None:
    """Text exceeding 10,000 code points is rejected with text_too_long."""
    long_text = "a" * 10_001
    with pytest.raises(ValidationError) as exc_info:
        validate_analysis_text(long_text, max_code_points=10_000)
    assert exc_info.value.code == "text_too_long"
    assert exc_info.value.status_code == 400


def test_validate_text_utf8_byte_limit_enforced() -> None:
    """
    Text within code-point limit but exceeding 40,000 UTF-8 bytes is rejected with text_too_long.
    Each 4-byte emoji (e.g. 🔒) is 1 code point, so 10,001 emojis = 40,004 UTF-8 bytes.
    """
    emoji_text = "🔒" * 10_001  # 10,001 code points, 40,004 bytes
    with pytest.raises(ValidationError) as exc_info:
        validate_analysis_text(emoji_text, max_code_points=20_000, max_utf8_bytes=40_000)
    assert exc_info.value.code == "text_too_long"
    assert exc_info.value.status_code == 400


def test_validate_text_multilingual_unicode_accepted() -> None:
    """Valid multilingual text including Arabic, Urdu, Chinese, and emojis passes cleanly."""
    multilingual = "TrustCue alert: بینک اکاؤنٹ الرٹ। 请确认。 ⚠️ Urgent verification required!"
    result = validate_analysis_text(multilingual)
    assert result == multilingual


def test_validate_text_rejects_null_bytes_and_control_chars() -> None:
    """Disallowed control characters (e.g. null byte, bell, escape) are rejected."""
    for bad_char in ["\x00", "\x01", "\x07", "\x08", "\x1b", "\x7f"]:
        text_with_control = f"Alert message with bad control: {bad_char}"
        with pytest.raises(ValidationError) as exc_info:
            validate_analysis_text(text_with_control)
        assert exc_info.value.code == "malformed_unicode"
        assert exc_info.value.status_code == 400


def test_validate_text_preserves_standard_newlines_and_tabs() -> None:
    """Standard whitespace characters (\t, \n, \r) are permitted."""
    text_with_newlines = "Line 1\nLine 2\r\n\tIndented details."
    result = validate_analysis_text(text_with_newlines)
    assert result == text_with_newlines


def test_api_analysis_endpoint_validates_payload() -> None:
    """API endpoint enforces validation on AnalysisAiRequest and returns sanitized error envelope."""
    settings = Settings(SUPABASE_JWT_SECRET="test-jwt-secret-key-32-chars-long!", ENVIRONMENT="test")
    app = create_app(settings=settings)
    client = TestClient(app)

    user_id = "00000000-0000-0000-0000-000000000001"
    token = create_test_jwt(user_id=user_id)
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Reject whitespace only
    resp = client.post(
        "/api/v1/analysis/ai",
        headers=headers,
        json={
            "snapshotId": "snap-1",
            "text": "    ",
            "source": "messageText",
            "sourceRevision": "rev-1",
            "clientTimestamp": "2026-10-15T12:00:00Z",
        },
    )
    assert resp.status_code in (400, 422)
    assert "error" in resp.json()

    # 2. Reject disallowed control characters
    resp_ctrl = client.post(
        "/api/v1/analysis/ai",
        headers=headers,
        json={
            "snapshotId": "snap-1",
            "text": "Suspicious text with null byte: \x00",
            "source": "messageText",
            "sourceRevision": "rev-1",
            "clientTimestamp": "2026-10-15T12:00:00Z",
        },
    )
    assert resp_ctrl.status_code in (400, 422)

    # 3. Reject extra fields (extra="forbid")
    resp_extra = client.post(
        "/api/v1/analysis/ai",
        headers=headers,
        json={
            "snapshotId": "snap-1",
            "text": "Valid text message",
            "source": "messageText",
            "sourceRevision": "rev-1",
            "clientTimestamp": "2026-10-15T12:00:00Z",
            "unexpected_extra_field": "injected_value",
        },
    )
    assert resp_extra.status_code == 422
    assert "extra_forbidden" in str(resp_extra.json())
