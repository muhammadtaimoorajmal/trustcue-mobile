# TrustCue AI Output Validation & Evidence Grounding Specification

## 1. Overview & Purpose
This document defines the strict validation and deterministic evidence-grounding layer implemented in **Module 34** between raw, untrusted AI provider completions and client-facing application reports.

TrustCue treats all outputs from upstream large language models (such as Groq's `llama-3.3-70b-versatile`) as **untrusted data**. Even when structured JSON output mode is active, the model output cannot be presumed conformant, grounded, or safe.

---

## 2. Strict Output Validation Layer (`OutputValidator`)

### 2.1 Parsing Invariants
1. **No Duplicate JSON Keys:** Evaluated via a strict `object_pairs_hook`. If duplicate keys occur (e.g. repeated `"category"` or `"findings"`), the payload is rejected with `OutputValidationError`. Standard Python `json.loads` silently overwrites prior keys; TrustCue prohibits this silent mutation.
2. **Rejection of Special Floats:** `NaN`, `Infinity`, and `-Infinity` are rejected via `parse_constant`.
3. **No Automatic Prose Scavenging:** The validator does not use regular expressions to fish out `{ ... }` fragments from arbitrary prose or conversational filler. The completion must be a valid top-level JSON object.
4. **No Silent Truncation/Repairs:** If a model returns 25 findings (exceeding the limit of 20), the backend does not silently truncate to 20 to manufacture a false success; the entire response is rejected.

### 2.2 Envelope Boundaries & Types
| Field | Type | Bounds | Policy |
| :--- | :--- | :--- | :--- |
| `factualSummary` | `string` | 1–512 chars | Required. Objective summary of evaluated patterns. |
| `findings` | `array[object]` | 0–20 items | Required list. Each item must conform to canonical taxonomy. |
| `uncertaintyNotes` | `array[string]` | 0–10 items | Max 256 chars/item. Contains honest limitations. |
| `suggestedActions` | `array[object]` | 0–10 items | Safe protective next steps. |

### 2.3 Prohibited Semantic Claims
The validator actively scans all generated text (`factualSummary`, `title`, `explanation`, `detail`) against regular expressions prohibiting deceptive or overconfident assertions:
- **Numerical Risk/Fraud Probabilities:** Rejects strings like `95% scam probability`, `risk score: 85`, `80% fraud risk`. TrustCue does not invent pseudo-scientific probabilities.
- **Safety Guarantees:** Rejects `100% safe`, `guaranteed safe`, `verified authentic`, `zero risk`.
- **Definitive Scam Claims:** Rejects `guaranteed scam`, `definitely fraudulent`, `confirmed scammer`.
- **Fictitious Lookups/Compromises:** Rejects claims like `your phone is hacked`, `checked against national blacklist`, or `we visited the link`.
- **Executable Markup:** Rejects `<script>`, `<iframe`, `<form`, `javascript:`, and `data:text/html`.

---

## 3. Exact Evidence Grounding (`EvidenceGrounder`)

### 3.1 Input Preservation
The submitted reviewed text is preserved **byte-for-byte**:
- **NO trimming** (`strip()`).
- **NO case-folding** (`lower()`).
- **NO whitespace collapsing** (multiple spaces, tabs, `\r\n` vs `\n` are preserved).
- **NO Unicode normalization** (e.g. NFC vs NFD). The excerpt must match the exact character representation submitted.

### 3.2 UTF-16 Code-Unit Offset Mapping
Dart strings are indexed by UTF-16 code units (where characters in the Basic Multilingual Plane count as 1 code unit, and supplementary astral characters such as emojis count as 2 code units: a surrogate pair). Python strings are indexed by Unicode code points.

The backend builds an authoritative UTF-16 offset map:
$$\text{char\_to\_utf16}[i] = \sum_{k=0}^{i-1} (2 \text{ if } \operatorname{ord}(\text{text}[k]) > \text{0xFFFF} \text{ else } 1)$$

- **Surrogate Split Protection:** Offsets that fall between the high surrogate and low surrogate of a supplementary character are strictly rejected.
- **Range Invariants:** $0 \le \text{startOffset} < \text{endOffset} \le \text{total\_utf16\_units}$.
- **Decoded Substring Equality:** $\operatorname{decode}(\text{text\_utf16}[2 \times \text{startOffset} : 2 \times \text{endOffset}]) == \text{excerpt}$.

### 3.3 Repeated Quotation Disambiguation Policy
When the exact quotation string appears more than once in the submitted text:
1. **No Offsets Provided:** The finding is rejected as ambiguous with `AmbiguousQuotationError`. The system will never arbitrarily pick the first occurrence.
2. **Offsets Provided by Provider:** The model-supplied `startOffset` and `endOffset` are tested against the exact text. If they identify a valid occurrence without splitting surrogates, that occurrence is grounded. If they fail to match or split a surrogate, the response is rejected.

### 3.4 Empty Findings & Limitation Injection
If the AI model detects zero warning indicators (`len(findings) == 0`), the response is valid, but the system guarantees that `uncertaintyNotes` includes:
> *"No scam warning indicators were detected in the evaluated text snapshot. This does not establish that the communication is safe, authentic, or risk-free."*

---

## 4. Quota Accounting Policy

| Scenario | Quota Outcome | Rationale |
| :--- | :--- | :--- |
| **Connect Timeout** | Refunded | Network connection was never established; no upstream tokens used. |
| **Upstream 401 / 429 / 503** | Refunded | Upstream provider error or rate limit; request did not execute inference. |
| **Ambiguous Read Timeout** | Retained (Not Refunded) | Request was dispatched; provider LPUs may have consumed compute. |
| **Validation / Grounding Failure** | Retained (Committed) | Inference ran to completion and tokens were consumed upstream. Withholding refunds prevents attackers from exploiting prompt injection to generate unlimited free inference calls. |
| **Successful Grounding** | Retained (Committed) | Normal successful transaction. |

---

## 5. What Validation Guarantees vs. What It Cannot Guarantee

### What Validation Guarantees:
- **Exact Quotation Existence:** Proves that every cited excerpt exists verbatim in the reviewed snapshot.
- **Valid UTF-16 Code-Unit Range:** Proves that mobile Flutter clients can highlight the evidence without crashing or splitting emojis.
- **Taxonomy Adherence:** Every finding belongs strictly to one of the 10 approved `IndicatorCategory` values.
- **Plain Data Safety:** Proves the output contains no executable HTML, script tags, or dangerous link schemes.
- **Absence of Fabricated Probabilities:** Prevents the model from manufacturing numerical percentages or safety certificates.

### What Validation CANNOT Guarantee:
- **Semantic Truth:** Having exact evidence proves the words were said; it does not prove the model's interpretation of intent is infallible.
- **Absence of Missed Scams:** Zero findings does not mean the communication is safe.
- **Sender Authenticity:** The backend cannot verify physical sender identity from text alone.

---

## 6. Public Workflow Consent Gate (Module 35)

In **Module 34**, the entire internal pipeline (`ProtectedAiService`, `OutputValidator`, `EvidenceGrounder`, and `GroqProviderAdapter`) is fully operational and verified through automated end-to-end test suites.

However, the public route `POST /api/v1/analysis/ai` remains gated with HTTP 503:
```json
{
  "error": {
    "code": "ai_provider_unavailable",
    "message": "Server-assisted AI analysis is temporarily unavailable pending mobile upload consent and client workflow implementation (Module 35)."
  }
}
```
**Gate Check Before Side Effects:** The gate check is evaluated before reserving quota in the database or acquiring concurrency locks. This ensures zero database churn, zero network calls, and instant responses until Module 35 implements mobile upload consent.
