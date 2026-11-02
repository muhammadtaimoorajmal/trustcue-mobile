"""Account profile persistence and administrative deletion service."""

import logging
from datetime import UTC, datetime
from typing import Any

import httpx

from trustcue_backend.api.schemas.account import (
    AccountDeletionResponse,
    UserProfileResponse,
)
from trustcue_backend.core.config import Settings
from trustcue_backend.core.errors import TrustCueError
from trustcue_backend.core.quota import QuotaStore
from trustcue_backend.core.state import AppState

logger = logging.getLogger("trustcue.account")


class AccountService:
    """
    Manages user profile queries, profile updates, and permanent account deletion.

    Interacts with Supabase PostgREST and Auth Admin API when configured;
    falls back cleanly to stateful in-memory tracking in test and offline modes.
    """

    def __init__(
        self,
        settings: Settings,
        app_state: AppState,
        quota_store: QuotaStore,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self.settings = settings
        self.app_state = app_state
        self.quota_store = quota_store
        self._http_client = http_client

    def _get_auth_headers(self) -> dict[str, str]:
        key = self.settings.SUPABASE_SERVICE_ROLE_KEY or ""
        return {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    async def get_profile(
        self,
        user_id: str,
        email: str | None,
        email_verified: bool,
        fallback_created_at: datetime,
    ) -> UserProfileResponse:
        """
        Retrieve profile metadata, querying PostgREST public.profiles with RPC fallback.
        """
        user_email = email or f"{user_id}@trustcue.local"
        remaining_quota = await self.quota_store.get_remaining_quota(user_id)
        display_name: str | None = self.app_state.get_display_name(user_id)
        avatar_path: str | None = self.app_state.get_avatar_path(user_id)
        created_at: datetime = fallback_created_at
        sync_enabled: bool = self.app_state.get_sync_enabled(user_id)

        if self.settings.SUPABASE_URL and self.settings.SUPABASE_SERVICE_ROLE_KEY:
            client = self._http_client or httpx.AsyncClient(timeout=5.0)
            close_client = self._http_client is None
            try:
                base_url = self.settings.SUPABASE_URL.rstrip("/")
                resp = await client.get(
                    f"{base_url}/rest/v1/profiles?id=eq.{user_id}&select=id,display_name,terms_version,sync_enabled,sync_generation,avatar_path,created_at,updated_at",
                    headers=self._get_auth_headers(),
                )
                if resp.status_code == 200:
                    data = resp.json()
                    if isinstance(data, list) and len(data) > 0:
                        row = data[0]
                        display_name = row.get("display_name")
                        sync_enabled = bool(row.get("sync_enabled", False))
                        sync_generation = int(row.get("sync_generation", 1))
                        avatar_path = row.get("avatar_path")
                        self.app_state.set_sync_enabled(user_id, sync_enabled)
                        self.app_state.set_sync_generation(user_id, sync_generation)
                        self.app_state.set_avatar_path(user_id, avatar_path)
                        if display_name is not None:
                            self.app_state.set_display_name(user_id, display_name)
                        raw_created = row.get("created_at")
                        if raw_created:
                            try:
                                created_at = datetime.fromisoformat(raw_created)
                            except Exception:
                                pass
                    elif isinstance(data, list) and len(data) == 0:
                        # Profile record missing; trigger recovery via ensure_profile_exists RPC
                        logger.info(
                            "Profile not found for user %s; calling ensure_profile_exists", user_id
                        )
                        await client.post(
                            f"{base_url}/rest/v1/rpc/ensure_profile_exists",
                            headers=self._get_auth_headers(),
                            json={"p_user_id": user_id},
                        )
            except Exception as exc:
                logger.warning(
                    "PostgREST profile retrieval failed for user %s: %s", user_id, str(exc)
                )
            finally:
                if close_client:
                    await client.aclose()

        return UserProfileResponse(
            userId=user_id,
            displayName=display_name,
            avatarPath=avatar_path,
            avatarUrl=None,
            email=user_email,
            emailVerified=email_verified,
            createdAt=created_at,
            syncEnabled=sync_enabled,
            syncGeneration=self.app_state.get_sync_generation(user_id),
            quotaRemainingToday=remaining_quota,
        )

    async def update_profile(
        self,
        user_id: str,
        display_name: str | None,
        email: str | None,
        email_verified: bool,
        fallback_created_at: datetime,
        sync_enabled: bool | None = None,
        avatar_path: str | None = None,
        clear_avatar: bool = False,
    ) -> UserProfileResponse:
        """
        Update user profile display name, avatar path, and sync settings with PostgREST persistence.
        Cached state is updated ONLY after confirmed database persistence.
        """
        user_email = email or f"{user_id}@trustcue.local"
        remaining_quota = await self.quota_store.get_remaining_quota(user_id)
        created_at: datetime = fallback_created_at

        if self.settings.SUPABASE_URL and self.settings.SUPABASE_SERVICE_ROLE_KEY:
            client = self._http_client or httpx.AsyncClient(timeout=5.0)
            close_client = self._http_client is None
            try:
                base_url = self.settings.SUPABASE_URL.rstrip("/")
                # Ensure profile exists before patching
                await client.post(
                    f"{base_url}/rest/v1/rpc/ensure_profile_exists",
                    headers=self._get_auth_headers(),
                    json={"p_user_id": user_id},
                )
                patch_payload: dict[str, Any] = {
                    "updated_at": datetime.now(UTC).isoformat(),
                }
                if display_name is not None:
                    patch_payload["display_name"] = display_name
                if sync_enabled is not None:
                    patch_payload["sync_enabled"] = sync_enabled
                if clear_avatar:
                    patch_payload["avatar_path"] = None
                elif avatar_path is not None:
                    patch_payload["avatar_path"] = avatar_path

                patch_headers = self._get_auth_headers()
                patch_headers["Prefer"] = "return=representation"

                resp = await client.patch(
                    f"{base_url}/rest/v1/profiles?id=eq.{user_id}",
                    headers=patch_headers,
                    json=patch_payload,
                )
                if resp.status_code not in (200, 204):
                    logger.error(
                        "PostgREST profile update returned %s for user %s: %s",
                        resp.status_code,
                        user_id,
                        resp.text,
                    )
                    raise TrustCueError(
                        code="database_error",
                        message="Failed to persist user profile update.",
                        status_code=503,
                    )

                # Confirm intended row was updated
                if resp.status_code == 200:
                    try:
                        rows = resp.json()
                        if isinstance(rows, list):
                            if len(rows) == 0:
                                raise TrustCueError(
                                    code="not_found",
                                    message="User profile record not found.",
                                    status_code=404,
                                )
                            updated_row = rows[0]
                            if "display_name" in updated_row:
                                display_name = updated_row.get("display_name")
                            if "sync_enabled" in updated_row:
                                sync_enabled = bool(updated_row.get("sync_enabled", False))
                            if "avatar_path" in updated_row:
                                avatar_path = updated_row.get("avatar_path")
                    except TrustCueError:
                        raise
                    except Exception as exc:
                        logger.warning("Could not parse PostgREST response representation: %s", exc)

                # Cache in local state ONLY after successful PostgREST update
                if display_name is not None:
                    self.app_state.set_display_name(user_id, display_name)
                if sync_enabled is not None:
                    self.app_state.set_sync_enabled(user_id, sync_enabled)
                if clear_avatar:
                    self.app_state.set_avatar_path(user_id, None)
                elif avatar_path is not None:
                    self.app_state.set_avatar_path(user_id, avatar_path)
            except TrustCueError:
                raise
            except Exception as exc:
                logger.error(
                    "Exception during PostgREST profile update for user %s: %s", user_id, str(exc)
                )
                raise TrustCueError(
                    code="database_error",
                    message="An unexpected error occurred while updating profile.",
                    status_code=503,
                ) from exc
            finally:
                if close_client:
                    await client.aclose()
        else:
            # In-memory test / offline fallback mode
            if display_name is not None:
                self.app_state.set_display_name(user_id, display_name)
            if sync_enabled is not None:
                self.app_state.set_sync_enabled(user_id, sync_enabled)
            if clear_avatar:
                self.app_state.set_avatar_path(user_id, None)
            elif avatar_path is not None:
                self.app_state.set_avatar_path(user_id, avatar_path)

        effective_display_name = self.app_state.get_display_name(user_id)
        effective_sync_enabled = self.app_state.get_sync_enabled(user_id)
        effective_avatar_path = self.app_state.get_avatar_path(user_id)

        return UserProfileResponse(
            userId=user_id,
            displayName=effective_display_name,
            avatarPath=effective_avatar_path,
            avatarUrl=None,
            email=user_email,
            emailVerified=email_verified,
            createdAt=created_at,
            syncEnabled=effective_sync_enabled,
            syncGeneration=self.app_state.get_sync_generation(user_id),
            quotaRemainingToday=remaining_quota,
        )

    async def delete_account(self, user_id: str) -> AccountDeletionResponse:
        """
        Permanently delete user account via Supabase Auth Admin API and invalidate active session.
        Purges avatar storage objects under the user prefix.
        """
        logger.info("Executing permanent account deletion for user UUID: %s", user_id)

        # 1. Invalidate session and clear user data in local application state immediately
        self.app_state.mark_user_deleted(user_id)
        self.app_state.set_avatar_path(user_id, None)

        # 2. Invoke Supabase Admin deletion and Storage cleanup if configured
        if self.settings.SUPABASE_URL and self.settings.SUPABASE_SERVICE_ROLE_KEY:
            client = self._http_client or httpx.AsyncClient(timeout=8.0)
            close_client = self._http_client is None
            try:
                base_url = self.settings.SUPABASE_URL.rstrip("/")

                # Clean up private avatar storage objects for user
                try:
                    list_resp = await client.post(
                        f"{base_url}/storage/v1/object/list/avatars",
                        headers=self._get_auth_headers(),
                        json={"prefix": f"{user_id}/", "limit": 100},
                    )
                    if list_resp.status_code == 200:
                        objects = list_resp.json()
                        if isinstance(objects, list) and objects:
                            prefixes = [
                                f"{user_id}/{obj['name']}"
                                for obj in objects
                                if isinstance(obj, dict) and obj.get("name")
                            ]
                            if prefixes:
                                await client.request(
                                    "DELETE",
                                    f"{base_url}/storage/v1/object/avatars",
                                    headers=self._get_auth_headers(),
                                    json={"prefixes": prefixes},
                                )
                except Exception as exc:
                    logger.warning(
                        "Failed to clean up avatar storage for user %s: %s", user_id, str(exc)
                    )

                admin_delete_url = f"{base_url}/auth/v1/admin/users/{user_id}"
                resp = await client.delete(
                    admin_delete_url,
                    headers=self._get_auth_headers(),
                )
                # 200 OK or 404 Not Found (already deleted) both denote success
                if resp.status_code not in (200, 204, 404):
                    logger.error(
                        "Supabase Admin API account deletion returned %s for user %s: %s",
                        resp.status_code,
                        user_id,
                        resp.text,
                    )
                    raise TrustCueError(
                        code="internal_error",
                        message="Failed to execute administrative account deletion on auth provider.",
                        status_code=500,
                    )
            except TrustCueError:
                raise
            except Exception as exc:
                logger.error(
                    "Exception during Supabase Admin account deletion for user %s: %s",
                    user_id,
                    str(exc),
                )
                raise TrustCueError(
                    code="internal_error",
                    message="An unexpected error occurred during administrative account deletion.",
                    status_code=500,
                ) from exc
            finally:
                if close_client:
                    await client.aclose()

        return AccountDeletionResponse(
            status="deleted",
            userId=user_id,
            deletedAt=datetime.now(UTC),
        )
