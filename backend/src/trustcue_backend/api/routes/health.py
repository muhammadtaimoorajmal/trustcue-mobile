"""Health and readiness probe routes."""

from datetime import UTC, datetime
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Response, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from trustcue_backend import __version__
from trustcue_backend.api.dependencies import get_app_state
from trustcue_backend.core.state import AppState

router = APIRouter(tags=["Health & Readiness"])


class HealthResponse(BaseModel):
    """Lightweight liveness probe response."""

    status: Literal["ok"] = "ok"
    version: str
    timestamp: datetime
    uptimeSeconds: int


class ReadinessDependencies(BaseModel):
    """Subsystem status breakdown."""

    foundation: Literal["ok", "degraded"]
    authProvider: Literal["ok", "error", "disabled", "unconfigured"]
    database: Literal["ok", "error", "disabled", "unconfigured"]
    aiProvider: Literal["ok", "error", "disabled", "unconfigured"]


class ReadinessResponse(BaseModel):
    """Readiness probe response indicating whether the service can accept work."""

    status: Literal["ready", "degraded"]
    timestamp: datetime
    dependencies: ReadinessDependencies


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="Service Health Check",
    description="Lightweight liveness probe. Returns 200 if the service process is alive.",
)
async def get_health(
    app_state: Annotated[AppState, Depends(get_app_state)],
) -> HealthResponse:
    """Return process health and uptime."""
    return HealthResponse(
        status="ok",
        version=__version__,
        timestamp=datetime.now(UTC),
        uptimeSeconds=app_state.uptime_seconds,
    )


@router.get(
    "/ready",
    response_model=ReadinessResponse,
    responses={
        200: {"model": ReadinessResponse, "description": "Service foundation is ready."},
        503: {"model": ReadinessResponse, "description": "Service is degraded or draining."},
    },
    summary="Service Readiness Probe",
    description="Evaluates operational readiness for implemented capabilities without calling external AI providers.",
)
async def get_readiness(
    response: Response,
    app_state: Annotated[AppState, Depends(get_app_state)],
) -> ReadinessResponse | JSONResponse:
    """Evaluate service readiness."""
    status_str, dep_dict = app_state.get_readiness_status()
    now = datetime.now(UTC)

    dependencies = ReadinessDependencies(
        foundation=dep_dict["foundation"],  # type: ignore[arg-type]
        authProvider=dep_dict["authProvider"],  # type: ignore[arg-type]
        database=dep_dict["database"],  # type: ignore[arg-type]
        aiProvider=dep_dict["aiProvider"],  # type: ignore[arg-type]
    )

    readiness_data = ReadinessResponse(
        status=status_str,
        timestamp=now,
        dependencies=dependencies,
    )

    if status_str == "degraded":
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=readiness_data.model_dump(mode="json"),
        )

    return readiness_data
