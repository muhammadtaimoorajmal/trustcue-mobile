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

## 8. Link Inspection, QR Decoding, and Destination Opening Contracts (Module 20 / 20A)

### 8.1 Link Inspection Models & Boundaries
- **`LinkInspectionResult`**: Complete immutable outcome of local URI parsing:
  - `rawInput` (`String`): Exact raw string entered or extracted.
  - `parsedUri` (`Uri?`): Standard parsed Dart URI when valid.
  - `scheme` (`String?`): Lowercase scheme (`http` or `https` permitted for opening).
  - `host` (`String?`): Hostname, IPv4, or IPv6 literal.
  - `port` (`int?`): Explicit port number if specified.
  - `path` (`String?`): Normalized hierarchical path.
  - `query` (`String?`): Full query string when present.
  - `fragment` (`String?`): Anchor or fragment identifier when present.
  - `isIpAddress` (`bool`): True if host is an IPv4 or IPv6 literal.
  - `isPunycode` (`bool`): True if host contains conventional ASCII punycode labels (`xn--...`).
  - `observations` (`List<String>`): Factual, non-judgmental structural characteristics:
    - Numerical IPv4 / IPv6 literal address usage.
    - Non-standard port usage.
    - Conventional Punycode label presence (`xn--`).
    - Unencrypted HTTP connection warning.
    - Factual query parameter count.
    - Factual observation of parameter names commonly associated with destination redirection (without claiming or concluding open redirect vulnerability).
    - *Policy:* No claims of counting "subdomains" or knowing registrable domain boundaries.
  - `rejectionCode` (`LinkRejectionCode?`): Specific rejection reason when invalid.
  - `isValid` (`bool`): True if and only if `rejectionCode == null`.
  - `isLaunchable` (`bool`): True if valid and scheme is strictly `http` or `https`.
- **`LinkRejectionCode`**: Rejection reasons:
  - `empty`: Blank or whitespace-only input.
  - `tooLong`: Input exceeds 4,096 UTF-8 bytes.
  - `missingScheme`: Missing explicit `http://` or `https://` protocol.
  - `unsupportedScheme`: Scheme is not supported (only `http`/`https` eligible for destination review).
  - `containsUserInfo`: URL contains embedded credentials (`user:pass@host`).
  - `malformedHost`: Hostname is missing or structurally invalid.
  - `unicodeHostUnsupported`: Unencoded non-ASCII Unicode hostnames are rejected as unsupported; standard ASCII punycode (`xn--...`) is required and accepted with a factual observation.
  - `localOrPrivateHost`: Localhost, RFC 1918 private IPs, loopback, link-local, or broadcast addresses.
  - `containsControlChars`, `containsInvisibleChars`, `containsBidiChars`, `containsBackslash`, `malformedPercentEncoding`, `malformedPort`, `malformedUrl`.

### 8.2 QR Decoding Contracts
- **`QrPayloadType`**: Categorization enum:
  - `webUrl`: Valid `http` or `https` link; inspected via `UrlInspectionService`.
  - `plainText`: Non-URL text or text exceeding URL constraints (strictly `<= 4,096` UTF-8 bytes).
  - `unsupported`: Non-web payloads (Wi-Fi, vCard, mailto, tel, SMS, payment/UPI, app intents) OR payloads exceeding 4,096 UTF-8 bytes (`isOversized: true`, formatDescription: `Oversized Payload`).
- **`QrPayload`**: Immutable payload descriptor containing `type`, `rawValue`, `byteCount`, `summary`, `formatDescription`, `isOversized`, and optional `LinkInspectionResult`.
  - *Strict Limit Enforcement (Module 20A):* Any decoded payload exceeding 4,096 UTF-8 bytes is strictly classified as `QrPayloadType.unsupported` (`isOversized: true`), preventing recategorization as `plainText` or forwarding to `/input/review`.
- **`QrDecodeResult`**: Result container with `payloads` list, `detectedCount`, `uniqueCount`, and status (`noneFound`, `singlePayload`, `multiplePayloads`).

### 8.3 Safe Opening and Privacy Invariants
- Zero network requests, DNS queries, or socket connections are initiated during URL inspection or QR decoding.
- Destination opening strictly delegates to external browser via `UrlLauncherAdapter` with `LaunchMode.externalApplication`.
- Opening requires explicit two-step confirmation presenting complete destination hostname and exact selectable URL.
- Confirmed state is cleared immediately if the underlying input or QR payload changes.

---

## 9. Android Incoming Share Contracts (Module 21)

### 9.1 Supported Payload Types & Intake Rules
- **Supported Intents:** Android `ACTION_SEND` with `text/plain`, `image/png`, or `image/jpeg`.
- **Text Bounds:** Strictly enforced maximum 10,000 code points (runes) and 40,000 UTF-8 bytes. Truncated or oversized text beyond these boundaries is flagged or bounded before consumption.
- **Image Bounds & Magic-Byte Verification:** Streamed off the main UI thread via `ContentResolver` into private staging cache (`cacheDir/trustcue_incoming_shares/`). Maximum file size 10 MiB (10,485,760 bytes). Streams exceeding 10 MiB are immediately aborted and deleted. Content is validated against authentic magic bytes:
  - PNG: `89 50 4E 47`
  - JPEG: `FF D8 FF`
- **Rejection Policy:** Multiple image shares (`ACTION_SEND_MULTIPLE`), non-content file URIs, unsupported MIME types, corrupt image streams, or oversized images are rejected with user-visible errors and never crash the application.
- **Mixed Content:** Intents with both text and an image present both components in the review presentation; users deliberately choose which item to examine. Payloads are never silently merged or dropped.

### 9.2 Domain Models & Platform Interface
- **`IncomingShareType`**: Enum designating share category:
  - `text`: Plain text payload.
  - `image`: Valid staged PNG or JPEG image payload.
  - `mixed`: Both valid plain text and staged image present.
  - `unsupported`: Rejected intent, oversized content, or unreadable URI with descriptive `errorMessage`.
- **`IncomingSharePayload`**: Immutable payload model holding:
  - `eventId` (`String`): UUID identifying the specific share instance.
  - `type` (`IncomingShareType`): Payload category.
  - `text` (`String?`): Validated shared text if present.
  - `stagedImagePath` (`String?`): Canonical file path to staged image in private cache.
  - `mimeType` (`String?`): Verified MIME type (`image/png`, `image/jpeg`, `text/plain`).
  - `errorMessage` (`String?`): Descriptive explanation if rejected.
- **Platform Channel (`trustcue/incoming_share`)**:
  - `getInitialShare`: Invoked on cold startup to retrieve any launch intent payload.
  - `onShareReceived`: Method channel event emitted from native `onNewIntent` when share arrives while running.
  - `consumeShare(String eventId)`: Acknowledges processing and clears native memory/intent cache.
  - `cleanStagedFile(String filePath)`: Safely deletes staged image from `trustcue_incoming_shares/`.

### 9.3 Lifecycle, Onboarding, and Draft Protection Invariants
- **Onboarding Gate:** If the user has not completed onboarding, incoming shares are held in memory as `pendingShare` and only presented after onboarding is fully acknowledged.
- **Single Pending Share Policy:** At most one incoming share is held pending user decision. Any prior unconsumed pending share is safely replaced and its staged file cleaned up.
- **Draft Conflict Protection (`DraftConflict`):** If the destination input screen already holds an unsaved draft (text, screenshot, or inspected URL), the user is explicitly warned before replacing it ("Keep current draft" vs "Replace draft with shared content").
- **Transactional Staging:** Shared images are initially copied to a temporary staging cache. When the user accepts the image for analysis (as screenshot or QR image), it is transactionally imported into the app-owned `ScreenshotStorageService` before the staged file is cleaned up.
- **Strict Privacy Invariants:** Zero automatic OCR, QR decoding, URL opening, or network analysis is triggered upon share reception. User interaction is strictly required.

---

## 10. Future Extension Points

- **Module 22–26:** Warning taxonomy, rule engine, evidence location mapping, and local assessment aggregation.
