# TrustCue Data Contracts & Serialization Policy

This document defines the core data models, serialization contracts, failure handling, and security boundaries established in Module 15 for digital communication intake and scam indicator analysis.

---

## 1. Architectural Scope & Ownership

These contracts define platform-independent domain models and version-1 JSON codecs for TrustCue. They are pure Dart constructs and do not depend on Flutter UI, GetX, local storage, HTTP clients, or platform plugins.

### Feature Ownership & Folder Layout
- `frontend/lib/core/`
  - `errors/analysis_failure.dart`: Structured failure categories and safe diagnostic representations.
  - `types/result.dart`: Generic, explicit `Result<T>` (`Success<T>` and `Failure<T>`) monad.
- `frontend/lib/features/input/`
  - `domain/models/input_source.dart`: Enumeration of supported communication vectors.
  - `domain/models/text_snapshot.dart`: Immutable, timestamped snapshot of input text.
  - `data/serialization/text_snapshot_codec.dart`: Version-1 JSON codec for text snapshots.
- `frontend/lib/features/analysis/`
  - `domain/models/finding_origin.dart`: Provenance category (`localRule` vs. `remoteAi`).
  - `domain/models/evidence_reference.dart`: Verifiable text excerpt reference using UTF-16 code-unit offsets.
  - `domain/models/analysis_finding.dart`: Individual detected scam indicator with attached evidence.
  - `domain/models/analysis_report.dart`: Aggregated analysis report grouping findings, methodology limitations, and suggested actions.
  - `domain/contracts/analysis_service.dart`: Asynchronous service contract for evaluating snapshots.
  - `data/serialization/`: Version-1 codecs for findings, evidence references, and analysis reports.

---

## 2. Models & Field Definitions

### `InputSource`
Represents the origin channel through which digital communication enters the application:
- `messageText`: Pasted or typed text message (SMS, WhatsApp, chat, email body).
- `screenshot`: Optical image or screenshot containing digital text.
- `link`: Suspicious URL or web destination.
- `qrCode`: Scanned QR code payload.
*Note: `link` and `qrCode` are maintained distinctly in data models and serialization even when grouped on the dashboard.*

### `TextSnapshot`
An immutable snapshot of exact digital communication text:
- `id` (`String`): Caller-supplied, non-empty identifier. Identifiers are never generated invisibly during serialization to guarantee determinism.
- `source` (`InputSource`): Communication source type.
- `text` (`String`): Exact, unredacted, unnormalized text. An empty string represents an initial draft.
- `createdAt` (`DateTime`): Normalized strictly to UTC.

### `EvidenceReference`
Pointers to specific substring evidence inside a `TextSnapshot`:
- `snapshotId` (`String`): Must strictly match the parent `TextSnapshot.id`.
- `startOffset` (`int`): 0-based start index (inclusive) in UTF-16 code units.
- `endOffset` (`int`): End index (exclusive) in UTF-16 code units (`endOffset > startOffset`).
- `exactExcerpt` (`String`): Verbatim substring at `[startOffset, endOffset)`. Length must match `(endOffset - startOffset)`.
- *Invariants:* Offsets must never split a UTF-16 surrogate pair (e.g., emojis or supplementary code points). Invented quotations or approximations are prohibited.

### `FindingOrigin`
Provenance descriptor:
- `localRule`: Derived deterministically by on-device pattern and heuristic rules.
- `remoteAi`: Derived via protected server-side AI evaluation.
*Note: Origin represents descriptive provenance. Production code never manufactures synthetic `remoteAi` findings.*

### `AnalysisFinding`
An individual indicator of potential scam tactics:
- `id` (`String`): Stable finding identifier.
- `category` (`String`): Extensible category identifier (e.g., `urgency_indicator`, `payment_threat`).
- `explanation` (`String`): Plain-language explanation of why this indicator is suspicious.
- `origin` (`FindingOrigin`): Provenance type.
- `producerId` (`String`): Rule ID or model descriptor that generated the finding.
- `evidence` (`List<EvidenceReference>`): Non-empty, defensively copied unmodifiable list of verified evidence references.

### `AnalysisReport`
The comprehensive result of an analysis run:
- `id` (`String`): Unique report identifier.
- `schemaVersion` (`int`): Integer schema version (currently `1`).
- `snapshot` (`TextSnapshot`): The exact text snapshot analyzed.
- `analyzedAt` (`DateTime`): Timestamp of analysis in UTC.
- `findings` (`List<AnalysisFinding>`): Defensively copied unmodifiable list of findings. Cannot contain duplicate finding IDs.
- `limitations` (`List<String>`): Explicit methodology limitations (e.g., "Analysis is limited to exact text provided; deterministic rules cannot verify sender identity").
- `suggestedActions` (`List<String>`): Plain-language next steps (e.g., "Verify via official website directly; do not click provided links").
*Important: An empty `findings` list signifies ONLY that no indicators were flagged by active rules. It NEVER constitutes a claim or guarantee of safety.*

---

## 3. Serialization Contract (Version 1)

All codecs operate under strict version-1 decoding rules:

1. **Schema Versioning:**
   - Reports specify `"schemaVersion": 1`. Any other version is rejected with `FormatException`.
2. **Type Strictness:**
   - No coercion: Strings, booleans, or floating-point values are rejected if an integer offset is required.
   - Enums must match exact serialized names (`messageText`, `screenshot`, `link`, `qrCode`, `localRule`, `remoteAi`). Unknown values throw `FormatException`.
3. **Timestamp Standardization:**
   - Timestamps must be ISO-8601 strings containing explicit timezone designators (`Z` or numeric offset like `+05:00`).
   - Timestamps lacking timezone info are rejected. Valid offsets are normalized to UTC upon decoding.
4. **Unknown Field Policy:**
   - Unknown additional top-level or nested JSON keys are ignored in Version 1 to allow forward compatibility.
   - All required fields must still be present, well-typed, and satisfy domain invariants.
5. **Round-Trip Fidelity:**
   - Full round-trip serialization preserves exact text, newlines, Urdu/Arabic script, emojis, evidence offsets, and millisecond timestamps.

---

## 4. Failure Handling & Privacy Protection

The application wraps operations in `Result<T>` rather than throwing unhandled exceptions across boundaries:

```dart
abstract class Result<T> {
  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(AnalysisFailure failure) = Failure<T>;
}
```

### Failure Codes (`AnalysisFailureCode`):
- `invalidInput`: Input fails structural requirements or length constraints.
- `unsupportedInput`: Input format or language is outside current capabilities.
- `unavailable`: Required local engine or remote service is offline/disabled.
- `timeout`: Analysis did not complete within the bounded time limit.
- `cancelled`: User cancelled ongoing processing.
- `malformedData`: Serialization decoding failed due to schema or invariant violations.

### Sensitive Content Protections:
- `AnalysisFailure.toString()` and error messages **never** embed submitted message text, extracted OCR strings, provider response bodies, or authentication credentials.
- Diagnostics are restricted to safe operational descriptions and optional safe metadata.
- Text snapshots and excerpts may contain sensitive personal data. Support for JSON serialization is an internal exchange format; it does **not** authorize saving, logging, background telemetry, or unconsented transmission.

---

## 5. Synthetic JSON Example (Version 1)

```json
{
  "id": "rep-synthetic-20261011-001",
  "schemaVersion": 1,
  "snapshot": {
    "id": "snap-synthetic-001",
    "source": "messageText",
    "text": "Urgent: Your account is suspended. Verify immediately at https://secure-bank.example.com",
    "createdAt": "2026-10-11T12:00:00.000Z"
  },
  "analyzedAt": "2026-10-11T12:00:01.500Z",
  "findings": [
    {
      "id": "find-synthetic-001",
      "category": "urgency_indicator",
      "explanation": "Urgent pressure language prompts immediate action before verifying authenticity.",
      "origin": "localRule",
      "producerId": "rule.urgency.v1",
      "evidence": [
        {
          "snapshotId": "snap-synthetic-001",
          "startOffset": 0,
          "endOffset": 7,
          "exactExcerpt": "Urgent:"
        }
      ]
    },
    {
      "id": "find-synthetic-002",
      "category": "link_indicator",
      "explanation": "Message requests credentials through an unverified external destination.",
      "origin": "localRule",
      "producerId": "rule.links.v1",
      "evidence": [
        {
          "snapshotId": "snap-synthetic-001",
          "startOffset": 57,
          "endOffset": 90,
          "exactExcerpt": "https://secure-bank.example.com"
        }
      ]
    }
  ],
  "limitations": [
    "Analysis is limited to exact text provided in the snapshot.",
    "Deterministic rules cannot confirm sender ownership or verify external domains."
  ],
  "suggestedActions": [
    "Verify your account status by navigating to the official website directly.",
    "Do not click links or call numbers provided in unsolicited messages."
  ]
}
```

---

## 6. Message Text Validation & Normalization (Module 16)

### 6.1 Input Limits and Counting Policy
- **Maximum Code Points (Runes):** `10,000` (`text.runes.length`). Displayed in UI as `"X / 10,000 characters"`.
- **Maximum UTF-8 Bytes:** `40,000` (`utf8.encode(text).length`).
- Limits are evaluated against the original, unnormalized editor text to prevent bypass.

### 6.2 Normalization Rules for TextSnapshot
- Converts CRLF (`\r\n`) and standalone CR (`\r`) line breaks to standard LF (`\n`).
- Preserves all other text properties exactly: casing, internal spacing, tabs, leading/trailing whitespace, URLs, punctuation, and Unicode scripts (e.g., Urdu Nastaliq glyphs, emojis, symbols).
- Editor input remains completely unchanged during typing and validation.

### 6.3 Validation Rejection Criteria
- **Empty input:** Rejects empty string (`MessageTextValidationReason.empty`).
- **Whitespace / invisible-only content:** Rejects inputs composed solely of spaces, tabs, newlines, or invisible Unicode formatting marks (e.g. `\u200B`, `\u200C`, `\u200D`, `\uFEFF`, bidi markers) without visible glyphs (`MessageTextValidationReason.onlyWhitespace`).
- **Length exceeded:** Rejects code points > 10,000 (`MessageTextValidationReason.tooLongCodePoints`) or bytes > 40,000 (`MessageTextValidationReason.tooLongBytes`).
- **Unsupported control characters:** Rejects NUL (`\u0000`), bell, ESC, or C0/C1 control characters other than `\t`, `\n`, `\r` (`MessageTextValidationReason.unsupportedControlCharacters`).
- **Malformed Unicode:** Rejects unpaired UTF-16 surrogate code units (`MessageTextValidationReason.malformedUnicode`).

### 6.4 Privacy and Invariants
- `MessageTextValidationError` and mapped `AnalysisFailure` instances never include user message contents, fragments, or credentials in diagnostics or error messages.
- `TextSnapshot` prepared from message text entry is held in-memory within the route-scoped `InputTextController` and is invalidated immediately upon subsequent user edits.

---

## 7. Text Review, Sensitive Data Detection, and Redaction (Module 19)

### 7.1 Domain Models
- **`SensitiveDataType`**: Enum defining detected sensitive categories:
  - `email`: Placeholder `[EMAIL]`, priority 1.
  - `phone`: Placeholder `[PHONE]`, priority 2.
  - `verificationCode`: Placeholder `[VERIFICATION CODE]`, priority 3 (4–8 digits near authentication context triggers like `code`, `otp`, `verification`).
  - `paymentCard`: Placeholder `[CARD NUMBER]`, priority 4 (13–19 digits satisfying standard Luhn checksum).
- **`SensitiveDataCandidate`**: Immutable candidate model with UTF-16 code-unit offsets `[startIndex, endIndex)`, masked label (`•••• 1234`), contextual summary snippet, and revision tag.
- **`ReviewInput`**: In-memory container passed to `/input/review` holding `snapshot`, `sourceRevision`, and optional `imagePath`. Never serialized to query strings or URLs.
- **`ReviewedTextResult`**: Immutable confirmation result holding freshly minted `TextSnapshot`, `sourceSnapshotId`, `sourceRevision`, UTC timestamp `reviewedAt`, and unmodifiable `redactionCounts` map.

### 7.2 Overlap Resolution & Redaction Application Policy
- **Deterministic Priority:** `paymentCard` (4) > `verificationCode` (3) > `phone` (2) > `email` (1). When candidate ranges overlap, higher-priority items take precedence. Ties broken by longer match length, then earlier start offset.
- **Descending Offset Application:** Redactions are applied in descending UTF-16 code-unit offset order so that earlier replacement offsets in the text remain exact and uncorrupted.
- **Invariants:** Replacement ranges never split UTF-16 surrogate code pairs.

### 7.3 Privacy & Local-Only Boundary
- Review and redaction operations are strictly local to the device memory session.
- Diagnostic `toString()` representations omit unmasked sensitive candidate strings.
- Neither unredacted nor redacted text is transmitted or evaluated by AI in this module.

---

## 8. Future Extension Points

- **Module 20–21:** URL parsing, QR decoding, and Android incoming-share handling.
- **Module 22–26:** Warning taxonomy, rule engine, evidence location mapping, and local assessment aggregation.
