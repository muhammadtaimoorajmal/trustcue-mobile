"""Schemas for Module 39 Optional Cloud Report Synchronization."""

import json
from datetime import UTC, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

FORBIDDEN_PAYLOAD_KEYS = {
    "text",
    "rawtext",
    "raw_text",
    "excerpt",
    "evidence",
    "screenshot",
    "hash",
    "ocrtext",
    "ocr_text",
    "inputtext",
    "input_text",
}


def check_privacy_keys(obj: Any) -> None:
    """Recursively verify that no forbidden raw text or excerpt keys exist."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            norm_k = str(k).strip().lower().replace("-", "").replace("_", "")
            if norm_k in FORBIDDEN_PAYLOAD_KEYS:
                raise ValueError(
                    f"Forbidden content key '{k}' found in report summary payload. "
                    "Cloud sync is strictly restricted to non-sensitive summaries."
                )
            check_privacy_keys(v)
    elif isinstance(obj, list):
        for item in obj:
            check_privacy_keys(item)


class SyncedReportItem(BaseModel):
    """Client-submitted sync item."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    client_report_id: str = Field(
        alias="clientReportId",
        min_length=1,
        max_length=128,
        description="Client-generated unique report UUID/ID.",
    )
    snapshot_id: str = Field(
        alias="snapshotId",
        min_length=1,
        max_length=128,
        description="Client-generated snapshot identifier.",
    )
    schema_version: int = Field(
        default=1,
        ge=1,
        alias="schemaVersion",
        description="Version of report summary schema.",
    )
    report_payload: dict[str, Any] = Field(
        alias="reportPayload",
        description="Structured non-sensitive summary payload (outcomeState, categories, timestamps).",
    )
    is_deleted: bool = Field(
        default=False,
        alias="isDeleted",
        description="Tombstone flag indicating deletion from cloud backup.",
    )
    deleted_at: datetime | None = Field(
        default=None,
        alias="deletedAt",
        description="UTC timestamp when deleted (required if isDeleted=True).",
    )
    client_updated_at: datetime = Field(
        alias="clientUpdatedAt",
        description="Device timestamp when report was modified or tombstoned.",
    )

    @field_validator("report_payload")
    @classmethod
    def validate_payload_privacy_and_bounds(cls, v: dict[str, Any]) -> dict[str, Any]:
        """Enforce strict size limits and verify zero raw content fields."""
        try:
            serialized = json.dumps(v, ensure_ascii=False)
        except Exception as exc:
            raise ValueError(f"Report payload cannot be serialized to JSON: {exc}") from exc

        if len(serialized.encode("utf-8")) > 500_000:
            raise ValueError("Report payload exceeds maximum allowed size (500 KB).")

        check_privacy_keys(v)
        return v

    @model_validator(mode="after")
    def validate_tombstone_consistency(self) -> "SyncedReportItem":
        """Verify tombstone flag and deletedAt consistency."""
        if self.is_deleted:
            if self.deleted_at is None:
                self.deleted_at = datetime.now(UTC)
        else:
            if self.deleted_at is not None:
                raise ValueError("deletedAt must be null when isDeleted is false.")
        return self


class SyncReportsPushRequest(BaseModel):
    """Batch upload of client reports to cloud sync."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    reports: list[SyncedReportItem] = Field(
        max_length=50,
        description="List of report items to synchronize (max 50 per batch).",
    )


class SyncReportsPushResponse(BaseModel):
    """Response confirming batch synchronization ingestion."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    accepted_count: int = Field(alias="acceptedCount")
    synced_report_ids: list[str] = Field(alias="syncedReportIds")
    server_timestamp: datetime = Field(alias="serverTimestamp")


class SyncedReportRecord(BaseModel):
    """Full synced report record stored in cloud and returned to client."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    id: str = Field(description="Server record UUID.")
    client_report_id: str = Field(alias="clientReportId")
    snapshot_id: str = Field(alias="snapshotId")
    schema_version: int = Field(alias="schemaVersion")
    revision: int = Field(description="Monotonic revision counter.")
    report_payload: dict[str, Any] = Field(alias="reportPayload")
    is_deleted: bool = Field(alias="isDeleted")
    deleted_at: datetime | None = Field(default=None, alias="deletedAt")
    client_updated_at: datetime = Field(alias="clientUpdatedAt")
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime = Field(alias="updatedAt")


class SyncReportsPullResponse(BaseModel):
    """Response returned when downloading report updates."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    reports: list[SyncedReportRecord]
    next_cursor: str | None = Field(default=None, alias="nextCursor")
    has_more: bool = Field(default=False, alias="hasMore")
    server_timestamp: datetime = Field(alias="serverTimestamp")


class SyncPurgeResponse(BaseModel):
    """Response returned after purging cloud synced reports."""

    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    purged_count: int = Field(alias="purgedCount")
    message: str
    server_timestamp: datetime = Field(alias="serverTimestamp")
