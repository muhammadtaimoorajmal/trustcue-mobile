"""Tests for exact evidence grounding, UTF-16 code-unit offsets, and disambiguation."""

import pytest

from trustcue_backend.api.schemas.analysis import FindingSeverity, IndicatorCategory
from trustcue_backend.providers.models import (
    RawAiFinding,
    RawEvidenceReference,
    RawSuggestedAction,
)
from trustcue_backend.validation.exceptions import (
    AmbiguousQuotationError,
    EvidenceGroundingError,
)
from trustcue_backend.validation.grounding import (
    DEFAULT_NO_FINDINGS_LIMITATION,
    EvidenceGrounder,
    build_utf16_metadata,
    extract_utf16_substring,
)
from trustcue_backend.validation.output_validator import ValidatedRawOutput


def _make_validated_output(
    findings: list[RawAiFinding] | None = None,
    summary: str = "Analysis summary",
) -> ValidatedRawOutput:
    """Helper creating a ValidatedRawOutput structure."""
    return ValidatedRawOutput(
        factual_summary=summary,
        findings=findings or [],
        uncertainty_notes=["Preliminary pattern evaluation."],
        suggested_actions=[
            RawSuggestedAction(
                id="act-1",
                priority="recommended",
                title="Verify directly",
                detail="Use official contact channels.",
            )
        ],
    )


def test_utf16_metadata_ascii_text() -> None:
    """Verify UTF-16 offset mapping for standard ASCII text."""
    text = "Hello world"
    char_map, valid_boundaries, total_u16 = build_utf16_metadata(text)
    assert total_u16 == 11
    assert len(valid_boundaries) == 12
    assert char_map[0] == 0
    assert char_map[5] == 5
    assert extract_utf16_substring(text, 0, 5) == "Hello"


def test_utf16_metadata_with_supplementary_characters() -> None:
    """
    Verify UTF-16 offset mapping with supplementary characters (emojis).

    Emoji 🛡 (U+1F6E1) requires 2 UTF-16 code units (surrogate pair: 0xD83D 0xDEE1).
    Python len(emoji) == 1, but Dart String.length == 2.
    """
    shield_emoji = "\U0001F6E1"  # 🛡
    text = f"Security {shield_emoji} alert"
    # "Security " is 9 chars -> 9 code units
    # shield_emoji is 1 char -> 2 code units
    # " alert" is 6 chars -> 6 code units
    # Total chars in Python: 9 + 1 + 6 = 16
    # Total code units in Dart/UTF-16: 9 + 2 + 6 = 17
    char_map, valid_boundaries, total_u16 = build_utf16_metadata(text)
    assert len(text) == 16
    assert total_u16 == 17

    # Offset 10 falls in the middle of the surrogate pair (9 is lead surrogate, 10 is trail)
    assert 9 in valid_boundaries
    assert 10 not in valid_boundaries  # Splitting surrogate!
    assert 11 in valid_boundaries

    # Extracting substring after the emoji
    extracted = extract_utf16_substring(text, 11, 17)
    assert extracted == " alert"


def test_valid_grounding_computes_exact_utf16_offsets() -> None:
    """Verify unambiguous evidence quotation computes correct UTF-16 code units."""
    text = "Important: Send your password immediately to secure your funds."
    excerpt = "Send your password immediately"
    finding = RawAiFinding(
        id="raw-1",
        category=IndicatorCategory.requests_for_credentials,
        severity=FindingSeverity.high,
        title="Password request",
        explanation="Requesting password submission.",
        evidence_references=[RawEvidenceReference(excerpt=excerpt)],
    )

    output = _make_validated_output(findings=[finding])
    report = EvidenceGrounder.ground_and_build_report(
        validated_output=output,
        submitted_text=text,
        snapshot_id="snap-trusted-01",
        provider="groq-cloud",
        model="llama-3.3-70b-versatile",
    )

    assert report.snapshotId == "snap-trusted-01"
    assert report.reportId.startswith("rep-")
    assert len(report.findings) == 1

    ev = report.findings[0].evidenceReferences[0]
    assert ev.excerpt == excerpt
    assert ev.startOffset == 11
    assert ev.endOffset == 11 + len(excerpt)
    assert text[ev.startOffset : ev.endOffset] == excerpt


def test_nonexistent_quotation_raises_grounding_error() -> None:
    """Verify fabricated quotation not found in text raises EvidenceGroundingError."""
    text = "Your package is ready for pickup at our local depot."
    finding = RawAiFinding(
        id="raw-1",
        category=IndicatorCategory.urgency_or_pressure,
        severity=FindingSeverity.high,
        title="Fake urgency",
        explanation="Urgent action required.",
        evidence_references=[RawEvidenceReference(excerpt="Act within 24 hours or account closed")],
    )

    output = _make_validated_output(findings=[finding])
    with pytest.raises(EvidenceGroundingError, match="does not exist in submitted text"):
        EvidenceGrounder.ground_and_build_report(
            validated_output=output,
            submitted_text=text,
            snapshot_id="snap-1",
            provider="groq",
            model="test",
        )


def test_case_sensitive_mismatch_raises_grounding_error() -> None:
    """Verify that case differences are not silently ignored (exact match required)."""
    text = "Contact your Bank directly."
    finding = RawAiFinding(
        id="raw-1",
        category=IndicatorCategory.claimed_identity_or_impersonation,
        severity=FindingSeverity.medium,
        title="Bank identity",
        explanation="Claims bank identity.",
        evidence_references=[RawEvidenceReference(excerpt="Contact your bank directly.")],  # lowercase bank
    )

    output = _make_validated_output(findings=[finding])
    with pytest.raises(EvidenceGroundingError, match="does not exist in submitted text"):
        EvidenceGrounder.ground_and_build_report(
            validated_output=output,
            submitted_text=text,
            snapshot_id="snap-1",
            provider="groq",
            model="test",
        )


def test_whitespace_and_newline_preservation() -> None:
    """Verify that tabs, line breaks, and spacing must match exactly."""
    text = "First alert\n\tCritical action required: send code"
    finding = RawAiFinding(
        id="raw-1",
        category=IndicatorCategory.requests_for_verification_codes,
        severity=FindingSeverity.high,
        title="Code request",
        explanation="Asks for verification code.",
        evidence_references=[RawEvidenceReference(excerpt="Critical action required: send code")],
    )

    output = _make_validated_output(findings=[finding])
    report = EvidenceGrounder.ground_and_build_report(
        validated_output=output,
        submitted_text=text,
        snapshot_id="snap-1",
        provider="groq",
        model="test",
    )
    ev = report.findings[0].evidenceReferences[0]
    assert extract_utf16_substring(text, ev.startOffset, ev.endOffset) == "Critical action required: send code"


def test_unicode_normalization_mismatch_rejected() -> None:
    """Verify that Unicode normalization differences (NFC vs NFD) are not conflated."""
    # 'é' as single code point U+00E9 (NFC)
    text_nfc = "Caf\u00e9 security alert"
    # 'é' as 'e' + combining acute U+0301 (NFD)
    excerpt_nfd = "Caf\u0065\u0301"

    finding = RawAiFinding(
        id="raw-1",
        category=IndicatorCategory.urgency_or_pressure,
        severity=FindingSeverity.low,
        title="Cafe alert",
        explanation="Test explanation.",
        evidence_references=[RawEvidenceReference(excerpt=excerpt_nfd)],
    )

    output = _make_validated_output(findings=[finding])
    with pytest.raises(EvidenceGroundingError, match="does not exist in submitted text"):
        EvidenceGrounder.ground_and_build_report(
            validated_output=output,
            submitted_text=text_nfc,
            snapshot_id="snap-1",
            provider="groq",
            model="test",
        )


def test_urdu_script_grounding() -> None:
    """Verify exact evidence grounding in right-to-left complex scripts (Urdu)."""
    text = "برائے مہربانی فوری طور پر اپنا پاس ورڈ درج کریں تاکہ اکاؤنٹ محفوظ رہے۔"
    excerpt = "اپنا پاس ورڈ درج کریں"

    finding = RawAiFinding(
        id="raw-1",
        category=IndicatorCategory.requests_for_credentials,
        severity=FindingSeverity.high,
        title="Urdu credential request",
        explanation="Urdu message requests password entry.",
        evidence_references=[RawEvidenceReference(excerpt=excerpt)],
    )

    output = _make_validated_output(findings=[finding])
    report = EvidenceGrounder.ground_and_build_report(
        validated_output=output,
        submitted_text=text,
        snapshot_id="snap-urdu",
        provider="groq",
        model="test",
    )

    ev = report.findings[0].evidenceReferences[0]
    assert ev.excerpt == excerpt
    assert extract_utf16_substring(text, ev.startOffset, ev.endOffset) == excerpt


def test_repeated_quotations_without_offsets_raises_ambiguous_error() -> None:
    """Verify repeated identical quotations without offsets cause AmbiguousQuotationError."""
    text = "call 555-0199 immediately. I repeat, call 555-0199 immediately."
    excerpt = "call 555-0199 immediately."

    finding = RawAiFinding(
        id="raw-1",
        category=IndicatorCategory.urgency_or_pressure,
        severity=FindingSeverity.medium,
        title="Repeated call prompt",
        explanation="Urges phone call.",
        evidence_references=[
            RawEvidenceReference(excerpt=excerpt, start_offset=None, end_offset=None)
        ],
    )

    output = _make_validated_output(findings=[finding])
    with pytest.raises(AmbiguousQuotationError, match="occurs 2 times and lacks offsets"):
        EvidenceGrounder.ground_and_build_report(
            validated_output=output,
            submitted_text=text,
            snapshot_id="snap-1",
            provider="groq",
            model="test",
        )


def test_repeated_quotations_with_valid_offsets_disambiguates_correctly() -> None:
    """Verify repeated identical quotation with valid offsets grounds to the intended occurrence."""
    text = "call 555-0199 now. If urgent, call 555-0199 now."
    excerpt = "call 555-0199 now."
    first_start = text.find(excerpt)
    second_start = text.find(excerpt, first_start + 1)
    second_end = second_start + len(excerpt)

    finding = RawAiFinding(
        id="raw-1",
        category=IndicatorCategory.urgency_or_pressure,
        severity=FindingSeverity.medium,
        title="Disambiguated call prompt",
        explanation="Urges call at second occurrence.",
        evidence_references=[
            RawEvidenceReference(
                excerpt=excerpt,
                start_offset=second_start,
                end_offset=second_end,
            )
        ],
    )

    output = _make_validated_output(findings=[finding])
    report = EvidenceGrounder.ground_and_build_report(
        validated_output=output,
        submitted_text=text,
        snapshot_id="snap-1",
        provider="groq",
        model="test",
    )

    ev = report.findings[0].evidenceReferences[0]
    assert ev.startOffset == second_start
    assert ev.endOffset == second_end
    assert extract_utf16_substring(text, ev.startOffset, ev.endOffset) == excerpt


def test_empty_findings_injects_honest_limitations() -> None:
    """Verify empty findings list automatically receives the honest limitation statement."""
    text = "Your standard grocery order has been confirmed."
    output = _make_validated_output(findings=[], summary="No scam indicators found.")

    report = EvidenceGrounder.ground_and_build_report(
        validated_output=output,
        submitted_text=text,
        snapshot_id="snap-empty",
        provider="groq",
        model="llama-3.3-70b-versatile",
    )

    assert len(report.findings) == 0
    assert any("does not establish that the communication is safe" in note for note in report.uncertaintyNotes)
    assert report.uncertaintyNotes[0] == DEFAULT_NO_FINDINGS_LIMITATION
