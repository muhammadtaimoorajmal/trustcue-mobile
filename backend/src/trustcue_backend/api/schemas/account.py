"""Account response schemas conforming to OpenAPI 3.1.0 specifications."""

import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class UserProfileResponse(BaseModel):
    """Minimal application user profile metadata."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    user_id: str = Field(
        alias="userId",
        description="Unique user UUID.",
    )
    email: str = Field(
        description="User primary email address.",
    )
    email_verified: bool = Field(
        alias="emailVerified",
        description="Whether email address is verified.",
    )
    created_at: datetime = Field(
        alias="createdAt",
        description="Timestamp of account creation.",
    )
    display_name: str | None = Field(
        default=None,
        alias="displayName",
        description="Sanitized user display name (max 64 characters).",
    )
    avatar_path: str | None = Field(
        default=None,
        alias="avatarPath",
        description="Relative storage path of user profile avatar image.",
    )
    avatar_url: str | None = Field(
        default=None,
        alias="avatarUrl",
        description="Accessible or signed URL to download the profile avatar image.",
    )
    sync_enabled: bool = Field(
        default=False,
        alias="syncEnabled",
        description="Whether encrypted cloud sync is enabled.",
    )
    sync_generation: int = Field(
        default=1,
        ge=1,
        alias="syncGeneration",
        description="Monotonic cloud backup generation counter.",
    )
    quota_remaining_today: int = Field(
        default=15,
        ge=0,
        alias="quotaRemainingToday",
        description="Remaining server-assisted AI analysis quota for today.",
    )


class UpdateUserProfileRequest(BaseModel):
    """Payload for updating mutable profile fields."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    display_name: str | None = Field(
        default=None,
        max_length=64,
        alias="displayName",
        description="Sanitized user display name (max 64 characters, trimmed).",
    )
    sync_enabled: bool | None = Field(
        default=None,
        alias="syncEnabled",
        description="Toggle encrypted cloud report sync.",
    )
    avatar_path: str | None = Field(
        default=None,
        max_length=255,
        alias="avatarPath",
        description="Storage path for user avatar (<userId>/filename).",
    )
    clear_avatar: bool = Field(
        default=False,
        alias="clearAvatar",
        description="Explicitly clear and remove the current avatar reference.",
    )

    @field_validator("display_name")
    @classmethod
    def validate_display_name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v_trimmed = v.strip()
        if not v_trimmed:
            return None
        if len(v_trimmed) > 64:
            raise ValueError("Display name cannot exceed 64 characters.")
        return v_trimmed

    @field_validator("avatar_path")
    @classmethod
    def validate_avatar_path(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v_trimmed = v.strip()
        if not v_trimmed:
            return None
        if len(v_trimmed) > 255:
            raise ValueError("Avatar path cannot exceed 255 characters.")
        if ".." in v_trimmed or "//" in v_trimmed or "\\" in v_trimmed:
            raise ValueError(
                "Invalid avatar path. Directory traversal and redundant separators are not permitted."
            )
        if not re.match(r"^[0-9a-fA-F-]+/[a-zA-Z0-9_\.-]+$", v_trimmed):
            raise ValueError("Invalid avatar path format. Must be <user_id>/<filename>.")
        parts = v_trimmed.split("/", 1)
        if len(parts) == 2:
            filename = parts[1]
            if filename.startswith(".") or not filename:
                raise ValueError("Invalid avatar filename.")
        return v_trimmed

    @model_validator(mode="after")
    def validate_avatar_fields(self) -> "UpdateUserProfileRequest":
        if self.clear_avatar and self.avatar_path is not None:
            raise ValueError("Cannot specify both clearAvatar=True and an avatarPath.")
        return self


class AccountDeletionResponse(BaseModel):
    """Account and server data deletion confirmation."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    status: Literal["deleted"] = Field(
        default="deleted",
        description="Account deletion confirmation status.",
    )
    user_id: str = Field(
        alias="userId",
        description="Deleted user UUID.",
    )
    deleted_at: datetime = Field(
        alias="deletedAt",
        description="Timestamp when account deletion was executed.",
    )
