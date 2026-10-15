"""Account response schemas conforming to OpenAPI 3.1.0 specifications."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


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
    sync_enabled: bool = Field(
        default=False,
        alias="syncEnabled",
        description="Whether encrypted cloud sync is enabled.",
    )
    quota_remaining_today: int = Field(
        default=15,
        ge=0,
        alias="quotaRemainingToday",
        description="Remaining server-assisted AI analysis quota for today.",
    )


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
