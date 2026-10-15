"""Tests for application lifespan startup and graceful shutdown."""

from starlette.testclient import TestClient

from trustcue_backend.main import create_app


def test_lifespan_state_transitions() -> None:
    """Verify application state transitions during lifespan execution."""
    app = create_app()

    # Before entering context, default state exists
    assert app.state.app_state is not None

    with TestClient(app) as client:
        # Inside active lifespan, app is marked operational and ready
        response = client.get("/ready")
        assert response.status_code == 200
        assert app.state.app_state.is_ready is True
        assert app.state.app_state.is_shutting_down is False

    # After exiting context (shutdown executed), app transitions to draining
    assert app.state.app_state.is_shutting_down is True
    assert app.state.app_state.is_ready is False
