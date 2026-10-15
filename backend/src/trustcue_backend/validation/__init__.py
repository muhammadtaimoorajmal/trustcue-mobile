"""AI output validation and evidence grounding package."""

from trustcue_backend.validation.exceptions import (
    AmbiguousQuotationError,
    EvidenceGroundingError,
    OutputValidationError,
)
from trustcue_backend.validation.grounding import (
    EvidenceGrounder,
    build_utf16_metadata,
    extract_utf16_substring,
)
from trustcue_backend.validation.output_validator import (
    OutputValidator,
    ValidatedRawOutput,
)

__all__ = [
    "OutputValidationError",
    "EvidenceGroundingError",
    "AmbiguousQuotationError",
    "OutputValidator",
    "ValidatedRawOutput",
    "EvidenceGrounder",
    "build_utf16_metadata",
    "extract_utf16_substring",
]
