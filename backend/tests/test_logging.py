"""Tests verifying that logs never capture sensitive payloads, queries, or secrets."""

import logging

import pytest
from starlette.testclient import TestClient

from trustcue_backend.core.config import Settings
from trustcue_backend.main import create_app


def test_request_id_generation_and_propagation(client: TestClient) -> None:
    """Ensure every HTTP interaction generates a distinct UUID4 request ID."""
    res1 = client.get("/health")
    res2 = client.get("/health")

    id1 = res1.headers.get("X-Request-ID")
    id2 = res2.headers.get("X-Request-ID")

    assert id1 is not None and id2 is not None
    assert id1 != id2
    assert len(id1) == 36


def test_logs_do_not_leak_query_parameters(caplog: pytest.LogCaptureFixture) -> None:
    """Verify that user-controlled URL query strings are omitted from operational logs."""
    app = create_app(settings=Settings(LOG_LEVEL="INFO"))
    client = TestClient(app)

    sensitive_query_val = "SECRET_SESSION_TOKEN_ABCXYZ_999"

    with caplog.at_level(logging.INFO):
        response = client.get(f"/health?secret_key={sensitive_query_val}")
        assert response.status_code == 200

        # Check all logged messages
        all_logs = " ".join(record.getMessage() for record in caplog.records)
        assert sensitive_query_val not in all_logs
        assert "secret_key" not in all_logs


def test_logs_do_not_leak_arbitrary_unmatched_urls(caplog: pytest.LogCaptureFixture) -> None:
    """Verify that unknown probe paths and injected queries are masked in access logs."""
    app = create_app(settings=Settings(LOG_LEVEL="INFO"))
    client = TestClient(app)

    malicious_probe = "/some/random/unregistered/probe?exploit=true&token=SECRET_TOKEN"

    with caplog.at_level(logging.INFO):
        response = client.get(malicious_probe)
        assert response.status_code == 404

        all_logs = " ".join(record.getMessage() for record in caplog.records)
        assert "SECRET_TOKEN" not in all_logs
        assert "exploit" not in all_logs
        assert "<unmatched_route>" in all_logs


def test_logs_do_not_contain_sha256_content_hashes(caplog: pytest.LogCaptureFixture) -> None:
    """Ensure routine telemetry never logs SHA-256 message content hashes."""
    app = create_app(settings=Settings(LOG_LEVEL="INFO"))
    client = TestClient(app)

    with caplog.at_level(logging.INFO):
        client.get("/health")
        client.get("/ready")

        all_logs = " ".join(record.getMessage() for record in caplog.records).lower()
        assert "sha256" not in all_logs
        assert "sha-256" not in all_logs
