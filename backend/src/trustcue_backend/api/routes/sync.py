"""Cloud report synchronization routes for Module 39."""

import logging
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from trustcue_backend.api.dependencies import (
    get_current_user,
    get_sync_service,
)
from trustcue_backend.api.schemas.sync import (
    SyncPurgeResponse,
    SyncReportsPullResponse,
    SyncReportsPushRequest,
    SyncReportsPushResponse,
)
from trustcue_backend.core.auth import AuthenticatedUser
from trustcue_backend.services.sync_service import SyncService

logger = logging.getLogger("trustcue.sync")

router = APIRouter(prefix="/api/v1/sync/reports", tags=["Sync"])


@router.get(
    "",
    response_model=SyncReportsPullResponse,
    summary="List Synced Reports",
    description=(
        "Retrieves user-opted report summaries modified after the optional 'since' timestamp. "
        "Strictly gated on user profile having syncEnabled=true."
    ),
    operation_id="listSyncedReports",
    responses={
        200: {
            "model": SyncReportsPullResponse,
            "description": "Report summaries retrieved successfully.",
        },
        401: {
            "description": "Unauthorized. Missing, expired, or invalid JWT bearer token.",
        },
        403: {
            "description": "Forbidden. Cloud synchronization is disabled for this user.",
        },
    },
)
async def list_synced_reports(
    current_user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    sync_service: Annotated[SyncService, Depends(get_sync_service)],
    since: Annotated[
        str | None,
        Query(description="UTC timestamp filter. Only reports updated after this time are returned."),
    ] = None,
    limit: Annotated[
        int,
        Query(ge=1, le=100, description="Maximum number of reports to return per batch."),
    ] = 50,
    cursor: Annotated[
        str | None,
        Query(description="Optional pagination cursor."),
    ] = None,
) -> SyncReportsPullResponse:
    """Retrieve synced report summaries for the authenticated user session."""
    parsed_since: datetime | None = None
    if since is not None:
        try:
            clean_since = since.replace(" ", "+")
            parsed_since = datetime.fromisoformat(clean_since)
        except Exception:
            from trustcue_backend.core.errors import TrustCueError
            raise TrustCueError(
                code="invalid_query_parameter",
                message="Invalid 'since' timestamp format. Expected ISO-8601 string.",
                status_code=status.HTTP_400_BAD_REQUEST,
            ) from None

    clean_cursor: str | None = None
    if cursor is not None:
        clean_cursor = cursor.replace(" ", "+")

    return await sync_service.pull_reports(
        user_id=current_user.user_id,
        since=parsed_since,
        limit=limit,
        cursor=clean_cursor,
    )


@router.post(
    "",
    response_model=SyncReportsPushResponse,
    status_code=status.HTTP_200_OK,
    summary="Batch Sync Reports",
    description=(
        "Uploads a batch of non-sensitive report summaries and tombstones for the authenticated user. "
        "Strictly rejects raw message text, excerpts, screenshots, and hashes. "
        "Requires syncEnabled=true on the user's profile."
    ),
    operation_id="syncReportsBatch",
    responses={
        200: {
            "model": SyncReportsPushResponse,
            "description": "Batch report ingestion processed successfully.",
        },
        400: {
            "description": "Bad Request. Payload contains forbidden fields or invalid format.",
        },
        401: {
            "description": "Unauthorized. Missing, expired, or invalid JWT bearer token.",
        },
        403: {
            "description": "Forbidden. Cloud synchronization is disabled for this user.",
        },
    },
)
async def sync_reports_batch(
    request: SyncReportsPushRequest,
    current_user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    sync_service: Annotated[SyncService, Depends(get_sync_service)],
) -> SyncReportsPushResponse:
    """Ingest a batch of report summaries and tombstones."""
    return await sync_service.push_reports(
        user_id=current_user.user_id,
        request=request,
    )


@router.delete(
    "",
    response_model=SyncPurgeResponse,
    summary="Purge All Cloud Synced Reports",
    description=(
        "Purges all cloud-backed report summaries for the authenticated user. "
        "Local device reports remain unaffected."
    ),
    operation_id="purgeSyncedReports",
    responses={
        200: {
            "model": SyncPurgeResponse,
            "description": "All cloud synced reports purged.",
        },
        401: {
            "description": "Unauthorized. Missing, expired, or invalid JWT bearer token.",
        },
    },
)
async def purge_synced_reports(
    current_user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    sync_service: Annotated[SyncService, Depends(get_sync_service)],
) -> SyncPurgeResponse:
    """Purge all cloud synced reports for the calling user."""
    return await sync_service.purge_reports(user_id=current_user.user_id)
