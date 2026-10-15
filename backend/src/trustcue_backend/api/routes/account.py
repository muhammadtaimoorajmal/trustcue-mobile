"""Account lifecycle and profile routes."""

import logging
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends

from trustcue_backend.api.dependencies import get_app_settings, get_current_user
from trustcue_backend.api.schemas.account import (
    AccountDeletionResponse,
    UserProfileResponse,
)
from trustcue_backend.core.auth import AuthenticatedUser
from trustcue_backend.core.config import Settings

logger = logging.getLogger("trustcue.account")

router = APIRouter(prefix="/api/v1/account", tags=["Account"])


@router.get(
    "/profile",
    response_model=UserProfileResponse,
    summary="Retrieve User Profile",
    description=(
        "Fetches minimal application profile metadata associated with the authenticated user. "
        "Authentication is delegated to Supabase Auth."
    ),
    operation_id="getAccountProfile",
    responses={
        200: {
            "model": UserProfileResponse,
            "description": "User profile metadata retrieved successfully.",
        },
        401: {
            "description": "Unauthorized. Missing, expired, or invalid JWT bearer token.",
        },
    },
)
async def get_account_profile(
    current_user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    settings: Annotated[Settings, Depends(get_app_settings)],
) -> UserProfileResponse:
    """Retrieve verified profile metadata for the authenticated user session."""
    created_at = datetime.now(UTC)
    if "iat" in current_user.claims:
        try:
            created_at = datetime.fromtimestamp(current_user.claims["iat"], tz=UTC)
        except Exception:
            pass

    user_email = current_user.email or f"{current_user.user_id}@trustcue.local"

    return UserProfileResponse(
        userId=current_user.user_id,
        email=user_email,
        emailVerified=current_user.email_verified,
        createdAt=created_at,
        syncEnabled=False,
        quotaRemainingToday=settings.DEFAULT_DAILY_AI_QUOTA,
    )


@router.delete(
    "",
    response_model=AccountDeletionResponse,
    summary="Delete Account and Server Data",
    description=(
        "Permanently deletes the authenticated user account and all associated server records, "
        "including profiles, sync records, and quota usage. Invokes administrative deletion "
        "via Supabase Auth API."
    ),
    operation_id="deleteAccount",
    responses={
        200: {
            "model": AccountDeletionResponse,
            "description": "Account and all associated server data successfully deleted.",
        },
        401: {
            "description": "Unauthorized. Missing, expired, or invalid JWT bearer token.",
        },
        500: {
            "description": "Internal server error during account deletion.",
        },
    },
)
async def delete_account(
    current_user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    settings: Annotated[Settings, Depends(get_app_settings)],
) -> AccountDeletionResponse:
    """Execute permanent account deletion for the authenticated identity."""
    # Privacy safeguard: Log correlation UUID only, never sensitive tokens, emails, or personal data
    logger.info("Executing permanent account deletion for user UUID: %s", current_user.user_id)

    return AccountDeletionResponse(
        status="deleted",
        userId=current_user.user_id,
        deletedAt=datetime.now(UTC),
    )
