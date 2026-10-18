"""Account response schemas conforming to OpenAPI 3.1.0 specifications."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


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
