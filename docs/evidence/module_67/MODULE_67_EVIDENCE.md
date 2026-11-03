# TrustCue Evidence Dossier: Module 67

**Milestone:** MODULE 67: Opt-in Metadata Cloud Sync Push & Pull Verification, including Two Targeted Module 66 Acceptance Repairs  
**Date:** November 3, 2026  
**Lead Developer:** Muhammad Taimoor Ajmal  
**Academic Program:** Production Release 2026  
**Course:** TrustCue Mobile Application Development  
**Institution:** TrustCue Engineering  
**Document ID:** `DOC-M67-EVIDENCE-DOSSIER`  
**Classification:** Definitive Verification, Observability & Acceptance Evidence  

---

## 1. Executive Summary & Exact Verified Baselines

Module 67 delivers comprehensive end-to-end verification and hardening of TrustCue's opt-in cloud report synchronization architecture, while resolving the two targeted Module 66 acceptance findings. It establishes that cloud report synchronization is strictly opt-in, disabled by default, completely independent from Cloud AI analysis consent, and bounded to a strict non-sensitive metadata allowlist. Prohibited fields (raw text, prompts, excerpts, evidence quotes, screenshots, image bytes, OCR text, and content hashes) are rejected across client codecs, backend schemas, and database check constraints.

### Exact Multi-Repository CI Verification Matrix

| Repository | Git Branch | Commit SHA | CI Workflow Run ID | CI Status | Test Results & Invariants Verified |
|---|---|---|---|---|---|
| `trustcue-backend` | `backend` | `a4a79fc` | [41575460306](https://github.com/muhammadtaimoorajmal/trustcue-mobile/actions/runs/41575460306) | **SUCCESS** | 184/184 unit & integration tests passed; Ruff linter clean; quota dispatch inference gate verified; bounded telemetry allowlist verified; sync isolation & telemetry verified. |
| `trustcue-database` | `database` | `50b02fb` | [41489694681](https://github.com/muhammadtaimoorajmal/trustcue-mobile/actions/runs/41489694681) | **SUCCESS** | 15/15 static schema & SQL regression tests passed; migrations 00003, 00007, 00008 active with `chk_report_payload_privacy`, RPCs `sync_push_reports` and `purge_synced_reports`. |
| `trustcue-mobile` | `frontend` | `18d69ba` (code) | [41468379659](https://github.com/muhammadtaimoorajmal/trustcue-mobile/actions/runs/41468379659) | **SUCCESS** | 95/95 reports suite passed; 17/17 sync tests passed; 99/99 auth tests passed; signed release APK verified on Vivo V2207. |
| Baseline | `main` | `a785db8` | N/A | **CLEAN** | Pre-integration baseline strictly untouched. |

---

## 2. Module 66 Acceptance Repairs

### Repair A: Quota Dispatch Inference Gate & Settlement Safety
- **Root Cause & Defect:** In Module 66, when `self.quota_store.dispatch_quota` returned `False` or encountered an exception, the failure was logged but execution continued to `self.provider.analyze`, allowing external LLM inference to proceed on unconfirmed or invalid reservations.
- **Architectural Fix Implemented (`trustcue_backend/providers/service.py`):**
  1. Gated provider inference strictly on confirmed dispatch:
     ```python
     if not disp_ok:
         raise TrustCueError(
             code="quota_dispatch_rejected",
             message="Quota reservation could not be dispatched. Please retry.",
             status_code=503,
         )
     ```
  2. Caught dispatch exceptions / timeouts truthfully:
     ```python
     except Exception as disp_err:
         raise TrustCueError(
             code="quota_dispatch_uncertain",
             message="Quota reservation dispatch status is uncertain. Please retry.",
             status_code=503,
         ) from disp_err
     ```
  3. Prohibited blind refunds: when dispatch status is uncertain, no `release_quota` call is made, preventing fraudulent free inference loops while preserving safety.
  4. Preserved legacy compatibility: reservations prefixed with `v1-legacy-` return `True` in `SupabaseQuotaStore.dispatch_quota` without attempting v2 RPCs.
  5. Verified via unit tests in `test_quota_store_module66.py`:
     - `test_dispatch_quota_failure_gates_provider_inference`: Confirmed `provider.analyze`, `release_quota`, and `commit_quota` are NOT called when dispatch returns `False`.
     - `test_dispatch_quota_exception_stops_provider_without_blind_refund`: Confirmed timeout in dispatch stops inference with HTTP 503 and avoids unsafe refund.

### Repair B: Telemetry Cardinality & Metadata Value Bounding
- **Root Cause & Defect:** `MetricsCollector.record_counter` permitted arbitrary string event names into counter dictionary keys, risking unbounded cardinality. `record_stage_duration` and `record_event` checked metadata keys but not metadata values.
- **Architectural Fix Implemented (`trustcue_backend/core/telemetry.py`):**
  1. Enforced finite `VALID_METRICS` allowlist:
     ```python
     VALID_METRICS: set[str] = {
         "quota_reserved", "quota_dispatched", "quota_committed", "quota_released",
         "quota_exhausted", "rate_limited", "concurrency_exceeded",
         "provider_inference_completed", "provider_inference_failed",
         "grounding_completed", "grounding_failed", "reaper_executed",
         "sync_push_completed", "sync_pull_completed", "sync_opt_in_changed",
         "sync_purged", "request_started", "request_completed", "unknown_event",
     }
     ```
  2. Bounded metric mapping: unknown event names are strictly remapped to `"unknown_event"`, and unknown outcomes to `"internal_error"`.
  3. Metadata value validation (`_sanitize_extra_fields`):
     - `quota_mode`: strictly bounded to `{"v1", "v2", "unknown"}`.
     - `provider`: strictly bounded to `{"groq-cloud", "google-gemini", "mock-provider", "unknown"}`.
     - `status_code`: strictly validated as integer between 100 and 599.
     - `reaped_count`, `sync_count`: strictly validated as non-negative integers (`>= 0`).
  4. Verified via unit tests in `test_telemetry.py`:
     - `test_unknown_event_mapped_to_bounded_category`: Confirms unknown event names map strictly to `unknown_event` in metrics summary.
     - `test_metadata_values_bounded_and_sanitized`: Confirms invalid/injected values in `extra_log_fields` are safely sanitized or dropped.

---

## 3. End-to-End Sync Pipeline & Privacy Boundaries

### Strict Allowlist vs. Prohibited Data Boundary

The TrustCue cloud sync pipeline is designed under the zero-knowledge principle for message content:

```
[Local Report / Summary]
           │
           ▼
[CloudReportSummaryCodec]  <── Strictly checks forbiddenKeys: text, excerpt, evidence, screenshot, ocr, hash
           │
           ▼ (Non-sensitive metadata only)
[ReportSyncService]       <── Gated on syncEnabled == true
           │
           ▼ (HTTPS Bearer JWT)
[FastAPI /api/v1/sync/reports] <── AuthenticatedUser ID from token; ReportSummaryPayload schema validation
           │
           ▼
[Supabase public.synced_reports] <── PostgreSQL check constraint: chk_report_payload_privacy
```

### Verified Payload Allowlist (Exact 6 Keys)
1. `formatVersion` (Integer, 1..10)
2. `outcomeState` (String: `indicatorsDetected`, `noIndicatorsMatched`, `limitedCoverage`, `cautious`)
3. `hasAiAnalysis` (Boolean)
4. `indicatorCount` (Integer, 0..1000)
5. `categories` (Array of bounded strings, max 50 items)
6. `source` (String: `messageText`, `screenshot`, `link`, `qrCode`)

### Prohibited Fields Strictly Rejection Matrix

| Prohibited Key | Rejected by Frontend Codec | Rejected by Backend Schema | Rejected by Database Constraint |
|---|---|---|---|
| `text` / `rawText` / `raw_text` | **YES** (StateError) | **YES** (ValidationError 422) | **YES** (`chk_report_payload_privacy`) |
| `excerpt` / `evidence` | **YES** (StateError) | **YES** (ValidationError 422) | **YES** (`chk_report_payload_privacy`) |
| `screenshot` / binary bytes | **YES** (StateError) | **YES** (ValidationError 422) | **YES** (`chk_report_payload_privacy`) |
| `hash` | **YES** (StateError) | **YES** (ValidationError 422) | **YES** (`chk_report_payload_privacy`) |
| `ocrText` / `ocr_text` | **YES** (StateError) | **YES** (ValidationError 422) | **YES** (`chk_report_payload_privacy`) |
| `inputText` / `input_text` | **YES** (StateError) | **YES** (ValidationError 422) | **YES** (`chk_report_payload_privacy`) |
| Extra arbitrary keys (`user_notes`, etc.) | **YES** (StateError) | **YES** (`extra="forbid"`) | **YES** (`report_payload - ARRAY[...] = '{}'`) |

### Empirical Verification on Live Hosted Database
Inspection of real hosted rows in Supabase table `public.synced_reports` (Project `yzqkmoqqvnhfmmrayfko`) confirmed 100% adherence:
```json
{
  "id": "2c5753e2-c6e0-4b5c-9776-ff08ff9758bc",
  "client_report_id": "report-1793541885258522",
  "snapshot_id": "rev-snap-1793541858384039-9055d9",
  "report_payload": {
    "source": "messageText",
    "categories": [],
    "outcomeState": "indicatorsDetected",
    "formatVersion": 1,
    "hasAiAnalysis": true,
    "indicatorCount": 5
  },
  "is_deleted": false,
  "sync_generation": 1
}
```
Zero sensitive message text, OCR, or evidence excerpts exist in cloud storage.

---

## 4. Explicit Opt-In & Cross-Account Isolation Verification

1. **Default State:** New user accounts have `sync_enabled = false` in `public.profiles`. The Account screen on the physical Vivo V2207 confirmed the toggle starts **Disabled (Local only)**.
2. **Cloud AI vs. Backup Separation:** Granting consent for Cloud AI analysis does NOT enable cloud backup. Cloud backup requires explicit user opt-in in Account settings.
3. **Server-Side Ownership Enforcement:** `/api/v1/sync/reports` endpoints use `current_user.user_id` extracted from the validated GoTrue JWT. The client cannot supply, modify, or spoof `user_id`.
4. **Cross-Account Isolation Test (`test_sync_account_isolation_prevents_cross_user_leakage`):**
   - User A and User B both opt in.
   - User A uploads reports (`rep-user-a-1`, `rep-user-a-2`).
   - User B pulls `/api/v1/sync/reports` $\rightarrow$ receives 0 reports.
   - User B executes purge (`DELETE /api/v1/sync/reports`) $\rightarrow$ returns `purgedCount: 0`.
   - User A pulls reports again $\rightarrow$ both reports remain fully intact.
5. **Session Cleardown:** Sign-out and account switching immediately clear pending sync queues and in-memory cursors.

---

## 5. Reliable Push, Pull & Opt-Out Workflows

1. **Idempotent Upsert:** Pushing existing reports repeatedly succeeds with HTTP 200 without creating duplicate database rows (`on_conflict=user_id,client_report_id` and `sync_push_reports` RPC).
2. **Resurrection Prevention:** Purging cloud backup increments `profiles.sync_generation` and records `profiles.sync_purged_at`. Any incoming push with a stale generation or timestamp preceding the purge is skipped.
3. **Local Deletion Independence:** Deleting a report locally pushes a lightweight tombstone (`is_deleted: true`), allowing remote clients to apply the tombstone. Local deletion never deletes cloud backups of other reports, and cloud purge never deletes local reports.
4. **Opt-Out Tombstone Exemption:** When a user opts out of cloud backup (`sync_enabled = false`), new report uploads are blocked with HTTP 403 `sync_opt_in_required`. However, tombstone deletions are explicitly permitted so users can delete previously backed-up items even after opting out.
5. **Honest Restoration on Clean Client:** When pulled onto a fresh client, `SavedReportDetailScreen` renders a clear disclosure banner: *"Cloud summary notice: Raw message text is never uploaded to the cloud for privacy protection."*

---

## 6. Hosted DDL Status Calibration

In accordance with strict reporting rules:
- **Status:** Avatar storage bucket policies (`00009`) and durable v2 reservation tables (`00010`) remain explicitly **OPEN / BLOCKED ON HOSTED DDL** pending owner execution of `HOSTED_MIGRATIONS_00009_00010.sql` in the Supabase Studio SQL editor.
- **Independence:** Cloud sync functionality relies on migrations `00003`, `00007`, and `00008`, which are fully applied and active on the hosted Supabase project. Sync is completely independent of avatar storage and v2 quota tables.

---

## 7. Physical Hardware Evidence (Vivo V2207)

- **Device:** Vivo V2207 (`10AC9R1ABF0013A`), Android 14 (API 34).
- **Execution:** Release APK running with PID 25436.
- **Observed UI Hierarchy:**
  - `Cloud Report Backup`: `android.widget.Switch`, `checked="false"`, `Disabled (Local only)`.
  - Privacy Notice: *"Strict Privacy Protection: Raw message text, images, and evidence quotes are NEVER uploaded. Only metadata summaries (timestamps, category, indicator count) are synced."*
  - Stability: Zero crashes, zero ANRs, zero memory leaks during sync inspection.
- **Artifact:** `trustcue-mobile/docs/evidence/m67_01_account_backup_disabled.png`.

---

## 8. Multi-Repository Acceptance Sign-Off

Module 67 satisfies all acceptance criteria and is ready for Phase 7 continuation:
- **Repairs Closed:** Quota dispatch inference gating verified; telemetry allowlist and metadata value bounding verified.
- **Sync Hardened:** Opt-in strictly enforced; allowlist enforced across all 3 layers; account isolation proven; zero sensitive text leakage.
- **Next Milestone:** Module 68 (Cross-Device Sync Conflict Resolution & Deletion Separation).
