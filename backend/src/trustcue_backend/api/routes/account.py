"""Account lifecycle and profile routes."""

import logging
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends

from trustcue_backend.api.dependencies import (
    get_account_service,
    get_current_user,
)
from trustcue_backend.api.schemas.account import (
    AccountDeletionResponse,
    UpdateUserProfileRequest,
    UserProfileResponse,
)
from trustcue_backend.core.auth import AuthenticatedUser
from trustcue_backend.services.account_service import AccountService

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
    account_service: Annotated[AccountService, Depends(get_account_service)],
) -> UserProfileResponse:
    """Retrieve verified profile metadata for the authenticated user session."""
    created_at = datetime.now(UTC)
    if "iat" in current_user.claims:
        try:
            created_at = datetime.fromtimestamp(current_user.claims["iat"], tz=UTC)
        except Exception:
            pass

    return await account_service.get_profile(
        user_id=current_user.user_id,
        email=current_user.email,
        email_verified=current_user.email_verified,
        fallback_created_at=created_at,
    )


@router.patch(
    "/profile",
    response_model=UserProfileResponse,
    summary="Update User Profile",
    description=(
        "Updates mutable profile fields (such as displayName) for the authenticated user. "
        "Persists to PostgREST public.profiles with recovery fallback."
    ),
    operation_id="updateAccountProfile",
    responses={
        200: {
            "model": UserProfileResponse,
            "description": "User profile metadata updated successfully.",
        },
        400: {
            "description": "Bad request. Invalid profile payload.",
        },
        401: {
            "description": "Unauthorized. Missing, expired, or invalid JWT bearer token.",
        },
    },
)
async def update_account_profile(
    payload: UpdateUserProfileRequest,
    current_user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    account_service: Annotated[AccountService, Depends(get_account_service)],
) -> UserProfileResponse:
    """Update profile display name for the authenticated user."""
    created_at = datetime.now(UTC)
    if "iat" in current_user.claims:
        try:
            created_at = datetime.fromtimestamp(current_user.claims["iat"], tz=UTC)
        except Exception:
            pass

    return await account_service.update_profile(
        user_id=current_user.user_id,
        display_name=payload.display_name,
        email=current_user.email,
        email_verified=current_user.email_verified,
        fallback_created_at=created_at,
        sync_enabled=payload.sync_enabled,
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
    account_service: Annotated[AccountService, Depends(get_account_service)],
) -> AccountDeletionResponse:
    """Execute permanent account deletion for the authenticated identity."""
    return await account_service.delete_account(user_id=current_user.user_id)
