"""Pydantic schemas for AI-assisted analysis requests, responses, and validation."""

from datetime import datetime
from enum import StrEnum
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator

from trustcue_backend.core.validation import validate_analysis_text


class InputSource(StrEnum):
    """Intake vector for text snapshots."""

    messageText = "messageText"
    screenshot = "screenshot"
    link = "link"
    qrCode = "qrCode"


class IndicatorCategory(StrEnum):
    """Taxonomy category for scam indicators."""

    urgency_or_pressure = "urgency_or_pressure"
    requests_for_credentials = "requests_for_credentials"
    requests_for_verification_codes = "requests_for_verification_codes"
    requests_for_payment = "requests_for_payment"
    account_suspension_or_threats = "account_suspension_or_threats"
    claimed_identity_or_impersonation = "claimed_identity_or_impersonation"
    rewards_or_prizes = "rewards_or_prizes"
    job_or_recruitment_offers = "job_or_recruitment_offers"
    investment_or_return_promises = "investment_or_return_promises"
    link_structural_indicators = "link_structural_indicators"


class FindingSeverity(StrEnum):
    """Relative significance of observed indicator."""

    high = "high"
    medium = "medium"
    low = "low"
    informational = "informational"


class AnalysisAiRequest(BaseModel):
    """Request payload for protected server-assisted AI analysis."""

    model_config = ConfigDict(extra="forbid")

    snapshotId: Annotated[
        str,
        Field(
            min_length=1,
            max_length=128,
            description="Unique client-generated identifier for the snapshot.",
        ),
    ]
    text: Annotated[
        str,
        Field(
            min_length=1,
            description="Exact reviewed and user-approved text.",
        ),
    ]
    source: InputSource
    sourceRevision: Annotated[
        str,
        Field(
            min_length=1,
            max_length=64,
            description="Client revision identifier.",
        ),
    ]
    clientTimestamp: datetime

    @field_validator("text")
    @classmethod
    def validate_text(cls, v: str) -> str:
        """Validate text boundaries, Unicode integrity, and control characters."""
        return validate_analysis_text(v)


class EvidenceReference(BaseModel):
    """Grounding reference pointing to exact UTF-16 code units in user text."""

    model_config = ConfigDict(extra="forbid")

    startOffset: Annotated[int, Field(ge=0, description="Start offset in UTF-16 code units.")]
    endOffset: Annotated[int, Field(gt=0, description="Exclusive end offset in UTF-16 code units.")]
    excerpt: Annotated[str, Field(min_length=1, description="Exact matching substring.")]


class AiFinding(BaseModel):
    """Observed warning indicator produced by server-side analysis."""

    model_config = ConfigDict(extra="forbid")

    id: str
    category: IndicatorCategory
    severity: FindingSeverity
    title: Annotated[str, Field(min_length=1, max_length=128)]
    explanation: Annotated[str, Field(min_length=1)]
    evidenceReferences: list[EvidenceReference]


class SuggestedAction(BaseModel):
    """Actionable protective guidance."""

    model_config = ConfigDict(extra="forbid")

    id: str
    priority: Annotated[str, Field(default="recommended", pattern="^(immediate|recommended|conditional)$")]
    title: Annotated[str, Field(min_length=1, max_length=128)]
    detail: Annotated[str, Field(min_length=1, max_length=512)]


class AnalysisAiResponse(BaseModel):
    """Response returned upon completion of server-assisted AI analysis."""

    model_config = ConfigDict(extra="forbid")

    reportId: Annotated[str, Field(description="Unique server-generated report identifier.")]
    snapshotId: Annotated[str, Field(description="Echoed snapshot identifier matching request.")]
    provider: str
    model: str
    analyzedAt: datetime
    factualSummary: Annotated[str, Field(min_length=1, max_length=512)]
    findings: list[AiFinding]
    uncertaintyNotes: list[str] = Field(default_factory=list)
    suggestedActions: list[SuggestedAction] = Field(default_factory=list)
