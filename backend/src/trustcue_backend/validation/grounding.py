"""Exact evidence grounding and trusted report synthesis for AI provider completions."""

from datetime import UTC, datetime
from uuid import uuid4

from trustcue_backend.api.schemas.analysis import (
    AiFinding,
    AnalysisAiResponse,
    EvidenceReference,
    SuggestedAction,
)
from trustcue_backend.validation.exceptions import (
    AmbiguousQuotationError,
    EvidenceGroundingError,
)
from trustcue_backend.validation.output_validator import ValidatedRawOutput

DEFAULT_NO_FINDINGS_LIMITATION = (
    "No scam warning indicators were detected in the evaluated text snapshot. "
    "This does not establish that the communication is safe, authentic, or risk-free."
)

DEFAULT_ANALYSIS_LIMITATION = (
    "AI evaluation identifies potential conversational risk patterns; "
    "it does not guarantee safety, verify sender identity, or determine objective fraud."
)


def build_utf16_metadata(text: str) -> tuple[list[int], set[int], int]:
    """
    Compute UTF-16 code-unit offsets for each Python character in text.

    Returns:
        char_to_utf16: List of length len(text)+1 mapping char index to starting UTF-16 offset.
        valid_boundaries: Set of valid UTF-16 code-unit offsets that do not split surrogate pairs.
        total_utf16_units: Total length in UTF-16 code units (matching Dart String.length).
    """
    char_to_utf16 = [0] * (len(text) + 1)
    valid_boundaries: set[int] = set()
    utf16_pos = 0

    for i, ch in enumerate(text):
        char_to_utf16[i] = utf16_pos
        valid_boundaries.add(utf16_pos)
        utf16_pos += 2 if ord(ch) > 0xFFFF else 1

    char_to_utf16[len(text)] = utf16_pos
    valid_boundaries.add(utf16_pos)
    return char_to_utf16, valid_boundaries, utf16_pos


def extract_utf16_substring(text: str, start_u16: int, end_u16: int) -> str:
    """Extract substring from text using UTF-16 code-unit offsets."""
    encoded = text.encode("utf-16-le")
    byte_start = start_u16 * 2
    byte_end = end_u16 * 2
    slice_bytes = encoded[byte_start:byte_end]
    return slice_bytes.decode("utf-16-le")


def find_all_substring_char_spans(text: str, sub: str) -> list[tuple[int, int]]:
    """Find all start/end character index pairs for substring in text."""
    if not sub:
        return []
    spans: list[tuple[int, int]] = []
    start = 0
    while True:
        idx = text.find(sub, start)
        if idx == -1:
            break
        spans.append((idx, idx + len(sub)))
        start = idx + 1
    return spans


class EvidenceGrounder:
    """
    Validates that every AI finding quotation is strictly grounded in the submitted text snapshot.

    Invariants:
    1. Preserves submitted text exactly without trimming, case-folding, or normalization.
    2. Enforces exact substring equality.
    3. Offsets match Dart UTF-16 code units without splitting surrogate pairs.
    4. Deterministic disambiguation: repeated quotations require valid offsets; otherwise rejected.
    5. Binds evidence to trusted request snapshotId; model-supplied snapshot IDs are discarded.
    6. Generates authoritative server report and finding UUIDs.
    """

    @classmethod
    def ground_and_build_report(
        cls,
        validated_output: ValidatedRawOutput,
        submitted_text: str,
        snapshot_id: str,
        provider: str,
        model: str,
        analyzed_at: datetime | None = None,
    ) -> AnalysisAiResponse:
        """
        Ground all findings against the exact submitted text and produce trusted AnalysisAiResponse.

        Raises EvidenceGroundingError or AmbiguousQuotationError if grounding fails.
        """
        # Exact text preservation: do NOT strip, lower, or normalize
        char_to_utf16, valid_boundaries, total_utf16_units = build_utf16_metadata(submitted_text)

        grounded_findings: list[AiFinding] = []

        for finding_idx, raw_finding in enumerate(validated_output.findings):
            grounded_refs: list[EvidenceReference] = []

            for _ref_idx, raw_ref in enumerate(raw_finding.evidence_references):
                excerpt = raw_ref.excerpt
                spans = find_all_substring_char_spans(submitted_text, excerpt)

                if len(spans) == 0:
                    raise EvidenceGroundingError(
                        f"Evidence quotation in finding[{finding_idx}] does not exist in submitted text."
                    )

                if len(spans) == 1:
                    # Single unambiguous occurrence
                    char_start, char_end = spans[0]
                    u16_start = char_to_utf16[char_start]
                    u16_end = char_to_utf16[char_end]

                    # If model provided offsets, verify whether they conflict
                    if raw_ref.start_offset is not None or raw_ref.end_offset is not None:
                        m_start = raw_ref.start_offset
                        m_end = raw_ref.end_offset
                        if m_start != u16_start or m_end != u16_end:
                            # Model supplied offsets do not match the unique occurrence
                            # Verify if model offsets point to the valid excerpt anyway (e.g. if model used another offset)
                            if (
                                m_start is not None
                                and m_end is not None
                                and 0 <= m_start < m_end <= total_utf16_units
                                and m_start in valid_boundaries
                                and m_end in valid_boundaries
                            ):
                                extracted = extract_utf16_substring(submitted_text, m_start, m_end)
                                if extracted == excerpt:
                                    u16_start, u16_end = m_start, m_end
                                else:
                                    raise EvidenceGroundingError(
                                        f"Finding[{finding_idx}] model offsets [{m_start}, {m_end}) do not match quotation."
                                    )
                            else:
                                # Model provided invalid offsets for unique occurrence
                                raise EvidenceGroundingError(
                                    f"Finding[{finding_idx}] model-supplied offsets [{m_start}, {m_end}) are invalid or split surrogate."
                                )

                else:
                    # Repeated ambiguous occurrence
                    m_start = raw_ref.start_offset
                    m_end = raw_ref.end_offset

                    if m_start is None or m_end is None:
                        raise AmbiguousQuotationError(
                            f"Quotation in finding[{finding_idx}] occurs {len(spans)} times and lacks offsets for disambiguation."
                        )

                    # Validate model-provided offsets against bounds and surrogate integrity
                    if (
                        m_start < 0
                        or m_end <= m_start
                        or m_end > total_utf16_units
                        or m_start not in valid_boundaries
                        or m_end not in valid_boundaries
                    ):
                        raise EvidenceGroundingError(
                            f"Finding[{finding_idx}] disambiguation offsets [{m_start}, {m_end}) are out of range or split a surrogate pair."
                        )

                    extracted = extract_utf16_substring(submitted_text, m_start, m_end)
                    if extracted != excerpt:
                        raise EvidenceGroundingError(
                            f"Finding[{finding_idx}] text at offsets [{m_start}, {m_end}) does not match quotation."
                        )

                    u16_start, u16_end = m_start, m_end

                grounded_refs.append(
                    EvidenceReference(
                        startOffset=u16_start,
                        endOffset=u16_end,
                        excerpt=excerpt,
                    )
                )

            # Generate authoritative server finding ID
            finding_id = f"finding-{uuid4()}"
            grounded_findings.append(
                AiFinding(
                    id=finding_id,
                    category=raw_finding.category,
                    severity=raw_finding.severity,
                    title=raw_finding.title,
                    explanation=raw_finding.explanation,
                    evidenceReferences=grounded_refs,
                )
            )

        # Assemble uncertainty notes with honest limitations
        uncertainty_notes = list(validated_output.uncertainty_notes)
        if len(grounded_findings) == 0:
            if DEFAULT_NO_FINDINGS_LIMITATION not in uncertainty_notes:
                uncertainty_notes.insert(0, DEFAULT_NO_FINDINGS_LIMITATION)
        else:
            if DEFAULT_ANALYSIS_LIMITATION not in uncertainty_notes:
                uncertainty_notes.append(DEFAULT_ANALYSIS_LIMITATION)

        # Assemble suggested actions
        suggested_actions: list[SuggestedAction] = []
        for raw_action in validated_output.suggested_actions:
            action_id = f"action-{uuid4().hex[:8]}"
            suggested_actions.append(
                SuggestedAction(
                    id=action_id,
                    priority=raw_action.priority,
                    title=raw_action.title,
                    detail=raw_action.detail,
                )
            )

        report_id = f"rep-{uuid4()}"
        report_timestamp = analyzed_at or datetime.now(UTC)

        return AnalysisAiResponse(
            reportId=report_id,
            snapshotId=snapshot_id,  # Authoritative request snapshot ID
            provider=provider,
            model=model,
            analyzedAt=report_timestamp,
            factualSummary=validated_output.factual_summary,
            findings=grounded_findings,
            uncertaintyNotes=uncertainty_notes,
            suggestedActions=suggested_actions,
        )
