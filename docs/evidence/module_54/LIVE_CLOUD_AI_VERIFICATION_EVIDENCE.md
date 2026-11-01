# Module 54: Live "Ask Cloud AI" End-to-End Verification Evidence

**Date:** 2026-11-01  
**Target:** Physical Vivo V2207 Android Phone (`10AC9R1ABF0013A`, Android 14 API 34)  
**Release APK SHA-256:** `5BB2E7745D127ADB64470304228D984D5432EBBB7F8869EE60313ACCC296539E`  
**Backend Base URL:** `https://trustcue-backend.onrender.com`  
**Supabase Project:** `https://yzqkmoqqvnhfmmrayfko.supabase.co`  
**Dedicated Test Account:** `play_reviewer@trustcue.internal` (`b2e2d115-7b87-47ee-8f82-9f24d7e72be9`)  

---

## 1. Executive Summary

Module 54 verified the live end-to-end integration of TrustCue's "Ask Cloud AI" functionality on the connected physical Vivo V2207 device using the production-signed release APK.

Key outcomes:
1. **Client & Service Baseline:** Built and installed release APK with R8 code shrinking and ProGuard rules intact. Confirmed backend health (`aiProvider: ok`, `authProvider: ok`).
2. **Defect Resolutions:**
   - Repaired `AuthRepository` lifecycle disposal issue where leaving the account screen caused subsequent AI queries to fail with an unauthenticated status error despite active Supabase session in KeyStore.
   - Repaired R8 reflection stripping bug on `shared_preferences_android` (`NoSuchMethodError` on `SharedPreferencesApiRegistrar.getAll`) by adding explicit ProGuard rules for `io.flutter.plugins.sharedpreferences.**`, `dev.flutter.pigeon.shared_preferences_android.**`, and `kotlin.coroutines.**`.
3. **Draft & Review Gates:** Verified preparation, sensitive detail review, explicit confirmation, and draft discard protection.
4. **Consent Cancel Verification:** Verified that opening the `UploadConsentDialog` and selecting "Keep on-device only" triggers zero backend network calls, leaves the daily quota untouched (15/15), and preserves all local findings.
   - *Measurement methodology:* Verified by client-side execution gating (`granted == null || !granted.granted` terminates before `AnalysisApiClient.analyzeWithAi`), confirmed via ADB logcat monitoring for HTTP traffic, and corroborated by unchanged quota balance.
5. **Consented Live Cloud AI Round-Trip:** Submitted the synthetic test message with explicit affirmative consent. Successfully completed round-trip through Render backend to Groq Cloud LPUs running `qwen/qwen3.8-27b` in ~6.2 seconds. UI displayed AI badge, model provenance, non-guarantee disclosures, and grounded excerpts (`"within 24 hours"`, `"Send your password"`).
6. **Quota Accounting:** Verified quota decrement from 15 of 15 to 14 of 15 remaining queries for the day (corrected typographical reference from 14 of 14).
7. **Offline Graceful Degradation & Online Retries:**
   - With device cellular and Wi-Fi disabled, confirmed local heuristic analysis runs completely intact.
   - Attempting Cloud AI offline displayed non-blocking error banner (`Cloud AI analysis unavailable: Network connection failed. Local analysis results preserved.`) without crashing.
   - Distinguishing online retry: Upon restoring network connectivity, submitting the message `"Urgent: Verify your account now"` online succeeded with live Cloud AI evaluation.
8. **Scope Boundaries:**
   - Fresh registration, email confirmation, account recovery, cloud report sync, account deletion, and provider retention guarantees were NOT verified in this module and remain assigned to their respective roadmap modules.
   - F-18 hardware rate limiting (HTTP 429) and prompt-injection resistance remain explicitly pending for verification in Modules 64–65.
9. **Observed AI Quality Defect:**
   - The Groq AI response included the recommendation: *"If no alert is present, the message is likely fraudulent."*
   - *Flagged Defect:* The absence of an account alert does not establish fraud; this is documented as an open AI-quality issue to be resolved in upcoming AI-quality verification modules.

---

## 2. Test Execution Details

### Synthetic Test Payload 1 (Primary Round-Trip)
```text
Your account will be suspended within 24 hours. Send your password and verification code to https://account-check.example to keep access.
```
- Character count: 137 characters.
- Modality: Text message input (`/input/text`).

### On-Device Local Heuristic Findings
Before cloud submission, local analysis ran 100% on-device and detected 3 warning signs:
1. **Requests for credentials:** `"Send your password"`
2. **Requests for verification codes:** `"Send your password and verification code"`
3. **Account suspension or threats:** `"Your account will be suspended within 24 hours"`

### Consent Dialog & Cancellation Step
- Tapped **Ask Cloud AI** on results screen.
- Consent dialog surfaced:
  - Destination & Transit: HTTPS to TrustCue backend -> Groq Cloud LPUs.
  - Ephemeral Processing: Text only, transient diagnostic logs, no training.
  - No Images Uploaded: Exact text preview shown (137 characters).
- Tapped **Keep on-device only**:
  - Dialog dismissed cleanly.
  - Client early-return ensured zero network requests were dispatched to `/api/v1/analysis/ai` (verified via ADB logcat).
  - Quota verified unchanged at 15 of 15.
  - Local analysis results remained fully displayed and intact.

### Consented Live Cloud AI Submission
- Tapped **Ask Cloud AI** -> **Agree & send**.
- Latency: ~6.2 seconds.
- Provider and Model identified dynamically: `groq-cloud • qwen/qwen3.8-27b`.
- Badging: `[AI-Assisted: Groq]`.
- AI Summary: Identified urgent deadline pressure, credential theft solicitation, and verification code bypass tactics.
- Grounded supporting excerpts:
  - `"within 24 hours"`
  - `"Send your password"`
- Quota: Updated to **14 of 15 analysis queries remaining today**.

### Offline Fallback vs. Online Execution
- **Offline Failure Test:** Network disabled via ADB (`svc wifi disable`, `svc data disable`).
  - Tested message: `"Urgent: Verify your account now"`.
  - Local heuristic successfully flagged urgency/pressure offline.
  - Tapped **Ask Cloud AI** -> **Agree & send**:
    - App displayed non-blocking banner: `Cloud AI analysis unavailable: Network connection failed. Local analysis results preserved.`
    - Primary buttons: `Dismiss` and `Retry AI review`.
    - Zero crashes; local heuristic cards remained interactive.
- **Online Reconnect & Evaluation:** Network re-enabled via ADB (`svc wifi enable`, `svc data enable`).
  - Upon network restoration, the online analysis completed successfully with live Groq AI evaluation.

---

## 3. Verified Artifacts & Checkpoints
- Release APK SHA-256: `5BB2E7745D127ADB64470304228D984D5432EBBB7F8869EE60313ACCC296539E`
- Test Account: `play_reviewer@trustcue.internal` (`b2e2d115-7b87-47ee-8f82-9f24d7e72be9`)
- Screenshots captured on Vivo V2207:
  - `screen_phone_m54_account_check.png` (Account initial authenticated state, 15/15)
  - `screen_phone_m54_review_page.png` (Text review screen with 137 chars)
  - `screen_phone_m54_confirmed.png` (Local review confirmed gate)
  - `screen_phone_m54_results.png` (Local heuristic results: 3 signs)
  - `screen_phone_m54_consent_dialog.png` (Consent dialog with text preview)
  - `screen_phone_m54_consent_declined.png` (Post-cancel preserved local results)
  - `screen_phone_m54_cloud_ai_results.png` (Live Cloud AI response with Groq badge)
  - `screen_phone_m54_ai_findings.png` (AI findings and grounded excerpts)
  - `screen_phone_m54_account_final.png` (Account quota decremented to 14/15)
  - `screen_phone_m54_offline_error.png` (Offline fallback banner)
