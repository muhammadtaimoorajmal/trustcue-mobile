"""Privacy-safe typed exceptions for AI output validation and evidence grounding."""

from trustcue_backend.core.errors import TrustCueError


class OutputValidationError(TrustCueError):
    """
    Raised when provider output violates strict JSON shape, field bounds, or semantic policies.

    Invariants:
    1. Returns HTTP 502 (Bad Gateway), indicating upstream untrusted data was rejected.
    2. Never exposes user prompt text, reviewed message content, or raw upstream secrets in the error envelope.
    """

    def __init__(self, message: str, code: str = "ai_output_validation_failed") -> None:
        super().__init__(
            code=code,
            message=message,
            status_code=502,
        )


class EvidenceGroundingError(TrustCueError):
    """
    Raised when an AI finding quotation cannot be strictly grounded in the submitted text snapshot.

    Invariants:
    1. Returns HTTP 502 (Bad Gateway).
    2. Never exposes sensitive message excerpts or user text in public logs or client responses.
    """

    def __init__(self, message: str, code: str = "ai_evidence_grounding_failed") -> None:
        super().__init__(
            code=code,
            message=message,
            status_code=502,
        )


class AmbiguousQuotationError(EvidenceGroundingError):
    """
    Raised when an evidence quotation occurs multiple times in the snapshot and cannot be
    unambiguously resolved with verified offsets.
    """

    def __init__(self, message: str = "Evidence quotation occurs multiple times and cannot be unambiguously grounded.") -> None:
        super().__init__(
            message=message,
            code="ai_ambiguous_quotation",
        )
