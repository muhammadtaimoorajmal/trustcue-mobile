"""Strict untrusted-output validation layer for server-assisted AI completions."""

import json
import re
from typing import Any

from trustcue_backend.api.schemas.analysis import FindingSeverity, IndicatorCategory
from trustcue_backend.providers.models import (
    RawAiFinding,
    RawEvidenceReference,
    RawSuggestedAction,
)
from trustcue_backend.validation.exceptions import OutputValidationError

MAX_FINDINGS_COUNT = 20
MAX_EVIDENCE_PER_FINDING = 5
MAX_UNCERTAINTY_NOTES_COUNT = 10
MAX_SUGGESTED_ACTIONS_COUNT = 10

MAX_SUMMARY_LENGTH = 512
MAX_TITLE_LENGTH = 128
MAX_EXPLANATION_LENGTH = 1024
MAX_EXCERPT_LENGTH = 1024
MAX_NOTE_LENGTH = 256
MAX_ACTION_DETAIL_LENGTH = 512

ALLOWED_TOP_LEVEL_KEYS = {
    "factualSummary",
    "factual_summary",
    "findings",
    "uncertaintyNotes",
    "uncertainty_notes",
    "suggestedActions",
    "suggested_actions",
}

ALLOWED_FINDING_KEYS = {
    "id",
    "category",
    "severity",
    "title",
    "explanation",
    "evidenceReferences",
    "evidence_references",
}

ALLOWED_EVIDENCE_KEYS = {
    "excerpt",
    "startOffset",
    "endOffset",
    "start_offset",
    "end_offset",
}

ALLOWED_ACTION_KEYS = {
    "id",
    "priority",
    "title",
    "detail",
    "description",
}

# Semantic safety patterns prohibiting dangerous or false assertions
PROHIBITED_SEMANTIC_PATTERNS = [
    # Risk percentages or fraud scores
    re.compile(r"(?i)\b\d{1,3}(?:\.\d+)?%\s*(?:scam|fraud|risk|safe|authentic|probability|confidence)\b"),
    re.compile(r"(?i)\b(?:scam|fraud|risk|confidence)\s*(?:score|percentage|probability|rate)\s*:\s*\d+"),
    # Absolute safety claims
    re.compile(r"(?i)\b(?:guaranteed safe|100% safe|definitely safe|verified safe|verified authentic|completely safe|zero risk)\b"),
    # Definitive scam verdicts
    re.compile(r"(?i)\b(?:guaranteed scam|definitely a scam|100% scam|confirmed fraud)\b"),
    # Fictitious device or compromise claims
    re.compile(r"(?i)\b(?:device is compromised|phone is hacked|account is permanently seized)\b"),
    # Fictitious external lookup claims
    re.compile(r"(?i)\b(?:we visited the link|reputation check confirmed|checked against national blacklist)\b"),
]

# Prohibited executable markup
PROHIBITED_MARKUP_PATTERN = re.compile(
    r"(?i)(?:<script\b|<iframe\b|<object\b|<embed\b|<form\b|<input\b|javascript:|vbscript:|data:text/html)",
)


def _strict_object_pairs_hook(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    """Parse JSON objects while rejecting any duplicate keys."""
    res: dict[str, Any] = {}
    for key, val in pairs:
        if key in res:
            raise OutputValidationError(f"Duplicate JSON key detected in provider output: '{key}'")
        res[key] = val
    return res


def _reject_special_floats(val: str) -> None:
    """Reject NaN, Infinity, -Infinity numeric constants."""
    raise OutputValidationError(f"Invalid numeric constant detected in provider output: '{val}'")


class ValidatedRawOutput:
    """Validated structured output extracted from raw untrusted provider completion."""

    def __init__(
        self,
        factual_summary: str,
        findings: list[RawAiFinding],
        uncertainty_notes: list[str],
        suggested_actions: list[RawSuggestedAction],
    ) -> None:
        self.factual_summary = factual_summary
        self.findings = findings
        self.uncertainty_notes = uncertainty_notes
        self.suggested_actions = suggested_actions


class OutputValidator:
    """
    Validates untrusted AI provider completions against strict structural and semantic policies.

    Invariants:
    1. Rejects malformed JSON, duplicate keys, and special numeric constants.
    2. Enforces top-level shape, field types, and strict upper bounds.
    3. Rejects unexpected properties (no silent tolerance of unauthorized fields).
    4. Enforces the canonical 10-category taxonomy; unknown categories cause rejection.
    5. Prohibits fraud probabilities, guaranteed-safety claims, and executable markup.
    6. Does not silently repair or extract partial fragments from surrounding prose.
    """

    @classmethod
    def parse_and_validate(cls, raw_completion: str) -> ValidatedRawOutput:
        """
        Parse raw provider completion text and enforce strict validation rules.

        Raises OutputValidationError on any schema, boundary, or semantic policy violation.
        """
        if not raw_completion or not raw_completion.strip():
            raise OutputValidationError("AI provider returned empty completion content.")

        stripped = raw_completion.strip()

        # Strict JSON parse
        try:
            data = json.loads(
                stripped,
                object_pairs_hook=_strict_object_pairs_hook,
                parse_constant=_reject_special_floats,
            )
        except json.JSONDecodeError as exc:
            raise OutputValidationError(f"Malformed JSON in provider completion: {exc.msg}") from exc

        if not isinstance(data, dict):
            raise OutputValidationError("AI provider completion root must be a JSON object.")

        # Check for refusal or error envelopes
        if "refusal" in data and data["refusal"]:
            raise OutputValidationError(f"AI provider refused request: {data['refusal']}")
        if "error" in data:
            raise OutputValidationError("AI provider returned an error envelope.")

        # Reject unexpected top-level fields
        for key in data:
            if key not in ALLOWED_TOP_LEVEL_KEYS:
                raise OutputValidationError(f"Unexpected top-level field in provider output: '{key}'")

        # 1. Validate factual summary
        factual_summary = data.get("factualSummary") or data.get("factual_summary")
        if not isinstance(factual_summary, str) or not factual_summary.strip():
            raise OutputValidationError("Missing or empty 'factualSummary' field in provider output.")
        factual_summary = factual_summary.strip()
        if len(factual_summary) > MAX_SUMMARY_LENGTH:
            raise OutputValidationError(
                f"'factualSummary' exceeds maximum allowable length ({len(factual_summary)} > {MAX_SUMMARY_LENGTH})."
            )
        cls._assert_safe_semantics(factual_summary, "factualSummary")

        # 2. Validate findings
        raw_findings = data.get("findings")
        if raw_findings is None or not isinstance(raw_findings, list):
            raise OutputValidationError("Missing or non-list 'findings' field in provider output.")

        if len(raw_findings) > MAX_FINDINGS_COUNT:
            raise OutputValidationError(
                f"Findings count exceeds maximum allowable limit ({len(raw_findings)} > {MAX_FINDINGS_COUNT})."
            )

        validated_findings: list[RawAiFinding] = []
        for idx, item in enumerate(raw_findings):
            finding = cls._validate_single_finding(item, index=idx)
            validated_findings.append(finding)

        # 3. Validate uncertainty notes
        raw_notes = data.get("uncertaintyNotes") if "uncertaintyNotes" in data else data.get("uncertainty_notes", [])
        if not isinstance(raw_notes, list):
            raise OutputValidationError("'uncertaintyNotes' must be a JSON list.")
        if len(raw_notes) > MAX_UNCERTAINTY_NOTES_COUNT:
            raise OutputValidationError(
                f"Uncertainty notes count exceeds maximum limit ({len(raw_notes)} > {MAX_UNCERTAINTY_NOTES_COUNT})."
            )

        validated_notes: list[str] = []
        for idx, note in enumerate(raw_notes):
            if not isinstance(note, str) or not note.strip():
                raise OutputValidationError(f"Uncertainty note at index {idx} must be a non-empty string.")
            note_str = note.strip()
            if len(note_str) > MAX_NOTE_LENGTH:
                raise OutputValidationError(
                    f"Uncertainty note at index {idx} exceeds maximum length ({len(note_str)} > {MAX_NOTE_LENGTH})."
                )
            cls._assert_safe_semantics(note_str, f"uncertaintyNotes[{idx}]")
            validated_notes.append(note_str)

        # 4. Validate suggested actions
        raw_actions = (
            data.get("suggestedActions") if "suggestedActions" in data else data.get("suggested_actions", [])
        )
        if not isinstance(raw_actions, list):
            raise OutputValidationError("'suggestedActions' must be a JSON list.")
        if len(raw_actions) > MAX_SUGGESTED_ACTIONS_COUNT:
            raise OutputValidationError(
                f"Suggested actions count exceeds maximum limit ({len(raw_actions)} > {MAX_SUGGESTED_ACTIONS_COUNT})."
            )

        validated_actions: list[RawSuggestedAction] = []
        for idx, act in enumerate(raw_actions):
            action = cls._validate_single_action(act, index=idx)
            validated_actions.append(action)

        return ValidatedRawOutput(
            factual_summary=factual_summary,
            findings=validated_findings,
            uncertainty_notes=validated_notes,
            suggested_actions=validated_actions,
        )

    @classmethod
    def _validate_single_finding(cls, item: Any, index: int) -> RawAiFinding:
        """Validate a single finding object."""
        if not isinstance(item, dict):
            raise OutputValidationError(f"Finding at index {index} is not a JSON object.")

        for key in item:
            if key not in ALLOWED_FINDING_KEYS:
                raise OutputValidationError(f"Unexpected field in finding[{index}]: '{key}'")

        # Category
        raw_category = item.get("category")
        if not isinstance(raw_category, str) or not raw_category.strip():
            raise OutputValidationError(f"Finding at index {index} missing 'category'.")
        try:
            category = IndicatorCategory(raw_category.strip())
        except ValueError as exc:
            raise OutputValidationError(
                f"Finding at index {index} contains unknown category: '{raw_category}'."
            ) from exc

        # Severity
        raw_severity = item.get("severity")
        if not isinstance(raw_severity, str) or not raw_severity.strip():
            raise OutputValidationError(f"Finding at index {index} missing 'severity'.")
        try:
            severity = FindingSeverity(raw_severity.strip().lower())
        except ValueError as exc:
            raise OutputValidationError(
                f"Finding at index {index} contains unknown severity: '{raw_severity}'."
            ) from exc

        # Title
        title = item.get("title")
        if not isinstance(title, str) or not title.strip():
            raise OutputValidationError(f"Finding at index {index} missing or empty 'title'.")
        title_str = title.strip()
        if len(title_str) > MAX_TITLE_LENGTH:
            raise OutputValidationError(
                f"Finding at index {index} title exceeds max length ({len(title_str)} > {MAX_TITLE_LENGTH})."
            )
        cls._assert_safe_semantics(title_str, f"finding[{index}].title")

        # Explanation
        explanation = item.get("explanation")
        if not isinstance(explanation, str) or not explanation.strip():
            raise OutputValidationError(f"Finding at index {index} missing or empty 'explanation'.")
        explanation_str = explanation.strip()
        if len(explanation_str) > MAX_EXPLANATION_LENGTH:
            raise OutputValidationError(
                f"Finding at index {index} explanation exceeds max length ({len(explanation_str)} > {MAX_EXPLANATION_LENGTH})."
            )
        cls._assert_safe_semantics(explanation_str, f"finding[{index}].explanation")

        # Evidence references
        raw_refs = item.get("evidenceReferences")
        if raw_refs is None:
            raw_refs = item.get("evidence_references")
        if not isinstance(raw_refs, list) or len(raw_refs) == 0:
            raise OutputValidationError(
                f"Finding at index {index} must contain at least one evidence reference."
            )
        if len(raw_refs) > MAX_EVIDENCE_PER_FINDING:
            raise OutputValidationError(
                f"Finding at index {index} exceeds evidence reference limit ({len(raw_refs)} > {MAX_EVIDENCE_PER_FINDING})."
            )

        evidence_refs: list[RawEvidenceReference] = []
        for ref_idx, ref_item in enumerate(raw_refs):
            evidence_ref = cls._validate_single_evidence(ref_item, finding_index=index, ref_index=ref_idx)
            evidence_refs.append(evidence_ref)

        finding_id = str(item.get("id") or f"model-finding-{index + 1}").strip()
        return RawAiFinding(
            id=finding_id,
            category=category,
            severity=severity,
            title=title_str,
            explanation=explanation_str,
            evidence_references=evidence_refs,
        )

    @classmethod
    def _validate_single_evidence(cls, item: Any, finding_index: int, ref_index: int) -> RawEvidenceReference:
        """Validate a single evidence reference."""
        if not isinstance(item, dict):
            raise OutputValidationError(
                f"Finding[{finding_index}].evidenceReferences[{ref_index}] is not a JSON object."
            )

        for key in item:
            if key not in ALLOWED_EVIDENCE_KEYS:
                raise OutputValidationError(
                    f"Unexpected field in finding[{finding_index}].evidenceReferences[{ref_index}]: '{key}'"
                )

        excerpt = item.get("excerpt")
        if not isinstance(excerpt, str) or not excerpt:
            raise OutputValidationError(
                f"Finding[{finding_index}].evidenceReferences[{ref_index}] has missing or empty 'excerpt'."
            )
        if len(excerpt) > MAX_EXCERPT_LENGTH:
            raise OutputValidationError(
                f"Finding[{finding_index}].evidenceReferences[{ref_index}] excerpt exceeds max length ({len(excerpt)} > {MAX_EXCERPT_LENGTH})."
            )

        start_offset = item.get("startOffset") if "startOffset" in item else item.get("start_offset")
        end_offset = item.get("endOffset") if "endOffset" in item else item.get("end_offset")

        parsed_start: int | None = None
        parsed_end: int | None = None

        if start_offset is not None:
            if not isinstance(start_offset, int) or isinstance(start_offset, bool) or start_offset < 0:
                raise OutputValidationError(
                    f"Finding[{finding_index}].evidenceReferences[{ref_index}] 'startOffset' must be a non-negative integer."
                )
            parsed_start = start_offset

        if end_offset is not None:
            if not isinstance(end_offset, int) or isinstance(end_offset, bool) or end_offset <= 0:
                raise OutputValidationError(
                    f"Finding[{finding_index}].evidenceReferences[{ref_index}] 'endOffset' must be a positive integer."
                )
            parsed_end = end_offset

        return RawEvidenceReference(
            excerpt=excerpt,
            start_offset=parsed_start,
            end_offset=parsed_end,
        )

    @classmethod
    def _validate_single_action(cls, item: Any, index: int) -> RawSuggestedAction:
        """Validate a single suggested action object."""
        if not isinstance(item, dict):
            raise OutputValidationError(f"Suggested action at index {index} is not a JSON object.")

        for key in item:
            if key not in ALLOWED_ACTION_KEYS:
                raise OutputValidationError(f"Unexpected field in suggestedActions[{index}]: '{key}'")

        priority = item.get("priority", "recommended")
        if not isinstance(priority, str) or priority.strip().lower() not in ("immediate", "recommended", "conditional"):
            raise OutputValidationError(
                f"Suggested action at index {index} priority must be 'immediate', 'recommended', or 'conditional'."
            )
        priority_str = priority.strip().lower()

        title = item.get("title")
        if not isinstance(title, str) or not title.strip():
            raise OutputValidationError(f"Suggested action at index {index} missing or empty 'title'.")
        title_str = title.strip()
        if len(title_str) > MAX_TITLE_LENGTH:
            raise OutputValidationError(
                f"Suggested action at index {index} title exceeds max length ({len(title_str)} > {MAX_TITLE_LENGTH})."
            )
        cls._assert_safe_semantics(title_str, f"suggestedActions[{index}].title")

        detail = item.get("detail") or item.get("description")
        if not isinstance(detail, str) or not detail.strip():
            raise OutputValidationError(f"Suggested action at index {index} missing or empty 'detail'.")
        detail_str = detail.strip()
        if len(detail_str) > MAX_ACTION_DETAIL_LENGTH:
            raise OutputValidationError(
                f"Suggested action at index {index} detail exceeds max length ({len(detail_str)} > {MAX_ACTION_DETAIL_LENGTH})."
            )
        cls._assert_safe_semantics(detail_str, f"suggestedActions[{index}].detail")

        action_id = str(item.get("id") or f"action-{index + 1}").strip()
        return RawSuggestedAction(
            id=action_id,
            priority=priority_str,
            title=title_str,
            detail=detail_str,
        )

    @classmethod
    def _assert_safe_semantics(cls, text: str, field_name: str) -> None:
        """Assert that string does not contain prohibited claims or executable markup."""
        # 1. Markup check
        if PROHIBITED_MARKUP_PATTERN.search(text):
            raise OutputValidationError(
                f"Prohibited executable markup or URI scheme detected in '{field_name}'."
            )

        # 2. Semantic claims check
        for pattern in PROHIBITED_SEMANTIC_PATTERNS:
            if pattern.search(text):
                raise OutputValidationError(
                    f"Prohibited semantic claim (risk percentage, certainty verdict, or false guarantee) detected in '{field_name}'."
                )
