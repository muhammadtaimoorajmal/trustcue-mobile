# TrustCue Google Play Data Safety & Code-Backed Disclosures (Module 49)

## Executive Summary
This document provides the authoritative, code-backed Data Safety section disclosure matrix for **TrustCue** on the Google Play Console.

Every data disclosure is verified against actual client SDK implementation (`frontend/lib/`), FastAPI backend routing (`backend/src/`), PostgreSQL schema and triggers (`database/migrations/`), and external service-provider terms (Groq, Render, Supabase).

Under Google Play Developer Program Policies:
> *"Collection" means transmitting data off the device. Data that is processed exclusively on-device without transmission does not constitute collection. Conversely, data transmitted off-device is considered collected, even if not stored permanently in the developer's primary database.*

---

## 1. Complete Data Safety Disclosure Matrix

| Google Play Data Category | Specific Data Element | Transmitted Off-Device? | Collected? | Shared with Third Parties? | Handled Ephemerally? | Optional or Required? | Purpose of Collection | Retention Period | Deletion Mechanism |
|---|---|---|---|---|---|---|---|---|---|
| **Personal Info: Email address** | Account registration email | Yes (TLS to Supabase GoTrue Auth) | **Yes** | No | No | Optional (Account creation only; app is 100% functional as guest) | Account Management, App Functionality | Stored for the lifetime of the account | In-App account deletion (`DELETE /api/v1/account`) or external web deletion request |
| **Personal Info: Name / Display Name** | User-configured display name | Yes (TLS to Supabase via backend API) | **Yes** | No | No | Optional (User can leave blank or edit anytime) | Account Management, Personalization | Stored for the lifetime of the account | Editable in-app, purged on account deletion |
| **Personal Info: User IDs** | Supabase UUID (`auth.users.id`) | Yes (TLS to backend / database) | **Yes** | No | No | Optional (Generated upon account signup) | Account Management, Quota Enforcement | Lifetime of account | Cascade deleted on account deletion (`ON DELETE CASCADE`) |
| **Messages: Other in-app messages** | Reviewed text submitted for optional Cloud AI evaluation | Yes (TLS via Render FastAPI backend to Groq Cloud API) | **Yes** | **Yes** (Transmitted to Groq Inc. as service processor) | **No** (Provider diagnostic log window) | Optional (Requires per-request explicit affirmative consent) | App Functionality (Secondary linguistic scam evaluation) | Retained by AI infrastructure provider (Groq) for up to 30 days for abuse monitoring and system diagnostics; not used for model training | Automated purge after Groq diagnostic retention window; not retained in TrustCue database |
| **Messages: Text entered for local checks** | Pasted or typed message text | **No** (Processed 100% on-device) | **No** | No | Yes (Volatile memory session) | Optional | N/A (On-device analysis only) | In-memory session until discarded; local SQLite only if user taps "Save" | User taps "Discard", clears draft, or deletes saved report |
| **Photos & Videos: Photos / Screenshots** | Selected screenshot image files | **No** (Processed 100% on-device by ML Kit Latin OCR) | **No** | No | Yes (App cache directory) | Optional | N/A (On-device text recognition) | Deleted upon text extraction or when discarded by user | Automated cache cleanup; never transmitted off device |
| **App Activity: Stored scam reports (Cloud Sync)** | Cloud report metadata (categories, timestamp, risk level) | Yes (TLS to Supabase PostgreSQL) | **Yes** | No | No | Optional (Strict opt-in: `sync_enabled = false` by default) | App Functionality (Cloud report backup/sync) | Until purged by user or account deletion | In-App "Purge cloud reports", in-app account deletion, or web deletion request |
| **App Info & Performance: Diagnostics / Logs** | Server access logs (HTTP method, route, status code, latency) | Yes (Generated on Render backend hosting server) | **Yes** | No | No | Required for backend API calls | System Health, Abuse & Rate-Limit Monitoring | Bounded Render log retention (~7 days rolling window) | Automated rolling truncation by host platform |
| **Financial Info** | Payment card, bank details, purchase history | **No** | **No** | No | N/A | N/A | None (TrustCue contains zero financial transactions, fees, or billing) | N/A | N/A |
| **Location** | Precise or approximate location | **No** | **No** | No | N/A | N/A | None (Zero location permissions declared or requested) | N/A | N/A |
| **Contacts / Calendar** | Contact lists, phone address book, calendar | **No** | **No** | No | N/A | N/A | None (Zero contact permissions declared or requested) | N/A | N/A |
| **Device or other IDs** | IMEI, Android ID, MAC address, Advertising ID | **No** | **No** | No | N/A | N/A | None (No ad networks, tracker SDKs, or hardware fingerprinting) | N/A | N/A |

---

## 2. Deep Dive: Privacy Guarantees & Code-Level Controls

### 2.1 The Distinction Between Local Storage, Transmission, and Collection
Google Play policy strictly defines **collection** as any off-device transmission. TrustCue distinguishes three execution tiers:
1. **Tier 1: Pure On-Device (No Collection):**
   - Pasted message text, OCR processing of screenshots, heuristic redaction scanning, 10-rule analysis engine, evidence excerpt matching, local report saving in SQLite, and PDF export are executed entirely within the device sandbox.
   - When users use TrustCue as a guest, **zero personal data or message content is transmitted off the device**.
2. **Tier 2: Consented AI Inference (Data Collected in Transit):**
   - When a user explicitly taps "Ask Cloud AI", an affirmative modal ([UploadConsentDialog](file:///D:/ALL%20DATA/PROJECTS/TrustCue/trustcue-mobile/frontend/lib/features/analysis/presentation/widgets/upload_consent_dialog.dart)) presents the exact text that will be uploaded.
   - The text is transmitted via TLS 1.3 to the FastAPI backend at `https://trustcue-backend.onrender.com/api/v1/analysis/ai`.
   - The backend validates the user's daily quota (`ai_usage_quotas` table) and dispatches the prompt to Groq Cloud (`llama-3.3-70b-versatile` / `qwen/qwen3.8-27b`).
   - **Retention Evidence:** The FastAPI backend does not persist the text in any database. However, per Groq's official developer terms, Groq may retain diagnostic logs for up to 30 days for security and abuse investigations before automated deletion. The data is **never used to train artificial intelligence models**.
3. **Tier 3: Opt-In Metadata Cloud Sync (Collected & Stored in PostgreSQL):**
   - Cloud sync is strictly disabled by default (`sync_enabled = false`).
   - If enabled by an authenticated user, only report metadata is synced via `POST /api/v1/sync/reports`.
   - **Database Privacy Enforcement:** PostgreSQL table `synced_reports` enforces table check constraint `chk_report_payload_privacy` (Migration `00007`) which actively rejects any payload containing raw text, OCR fragments, evidence quotations, screenshots, or message hashes. Sync payloads are restricted to a maximum size of 500 KB.

### 2.2 Security Practices Declared in Play Console
1. **Data Encrypted in Transit:**
   - All network communication (FastAPI backend, Supabase GoTrue Auth, and Groq Cloud) uses TLS 1.3 encryption. Unencrypted HTTP traffic is rejected.
2. **Data Encrypted at Rest:**
   - On-device auth tokens are stored using `flutter_secure_storage` backed by the Android Hardware KeyStore (AES-GCM encryption).
   - Hosted Supabase database uses disk-level encryption (AES-256) and Row Level Security (RLS) policies.
3. **Data Deletion Mechanism Provided:**
   - Users can delete their account and all associated cloud data directly within the app (`Account -> Delete Account`).
   - An external web-based deletion request page is hosted at `https://muhammadtaimoorajmal.github.io/trustcue-mobile/privacy/account_deletion.html` (and available as Markdown/HTML in the repository) to satisfy Google Play's Two-Pathway Deletion Rule.

---

## 3. Third-Party SDK & Dependency Audit

| Dependency / SDK | Purpose | Network Activity? | Data Transmission / Telemetry Audit |
|---|---|---|---|
| `google_mlkit_text_recognition: 0.17.1` | On-device Latin OCR | **No** | Runs bundled on-device model (`com.google.android.gms.vision`). No images or OCR text uploaded. |
| `google_mlkit_barcode_scanning: 0.16.1` | QR code decoding | **No** | Runs on-device Barcode scanner. No network queries. |
| `sqflite: 2.4.4+2` | Local SQLite database | **No** | Operates exclusively on local file `/data/user/0/.../databases/trustcue.db`. |
| `flutter_secure_storage: 11.2.0` | Hardware KeyStore wrapper | **No** | Encrypts credentials locally with Android Keystore. |
| `supabase_flutter: 2.18.3` | Authentication client | **Yes** | Connects to configured Supabase HTTPS endpoint for signup, login, session refresh, and token management. |
| `http: 1.6.0` | Backend API client | **Yes** | Communicates with `https://trustcue-backend.onrender.com` over TLS. |
| `pdf: 3.13.1` | Local document export | **No** | Generates PDF files locally in memory and writes to sandboxed cache directory. |
| `share_plus: 13.3.1` | System ShareSheet launcher | **No** | Invokes Android `ACTION_SEND` intent with temporary file URI. |
| `shared_preferences: 2.5.6` | App preferences | **No** | Stores non-sensitive preferences (`hasCompletedOnboarding`, theme, locale). |

**Conclusion:** TrustCue bundles **zero advertising SDKs, zero analytics trackers, and zero third-party device profiling libraries**.

