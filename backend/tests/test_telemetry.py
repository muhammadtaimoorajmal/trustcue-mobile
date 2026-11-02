"""Tests for privacy-safe operational observability, latency metrics, and bounded telemetry."""

import logging
import uuid

import pytest
from starlette.testclient import TestClient

from trustcue_backend.core.config import Settings
from trustcue_backend.core.telemetry import (
    CORRELATION_ID_PATTERN,
    metrics,
    record_event,
    record_stage_duration,
    validate_or_generate_correlation_id,
)
from trustcue_backend.main import create_app


def test_correlation_id_validation_and_generation() -> None:
    """Validates strict character and length bounding for correlation IDs."""
    # Valid custom IDs (8 to 64 chars, allowed charset [a-zA-Z0-9_.-])
    valid_id_1 = "test-corr-id-12345"
    valid_id_2 = "TRACE_ABC.123_XYZ"
    valid_id_3 = "a" * 64

    assert validate_or_generate_correlation_id(valid_id_1) == valid_id_1
    assert validate_or_generate_correlation_id(valid_id_2) == valid_id_2
    assert validate_or_generate_correlation_id(valid_id_3) == valid_id_3

    # Invalid IDs must be rejected and replaced with server-controlled generated ID
    too_short = "short"  # < 8 chars
    too_long = "b" * 65  # > 64 chars
    injection_attempt = "req_12345; DROP TABLE users;--"
    spaces_attempt = "req 12345678"
    unicode_attempt = "req_12345_\u00e9\u00e8"

    for invalid_val in [too_short, too_long, injection_attempt, spaces_attempt, unicode_attempt, None, ""]:
        generated = validate_or_generate_correlation_id(invalid_val)
        assert generated != invalid_val
        assert CORRELATION_ID_PATTERN.match(generated)
        assert generated.startswith("req_")


def test_correlation_id_header_propagation_and_sanitization() -> None:
    """Verifies middleware accepts valid correlation IDs and masks invalid/injected headers."""
    app = create_app(settings=Settings(LOG_LEVEL="INFO"))
    client = TestClient(app)

    # 1. Valid custom correlation ID
    custom_id = "valid-trace-id-100200"
    resp = client.get("/health", headers={"X-Correlation-ID": custom_id})
    assert resp.status_code == 200
    assert resp.headers.get("X-Correlation-ID") == custom_id
    assert resp.headers.get("X-Request-ID") == custom_id

    # 2. Malicious / invalid incoming correlation ID is sanitized
    malicious_header = "<script>alert('xss')</script>"
    resp2 = client.get("/health", headers={"X-Correlation-ID": malicious_header})
    assert resp2.status_code == 200
    sanitized_id = resp2.headers.get("X-Correlation-ID")
    assert sanitized_id is not None
    assert "<script>" not in sanitized_id
    assert CORRELATION_ID_PATTERN.match(sanitized_id)


def test_metrics_collector_cardinality_boundedness() -> None:
    """
    Ensure the metrics collector enforces bounded cardinality:
    Only finite enum keys, never user IDs, reservation IDs, or prompt excerpts.
    """
    metrics.reset()

    # Record valid operational stages
    record_stage_duration("request_total", 45.2, "success")
    record_stage_duration("quota_reserve", 12.5, "success")
    record_stage_duration("provider_inference", 350.0, "provider_timeout_read")
    record_stage_duration("quota_settle", 8.1, "database_error")
    record_event("quota_exhausted", "quota_exhausted")

    summary = metrics.get_summary()

    # Verify counters
    assert "quota_exhausted:quota_exhausted" in summary["counters"]

    # Verify latencies
    latencies = summary["latencies"]
    assert "request_total:success" in latencies
    assert latencies["request_total:success"]["count"] == 1
    assert latencies["request_total:success"]["avg_ms"] == 45.2

    assert "provider_inference:provider_timeout_read" in latencies
    assert latencies["provider_inference:provider_timeout_read"]["avg_ms"] == 350.0

    # Ensure zero unbounded keys exist
    for key in list(summary["counters"].keys()) + list(summary["latencies"].keys()):
        # Keys must strictly match '<valid_stage_or_event>:<valid_outcome>'
        stage_or_metric, outcome = key.split(":")
        assert outcome in {
            "success", "client_error", "auth_error", "consent_rejected",
            "concurrency_rejected", "quota_exhausted", "rate_limited",
            "provider_timeout_connect", "provider_timeout_read", "provider_error",
            "malformed_output", "grounding_failed", "database_error", "internal_error",
        }


def test_synthetic_secrets_and_user_text_never_leak_in_telemetry(caplog: pytest.LogCaptureFixture) -> None:
    """
    Synthetic secret probe: prove that passwords, auth tokens, and message excerpts
    are completely absent from all telemetry and access log outputs.
    """
    app = create_app(settings=Settings(LOG_LEVEL="INFO"))
    client = TestClient(app)

    synthetic_password = "SUPER_SECRET_USER_PASSWORD_XYZ123"
    synthetic_user_text = "CONFIDENTIAL_BANK_ACCOUNT_9876543210"
    synthetic_jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.SYNTHETIC_PAYLOAD.SIGNATURE"

    with caplog.at_level(logging.INFO):
        # 1. Unauthenticated or malformed request
        client.post(
            "/api/v1/analysis/ai",
            headers={"Authorization": f"Bearer {synthetic_jwt}"},
            json={
                "snapshotId": str(uuid.uuid4()),
                "text": synthetic_user_text,
                "consent": {
                    "granted": True,
                    "disclosureVersion": "1.0.0",
                    "recipient": "trustcue-backend",
                    "provider": "groq-cloud",
                },
            },
        )

        # 2. Probe with query parameter
        client.get(f"/health?pwd={synthetic_password}")

        all_logs = " ".join(record.getMessage() for record in caplog.records)
        assert synthetic_password not in all_logs
        assert synthetic_user_text not in all_logs
        assert synthetic_jwt not in all_logs
