# TrustCue Data Lifecycle & Privacy Architecture

This document defines the comprehensive data lifecycle, storage locations, retention policies, network boundaries, and deletion semantics across the TrustCue platform (Android mobile client, FastAPI backend, and PostgreSQL database) as enforced in Module 40.

---

## 1. Data Lifecycle Matrix

| Data Category | Storage Location | Retention Duration | Network Boundary | Deletion Semantics & Trigger |
| :--- | :--- | :--- | :--- | :--- |
| **Draft Message Inputs & Pasted Links** | Memory (`GetX` controller state) | Ephemeral: discarded upon leaving input screen, clearing form, or completing analysis | Local device only (never persisted or transmitted prior to review) | Cleared on page navigation, explicit clear button, or app termination |
| **Temporary Screenshots & Image Buffers** | App-private cache directory (`getTemporaryDirectory()`) | Ephemeral: cleaned automatically following text extraction, on orphan sweep, or via Privacy Center | Local device only (image bytes never sent over network) | Manual button in Privacy Center, automated sweep on app startup, or OS cache reclamation |
| **Reviewed Text Snapshots** | App-private SQLite database (`text_snapshots` table) | Persists as long as referencing report exists | Local device only (only sent to remote AI provider upon explicit, affirmative per-request user consent) | Cascades on referencing report deletion, account report clear, guest clear, or retention pruning |
| **Local Saved Reports & Findings** | App-private SQLite database (`reports` table) | User-configured retention policy: `never` (default), `30 days`, `60 days`, or `90 days` | Local device only | Deleted individually via History, in bulk via Privacy Center, or automatically via retention policy |
| **Cloud Report Metadata Summaries** | Remote PostgreSQL database (`public.synced_reports`) | Persists while account active and sync enabled | Transmitted over TLS 1.3 to TrustCue backend (strictly non-sensitive metadata only) | Deleted via "Delete Cloud Backups" RPC, cascade on account deletion, or local deletion with cloud tombstone |
| **Auth Tokens & Session Keys** | Encrypted storage via `FlutterSecureStorage` (Android Keystore / EncryptedSharedPreferences) | Active session duration; cleared on explicit logout, token expiration, or account deletion | Sent via HTTPS `Authorization: Bearer` header to TrustCue backend | Immediately deleted on sign out or account deletion |
| **AI Quota Tracking Records** | Remote PostgreSQL database (`public.profiles`) | Daily sliding window: resets at midnight (00:00 UTC) | Internal backend service database | Reset automatically every 24 hours UTC; purged on account deletion |
| **Application & Server Logs** | Server stdout / container journal (`trustcue-backend`) | Ephemeral container logs; rotated per hosting provider policy | Backend internal only | Zero telemetry or analytics uploaded from mobile app; server logs contain no raw message content |

---

## 2. Platform Security Boundaries & Limitations

### 2.1 Android Sandbox Isolation
- TrustCue stores all local reports, reviewed snapshots, and configuration databases in app-private storage (`/data/user/0/io.github.muhammadtaimoorajmal.trustcue/databases/`).
- Standard Android Linux process UID isolation restricts access to TrustCue exclusively. Unprivileged third-party apps cannot inspect or read these databases.

### 2.2 OS Backup Prohibited (`allowBackup="false"`)
- In `frontend/android/app/src/main/AndroidManifest.xml`, `android:allowBackup="false"` is strictly enforced.
- Android Cloud Backup, Google Drive device backups, and standard `adb backup` commands are explicitly disallowed from copying TrustCue's SQLite databases, secure storage keystores, or user preferences to cloud storage or unauthorized machines.

### 2.3 Transparent Encryption vs App-Private Sandboxing
- **App-Private Storage (Current)**: Local SQLite storage relies on Android kernel sandbox permissions. 
- **Platform Limitation**: Transparent hardware-backed database encryption (e.g., SQLCipher) is not compiled into the current SQLite mobile build. Consequently, on rooted devices with elevated superuser privileges or forensic hardware chip dump tools, unencrypted SQLite tables could theoretically be read. Users on rooted devices are advised of this boundary.

---

## 3. Remote AI Processing Terms & Privacy Guarantees

When a user provides affirmative consent to request Remote Cloud AI analysis:
1. **Single Reviewed Text Snapshot**: Only the explicit, user-reviewed text snapshot (and its input source metadata) is uploaded. Raw screenshots, images, device IDs, or surrounding context are **never** transmitted.
2. **Ephemeral Inference**: The TrustCue backend forwards the text snapshot to Groq cloud API for inference.
3. **Zero Model Training**: Under enterprise AI provider terms, customer inference inputs are not utilized for foundation model training or reinforcement learning.
4. **Zero Data Retention**: The backend and inference provider do not persist the raw analyzed text. Once JSON findings are structured, formatted, and delivered to the client, backend memory is reclaimed.

---

## 4. Cloud Summary Synchronization Boundary (Module 39 Reconciliation)

Cloud synchronization is strictly opt-in and disabled by default. When enabled, it adheres to the following strict allowlist:

### 4.1 Permitted Cloud Summary Fields
- `formatVersion` (Integer format discriminator)
- `outcomeState` (e.g. `needsReview`, `noIndicatorsMatched`, `indicatorsDetected`)
- `hasAiAnalysis` (Boolean flag)
- `indicatorCount` (Integer count of matched indicators)
- `categories` (Alphabetically sorted list of indicator category tags, e.g. `["urgency", "spoofing"]`)
- `source` (Input source discriminator, e.g. `messageText`, `screenshot`, `link`)

### 4.2 Prohibited Cloud Fields (Hard Blocked)
The database enforces check constraints (`chk_report_payload_privacy`) and the backend enforces Pydantic schemas with `extra="forbid"` to strictly reject:
- `raw_text`, `text`, `snapshot`, `ocr_text`, `input_text`
- `evidence`, `excerpt`, `quote`
- `screenshot`, `image`, `bytes`
- `hash`, `digest`, `fingerprint`

---

## 5. Decoupled Consent Architecture

TrustCue enforces absolute decoupling between distinct consent decisions:
1. **First-Run Onboarding Introduction**: Acknowledging introductory guidance does not grant permission for remote AI processing, cloud synchronization, or account creation.
2. **Local Report Saving**: Saving reports to device SQLite does not require an account and never triggers cloud uploads unless cloud sync is independently active.
3. **Remote AI Analysis**: Affirmative consent is captured per-request. Granting AI consent does not enable cloud summary backup.
4. **Cloud Report Backup**: Enabling cloud sync requires an authenticated account and is completely independent of local retention or AI analysis.

---

## 6. Granular Deletion Semantics

| Action | Local SQLite Impact | Cloud PostgreSQL Impact | Unreferenced Snapshots |
| :--- | :--- | :--- | :--- |
| **Single Report Deletion (Local only)** | Deleted immediately | None (no tombstone created) | Deleted if no other report references snapshot |
| **Single Report Deletion (Device & Cloud)** | Deleted immediately | Tombstone uploaded during next sync; summary wiped | Deleted if unreferenced |
| **Clear Account Reports** | All reports for account deleted | None (cloud summaries preserved unless purged) | Cleaned transactionally |
| **Clear Guest Reports** | All unauthenticated guest reports deleted | None (guest reports are never synced) | Cleaned transactionally |
| **Retention Policy Pruning** | Reports older than cutoff deleted | None (retention pruning never issues cloud tombstones) | Cleaned transactionally |
| **Stop Sync & Purge Cloud Summaries** | None (local reports remain intact) | All `public.synced_reports` deleted; sync disabled | None |
| **Permanent Account Deletion** | Local account reports cleared | Profile, auth user, quotas, and synced reports permanently wiped | Cleaned transactionally |

