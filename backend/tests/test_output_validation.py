"""Tests for strict untrusted-output validation of AI provider completions."""

import json

import pytest

from trustcue_backend.validation.exceptions import OutputValidationError
from trustcue_backend.validation.output_validator import OutputValidator


def _valid_completion_dict() -> dict:
    """Helper returning a standard, valid completion dictionary."""
    return {
        "factualSummary": "Observed urgent credential solicitation patterns.",
        "findings": [
            {
                "id": "finding-1",
                "category": "requests_for_credentials",
                "severity": "high",
                "title": "Account password request",
                "explanation": "Message requests password submission via unverified channels.",
                "evidenceReferences": [
                    {
                        "excerpt": "enter your password here",
                        "startOffset": 10,
                        "endOffset": 34,
                    }
                ],
            }
        ],
        "uncertaintyNotes": [
            "Sender identity cannot be conclusively established from text alone.",
        ],
        "suggestedActions": [
            {
                "id": "act-1",
                "priority": "immediate",
                "title": "Do not share passwords",
                "detail": "Legitimate services do not ask for your password via messaging.",
            }
        ],
    }


def test_valid_structured_completion() -> None:
    """Verify standard compliant completion passes validation."""
    data = _valid_completion_dict()
    validated = OutputValidator.parse_and_validate(json.dumps(data))
    assert validated.factual_summary == "Observed urgent credential solicitation patterns."
    assert len(validated.findings) == 1
    assert validated.findings[0].category == "requests_for_credentials"
    assert validated.findings[0].severity == "high"
    assert len(validated.findings[0].evidence_references) == 1
    assert validated.findings[0].evidence_references[0].excerpt == "enter your password here"
    assert len(validated.uncertainty_notes) == 1
    assert len(validated.suggested_actions) == 1


def test_empty_completion_raises() -> None:
    """Verify empty or whitespace-only completion raises OutputValidationError."""
    with pytest.raises(OutputValidationError, match="empty completion content"):
        OutputValidator.parse_and_validate("")

    with pytest.raises(OutputValidationError, match="empty completion content"):
        OutputValidator.parse_and_validate("   \n\t  ")


def test_malformed_json_raises() -> None:
    """Verify non-JSON or broken JSON raises OutputValidationError."""
    with pytest.raises(OutputValidationError, match="Malformed JSON"):
        OutputValidator.parse_and_validate("This is not JSON at all.")

    with pytest.raises(OutputValidationError, match="Malformed JSON"):
        OutputValidator.parse_and_validate('{"factualSummary": "Unclosed string')


def test_duplicate_json_keys_rejected() -> None:
    """Verify duplicate JSON keys are detected and strictly rejected."""
    raw_json = (
        '{"factualSummary": "Summary 1", "factualSummary": "Summary 2", '
        '"findings": [], "uncertaintyNotes": [], "suggestedActions": []}'
    )
    with pytest.raises(OutputValidationError, match="Duplicate JSON key"):
        OutputValidator.parse_and_validate(raw_json)


def test_special_numeric_constants_rejected() -> None:
    """Verify NaN and Infinity numeric constants are strictly rejected."""
    raw_nan = '{"factualSummary": "Summary", "findings": [], "uncertaintyNotes": [], "suggestedActions": [], "val": NaN}'
    with pytest.raises(OutputValidationError, match="Invalid numeric constant"):
        OutputValidator.parse_and_validate(raw_nan)

    raw_inf = '{"factualSummary": "Summary", "findings": [], "uncertaintyNotes": [], "suggestedActions": [], "val": Infinity}'
    with pytest.raises(OutputValidationError, match="Invalid numeric constant"):
        OutputValidator.parse_and_validate(raw_inf)


def test_non_object_root_rejected() -> None:
    """Verify arrays or primitives at JSON root are rejected."""
    with pytest.raises(OutputValidationError, match="must be a JSON object"):
        OutputValidator.parse_and_validate('[{"findings": []}]')

    with pytest.raises(OutputValidationError, match="must be a JSON object"):
        OutputValidator.parse_and_validate('"just a string"')


def test_unexpected_top_level_field_rejected() -> None:
    """Verify unallowed extra fields in top-level object are rejected."""
    data = _valid_completion_dict()
    data["unauthorized_field"] = "malicious payload"
    with pytest.raises(OutputValidationError, match="Unexpected top-level field"):
        OutputValidator.parse_and_validate(json.dumps(data))


def test_missing_required_factual_summary() -> None:
    """Verify missing factualSummary is rejected."""
    data = _valid_completion_dict()
    del data["factualSummary"]
    with pytest.raises(OutputValidationError, match="Missing or empty 'factualSummary'"):
        OutputValidator.parse_and_validate(json.dumps(data))


def test_excessive_findings_count_rejected() -> None:
    """Verify findings count exceeding upper bound (20) is rejected."""
    data = _valid_completion_dict()
    single_finding = data["findings"][0]
    data["findings"] = [dict(single_finding, id=f"f-{i}") for i in range(25)]
    with pytest.raises(OutputValidationError, match="Findings count exceeds maximum allowable limit"):
        OutputValidator.parse_and_validate(json.dumps(data))


def test_unknown_indicator_category_rejected() -> None:
    """Verify indicator category outside canonical taxonomy is rejected."""
    data = _valid_completion_dict()
    data["findings"][0]["category"] = "unsupported_crypto_phishing"
    with pytest.raises(OutputValidationError, match="unknown category"):
        OutputValidator.parse_and_validate(json.dumps(data))


def test_unknown_severity_rejected() -> None:
    """Verify invalid severity value is rejected."""
    data = _valid_completion_dict()
    data["findings"][0]["severity"] = "critical_emergency"
    with pytest.raises(OutputValidationError, match="unknown severity"):
        OutputValidator.parse_and_validate(json.dumps(data))


def test_unexpected_finding_field_rejected() -> None:
    """Verify unauthorized extra field in finding item is rejected."""
    data = _valid_completion_dict()
    data["findings"][0]["extraScore"] = 0.99
    with pytest.raises(OutputValidationError, match="Unexpected field in finding"):
        OutputValidator.parse_and_validate(json.dumps(data))


def test_finding_without_evidence_rejected() -> None:
    """Verify finding with empty evidence references list is rejected."""
    data = _valid_completion_dict()
    data["findings"][0]["evidenceReferences"] = []
    with pytest.raises(OutputValidationError, match="must contain at least one evidence reference"):
        OutputValidator.parse_and_validate(json.dumps(data))


def test_prohibited_risk_percentages_rejected() -> None:
    """Verify fraud probability or risk percentages in text cause rejection."""
    data = _valid_completion_dict()
    data["factualSummary"] = "This message has a 95% scam probability."
    with pytest.raises(OutputValidationError, match="Prohibited semantic claim"):
        OutputValidator.parse_and_validate(json.dumps(data))

    data2 = _valid_completion_dict()
    data2["findings"][0]["explanation"] = "Identified pattern indicates fraud score: 85."
    with pytest.raises(OutputValidationError, match="Prohibited semantic claim"):
        OutputValidator.parse_and_validate(json.dumps(data2))


def test_prohibited_safety_guarantees_rejected() -> None:
    """Verify guaranteed safety or definitive claims cause rejection."""
    data = _valid_completion_dict()
    data["factualSummary"] = "The sender is verified safe and this message is 100% safe."
    with pytest.raises(OutputValidationError, match="Prohibited semantic claim"):
        OutputValidator.parse_and_validate(json.dumps(data))


def test_prohibited_executable_markup_rejected() -> None:
    """Verify script tags or javascript URIs in output cause rejection."""
    data = _valid_completion_dict()
    data["suggestedActions"][0]["detail"] = "<script>alert('xss')</script> Verify in app."
    with pytest.raises(OutputValidationError, match="Prohibited executable markup"):
        OutputValidator.parse_and_validate(json.dumps(data))

    data2 = _valid_completion_dict()
    data2["findings"][0]["title"] = "Check javascript:void(0)"
    with pytest.raises(OutputValidationError, match="Prohibited executable markup"):
        OutputValidator.parse_and_validate(json.dumps(data2))


def test_provider_refusal_handled() -> None:
    """Verify refusal envelope from provider raises typed rejection."""
    refusal_payload = {
        "refusal": "I cannot analyze this message.",
    }
    with pytest.raises(OutputValidationError, match="AI provider refused request"):
        OutputValidator.parse_and_validate(json.dumps(refusal_payload))
