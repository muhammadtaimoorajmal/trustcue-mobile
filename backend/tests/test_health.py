"""Tests for health and readiness probes."""

from datetime import datetime

from starlette.testclient import TestClient

from trustcue_backend.core.config import Settings
from trustcue_backend.main import create_app


def test_health_check_endpoint(client: TestClient) -> None:
    """Test /health liveness probe returns 200 with valid schema and uptime."""
    response = client.get("/health")
    assert response.status_code == 200

    data = response.json()
    assert data["status"] == "ok"
    assert data["version"] == "0.1.0"
    assert isinstance(data["uptimeSeconds"], int)
    assert data["uptimeSeconds"] >= 0

    # Validate ISO timestamp
    parsed_time = datetime.fromisoformat(data["timestamp"])
    assert parsed_time is not None

    # Assert X-Request-ID correlation header is present
    assert "X-Request-ID" in response.headers
    assert len(response.headers["X-Request-ID"]) == 36  # Standard UUID length


def test_readiness_probe_operational_state(client: TestClient) -> None:
    """Test /ready returns 200 and correctly states foundation is ok while subsystems are unconfigured."""
    response = client.get("/ready")
    assert response.status_code == 200

    data = response.json()
    assert data["status"] == "ready"
    assert data["dependencies"]["foundation"] == "ok"
    assert data["dependencies"]["authProvider"] == "unconfigured"
    assert data["dependencies"]["database"] == "unconfigured"
    assert data["dependencies"]["aiProvider"] == "unconfigured"

    # Must not leak internal paths or secrets
    text_content = response.text.lower()
    assert "password" not in text_content
    assert "secret" not in text_content
    assert "key" not in text_content


def test_readiness_probe_draining_degraded_state(default_settings: Settings) -> None:
    """Test /ready returns 503 when the application transitions to draining/shutdown state."""
    app = create_app(settings=default_settings)

    with TestClient(app) as test_client:
        # Verify initial healthy state
        initial_res = test_client.get("/ready")
        assert initial_res.status_code == 200

        # Simulate shutdown draining state
        app.state.app_state.mark_draining()

        degraded_res = test_client.get("/ready")
        assert degraded_res.status_code == 503

        data = degraded_res.json()
        assert data["status"] == "degraded"
        assert data["dependencies"]["foundation"] == "degraded"
        assert data["dependencies"]["authProvider"] == "error"
        assert data["dependencies"]["database"] == "error"
        assert data["dependencies"]["aiProvider"] == "error"
