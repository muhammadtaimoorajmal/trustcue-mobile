# TrustCue Demonstration & Rehearsal Verification Record

**Course:** CS3643 — Mobile Application Development (BSCS Semester 5-1, Fall 2026)  
**Institution:** Faculty of Computing & Applied Sciences, Riphah International University  
**Student:** Muhammad Taimoor Ajmal (SAP ID: 63461)  
**Instructor:** Mr. Muhammad Shariq Hasnain  
**Presentation Target Date:** Wednesday, 21 October 2026  
**Document ID:** `DOC-DEMO-VERIFICATION-RECORD-20261021`  
**Classification:** Authoritative Technical Rehearsal & Artifact Audit  

---

## 1. Executive Summary & Verification Checkpoints

This document formally records the technical verification, artifact provenance, and live rehearsal outcomes for the TrustCue classroom demonstration and progress viva. Every technical claim, command, and observation in the demonstration scripts has been reconciled against genuine source code, automated test suites, and hardware execution on the target Android handset.

### 1.1 Repository & Branch Checkpoint Matrix

| Tier / Worktree | Owning Git Branch | Authoritative Commit SHA | Verification Status & Cleanliness |
|---|---|---|---|
| **Mobile Client (`trustcue-mobile`)** | `frontend` | `2009246` (code: `850b3da`) | Clean, synchronized with `origin/frontend`; GitHub Actions CI passing (Run `39304722716`) |
| **Backend API (`trustcue-backend`)** | `backend` | `b51c638` | Clean, synchronized with `origin/backend`; Render web service deployed |
| **Database Migrations (`trustcue-database`)** | `database` | `534f66a` | Clean, synchronized with `origin/database`; Supabase PostgreSQL migrations 00001–00008 active |
| **Production Baseline (`main`)** | `main` | `a785db8` | **Strictly untouched** pre-integration baseline |

### 1.2 Four-Branch Governance Enforcement
* Exactly four branches exist: `main`, `frontend`, `backend`, and `database`.
* No temporary or integration branches exist in the remote or local repositories.
* The `main` branch remains locked at commit `a785db8` until formal course evaluation and instructor approval.

---

## 2. Release Binary & Hardware Provenance

### 2.1 Release Binary Verification
* **Artifact Path:** `frontend/build/app/outputs/flutter-apk/app-release.apk`
* **File Size:** `111,625,006` bytes (106.45 MB)
* **Cryptographic SHA-256 Digest:** `FF02F2A79A4D1755EA1CF354BAB434658397DAAE760E7736622E90CBB16D006D`
* **Signing Architecture:** 4096-bit RSA keystore (`trustcue-release-key.jks`)
* **Signature Scheme:** APK Signature Scheme v2 verified (`true` via `apksigner.bat verify --verbose`)
* **Target Build Settings:** Compile SDK 36, Target SDK 36, Min SDK 24, R8 code/resource shrinking enabled.

### 2.2 Application Code Equivalence Audit
* A git diff audit of application code between commit `803dc7b` (when the APK was compiled) and the current frontend HEAD (`2009246`) confirms:
  ```bash
  git diff 803dc7b..850b3da -- frontend/lib/
  # Result: 0 files changed, 0 insertions, 0 deletions
  ```
* **Conclusion:** The compiled release APK on disk and installed on the test handset contains the **exact, identical application source code** as the current Git repository HEAD. Subsequent commits (`850b3da` and `2009246`) added automated test fixtures (`module_50e1_fixtures_test.dart`) and updated documentation registers.

### 2.3 Physical Hardware Test Bed
* **Device Model:** Vivo V2207 (`model:V2207`, `product:V2207`)
* **ADB Device Identifier:** `10AC9R1ABF0013A`
* **Operating System:** Android 14 (API Level 34, Linux kernel 5.10.198, ARM64-v8a)
* **Display Resolution:** 720 x 1612 pixels (Density: 320 dpi)
* **Installed Application ID:** `io.github.muhammadtaimoorajmal.trustcue`

---

## 3. Automated Test Suite Reconciliation

| Test Domain | Execution Command | Tests Passed | Regressions / Failures | Static Analyzer Status |
|---|---|---|---|---|
| **Flutter Mobile Client** | `flutter test --no-pub` | **981** | 0 | 0 issues (`flutter analyze --no-pub`) |
| **Release Build Harness** | `pwsh scripts/test_build_release.ps1` | **8** | 0 | Exit code 0, 8/8 tests pass |
| **Backend API Service** | `pytest backend/tests` | **142** | 0 | 0 lint issues (`ruff check`) |
| **Database Migrations/RLS**| `python -m unittest discover database/tests` | **13** | 0 | SQL regression suites pass |
| **Cross-Repository Total** | — | **1,136** | **0** | **100% Pass Rate** |

### Remote GitHub Actions CI Confirmation
* **Run ID:** `39304722716`
* **Tested Commit:** `850b3da6ef1fdc47a29cf079ba39ae2e1fcccfa8`
* **Run URL:** `https://github.com/muhammadtaimoorajmal/trustcue-mobile/actions/runs/39304722716`
* **Run Conclusion:** `success` across all 11 stages (including formatting, static analysis, full 981-test suite, and debug APK compilation).

---

## 4. Rehearsal Verification Matrix (Synthetic Demo Inputs)

Every demonstration input from `docs/demo/DEMO_INPUTS.txt` was rehearsed and verified on physical hardware running the release APK.

| ID | Input Type / Name | Input Route | Actual Observed Outcome | Grounded Evidence / Observation | Verified Status |
|:---:|---|---|---|---|:---:|
| **FIX-01** | USPS Delivery Fee (`$1.99`) | Message Editor (`/input/text`) | **Indicators Detected** (1 Warning Sign) | Category: Requests for payment.<br>Quote: `"Pay $1.99 redelivery fee"` (literal `$` preserved). | **Demo-Ready** |
| **FIX-02** | Urgent Bank Threat | Guided Practice (`/guide`) or Text Input | **Indicators Detected** (3 Warning Signs) | Category 1: Urgent language ("URGENT", "within 24 hours").<br>Category 2: Account threat ("suspended", "permanently closed").<br>Category 3: Credential request ("login credentials"). | **Demo-Ready** |
| **FIX-03** | Benign Family Grocery | Message Editor (`/input/text`) | **No Indicators Detected** (Calm Card) | 0 warning signs triggered.<br>Honest limitation notice displayed: no indicators $\neq$ 100% safe. | **Demo-Ready** |
| **FIX-04** | Clean HTTPS URL (`example.com`) | Link Inspector (`/input/link`) | **Valid HTTPS Link** | Protocol: HTTPS.<br>Host: `example.com`.<br>Two-step browser confirmation modal verified. | **Demo-Ready** |
| **FIX-05** | Structural Warning URL | Link Inspector (`/input/link`) | **Structural Anomaly Warnings** | Direct numerical IP: `37.77.150.214`.<br>Non-standard port: `8080`.<br>Unencrypted HTTP protocol flagged. | **Demo-Ready** |
| **FIX-06** | Dangerous URI (`javascript:`) | Link Inspector (`/input/link`) | **Invalid / Rejected Scheme** | Red banner: *"Cannot be opened externally"*. Launch button strictly disabled. | **Demo-Ready** |
| **FIX-07** | Screenshot Latin OCR | Screenshot Picker (`/input/screenshot`)| **On-Device Text Extracted** | Google ML Kit on-device Latin OCR processes 1080p image in ~930ms; text populated in Review Screen. | **Demo-Ready (Staged)** |
| **FIX-08** | QR Code Barcode | QR Scanner in Link Inspector | **Destination URL Decoded** | Google ML Kit Barcode Scanning decodes payload offline; loads into Link Inspector. | **Demo-Ready (Staged)** |

---

## 5. Live Cloud Infrastructure vs. Offline Capabilities

### 5.1 What Operates 100% Offline (Zero Internet Required)
The core application is completely functional without Wi-Fi, mobile data, or external servers:
1. Message text input, validation, and character bounds enforcement.
2. Screenshot intake, pan/zoom preview, and on-device Latin OCR extraction.
3. Link inspection, protocol validation, IP detection, and dangerous scheme quarantine.
4. On-device QR barcode decoding.
5. Sensitive data redaction review (Luhn-checked payment cards, phones, emails, OTPs).
6. Local 10-family rule engine execution and evidence excerpt extraction.
7. Assessment outcome synthesis (Indicators Detected vs. No Indicators Detected).
8. Contextual guidance and safe verification recommendations.
9. Local SQLite database persistence (`trustcue_local.db`), history browsing, search, and deletion.
10. In-app User Guide (all 6 topics) and Safe Guided Practice engine.
11. Sanitized Plain Text (`.txt`) and PDF report export with Android ShareSheet.
12. Bilingual English and Urdu localization switching.

### 5.2 What Requires Network & Cloud Infrastructure
1. **Optional Consented AI Scam Analysis:**
   * Endpoint: `POST /api/v1/analysis/ai` hosted on Render (`https://trustcue-backend.onrender.com`).
   * Provider: Groq Cloud API (`llama-3.3-70b-versatile`).
   * Requires: Active internet, authenticated user session, explicit per-request upload consent.
   * Reality & Boundaries: Render free-tier web services enter sleep mode after 15 minutes of inactivity; initial cold start takes approximately 50 seconds.
2. **Optional Cloud Report Backup (Sync):**
   * Endpoint: `POST /api/v1/sync/reports` communicating with Supabase PostgreSQL (`https://yzqkmoqqvnhfmmrayfko.supabase.co`).
   * Requires: Active internet, authenticated user session, explicit sync opt-in toggle in Settings.
   * Reality & Boundaries: Sync transmits metadata only (timestamps, counts, indicator categories); raw message text and evidence quotes are **never** transmitted to the sync table.
3. **User Authentication & Account Management:**
   * Service: Supabase GoTrue Auth.
   * Reality & Boundaries: Free-tier Supabase project uses built-in rate-limited SMTP (max 3-4 emails/hour). Live signup during class is discouraged; a pre-authenticated session should be used if cloud features are shown.

---

## 6. Status of Paused Roadmap Modules

To guarantee presentation focus and preserve engineering stability before the viva, all development on unfinished modules is formally **PAUSED**:

| Module ID | Module Title | Current Status | Viva Handling Strategy |
|:---:|---|:---:|---|
| **50E.2** | Screenshot & OCR Corpus Testing (19 images) | **PAUSED** | Show rehearsed representative screenshot (`images (1).jpg`). Explain that full 19-image corpus verification is scheduled. |
| **50E.3** | QR Code Corpus Testing (9 QR images) | **PAUSED** | Show rehearsed representative QR fixture. Explain that full 9-QR corpus verification is scheduled. |
| **50F** | Fresh Registration, Email Recovery & Live AI Lifecycle | **PAUSED** | Explain architecture via OpenAPI spec and code tour. Do not attempt live email confirmation in front of class. |
| **50G** | History, Export, Privacy & Remaining Layout Checks | **PAUSED** | Demonstrate locally verified SQLite history, TXT/PDF export, and Privacy Center. |
| **50H** | Independent-Device Testing & Approved Main Integration | **PAUSED** | Explain four-branch governance and release candidate gating. Keep `main` untouched (`a785db8`). |

---

## 7. Known Limitations & Technical Boundaries

1. **Deterministic Heuristics, Not General AI:** The local analysis engine executes deterministic pattern rules. It does not possess semantic comprehension; it identifies structured warning signs.
2. **No-Match Disclaimers:** A "No indicators detected" outcome does not mean a message is guaranteed safe; novel scams or benign-looking lures may not trigger known rules.
3. **Latin OCR Restriction:** Google ML Kit's bundled on-device OCR model supports Latin-based alphabets. It cannot transcribe Nastaliq Urdu or Arabic text from images.
4. **Android Sandbox Protection:** Local SQLite storage (`trustcue_local.db`) is protected by Linux UID sandboxing and `android:allowBackup="false"`. It cannot be inspected via standard unrooted ADB shell commands.
5. **Session Token Security:** Refresh tokens are stored using `flutter_secure_storage` backed by Android KeyStore hardware-backed AES-GCM encryption, distinct from the unencrypted local SQLite database.

---

**Audited & Verified By:** Antigravity Pairing Assistant  
**Lead Developer / Student:** Muhammad Taimoor Ajmal (SAP ID: 63461)  
**Verification Date:** October 20, 2026  
**Presentation Status:** READY FOR CLASSROOM DEMONSTRATION & VIVA DEFENSE  
