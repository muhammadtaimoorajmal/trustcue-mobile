"""Internal domain models for AI provider requests and responses."""

from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

from trustcue_backend.api.schemas.analysis import FindingSeverity, IndicatorCategory


class RawEvidenceReference(BaseModel):
    """Raw evidence reference extracted by the AI provider."""

    model_config = ConfigDict(extra="ignore")

    excerpt: Annotated[str, Field(min_length=1, description="Quoted substring from the evaluated text.")]
    start_offset: int | None = Field(default=None, description="Model-reported start offset (untrusted until grounded).")
    end_offset: int | None = Field(default=None, description="Model-reported end offset (untrusted until grounded).")


class RawAiFinding(BaseModel):
    """Raw scam-indicator finding extracted by the AI provider before server grounding."""

    model_config = ConfigDict(extra="ignore")

    id: str = Field(description="Temporary model-assigned finding ID.")
    category: IndicatorCategory
    severity: FindingSeverity
    title: str = Field(min_length=1, max_length=128)
    explanation: str = Field(min_length=1, max_length=1024)
    evidence_references: list[RawEvidenceReference] = Field(default_factory=list)


class RawSuggestedAction(BaseModel):
    """Raw safe action suggested by the AI provider."""

    model_config = ConfigDict(extra="ignore")

    id: str
    priority: str = Field(pattern="^(immediate|recommended|conditional)$")
    title: str = Field(min_length=1, max_length=128)
    detail: str = Field(min_length=1, max_length=512)


class ProviderAnalysisRequest(BaseModel):
    """Bounded, internal request payload sent to the provider adapter."""

    model_config = ConfigDict(extra="forbid")

    snapshot_id: str
    text: str
    request_id: str


class ProviderAnalysisResult(BaseModel):
    """
    Internal structured result returned by the provider adapter.

    Contains raw model observations. Kept strictly separate from the client-facing
    AnalysisAiResponse until Module 34 evidence grounding verification.
    """

    model_config = ConfigDict(extra="ignore")

    provider: str
    model: str
    factual_summary: str = Field(min_length=1, max_length=512)
    findings: list[RawAiFinding] = Field(default_factory=list)
    uncertainty_notes: list[str] = Field(default_factory=list)
    suggested_actions: list[RawSuggestedAction] = Field(default_factory=list)
    raw_usage: dict[str, int] | None = None
