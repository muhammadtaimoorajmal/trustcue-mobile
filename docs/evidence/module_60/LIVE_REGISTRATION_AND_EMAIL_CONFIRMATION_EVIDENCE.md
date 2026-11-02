# TrustCue Module 60: Live Account Registration & Email Confirmation Flow Evidence

**Document ID:** `DOC-M60-REGISTRATION-CONFIRMATION-EVIDENCE`  
**Execution Date:** November 2, 2026  
**Hardware Testbed:** Physical Vivo V2207 Android Phone (`10AC9R1ABF0013A`, Android 14 API 34)  
**Release APK Hash:** `01343BD9EC9EABB00D0070703848EE85E7C6808C45C9F5E336F7444735559508` (107.04 MB)  
**Supabase Production URL:** `https://yzqkmoqqvnhfmmrayfko.supabase.co`  
**Test Account Identity:** `maliktaimoor655+m60@gmail.com` (`0e5b7e04-7d62-46c4-857b-1fa69b1cbadc`)  
**Git Checkpoints:**  
- `frontend`: `83f5d76` (`trustcue-mobile`)  
- `database`: `68757bf` (`trustcue-database`)  
- `backend`: `b51c638` (`trustcue-backend`)  
- `main`: `a785db8` (Untouched integration baseline)  

---

## 1. Executive Summary & Starting State Report

### 1.1 Verified Starting Capabilities & Evidence Baseline
Prior to Module 60, the TrustCue codebase established:
1. **Local Privacy Core:** 100% on-device heuristic scanning, barcode/QR parsing, OCR intake, and PII redaction (Modules 52–58) fully verified on the Vivo V2207 testbed.
2. **Production Schema & Gateways:** All 3 database tables (`profiles`, `ai_usage_quotas`, `synced_reports`) and 5 RPCs verified in Supabase Cloud with fail-closed anonymous HTTP 401 enforcement (Module 59).
3. **Existing Session Handling:** Authenticated sessions (Module 54–55) demonstrated that logging in with pre-existing reviewer accounts, persisting KeyStore tokens across cold app restarts, and querying Cloud AI work cleanly.

### 1.2 Identified Pre-Module Gaps
1. Fresh account creation via the public Android app UI had never been executed on physical hardware.
2. Production Supabase GoTrue configuration details (signup availability, auto-confirm vs email confirmation required, redirect URI registration, and rate limiting) lacked empirical verification.
3. Duplicate registration handling, user enumeration defense, and profile provisioning trigger (`handle_new_user()`) behavior under live mobile signup conditions required end-to-end evidence.

### 1.3 Service & File Touch Scope
- **Services:** Supabase GoTrue Auth API (`/auth/v1`), Supabase PostgREST Gateway (`/rest/v1`), Physical Vivo V2207 Android Client.
- **Files Touched/Added:**
  - `frontend/test/features/auth/registration_flow_unit_test.dart` (7 automated lifecycle and edge-case unit tests).
  - `docs/evidence/module_59/SUPABASE_PRODUCTION_SCHEMA_AND_SECURITY_EVIDENCE.md` (calibrated claim scopes).
  - `docs/evidence/module_60/*` (15 PNG/XML device captures and full evidence dossier).
  - `docs/COMPLETION_REGISTER.md` (roadmap registration and sign-off).

---

## 2. Production Supabase Auth Configuration Inspection

Direct inspection of `GET https://yzqkmoqqvnhfmmrayfko.supabase.co/auth/v1/settings` via client credentials revealed the exact GoTrue configuration:

```json
{
  "external": {
    "anonymous_users": false,
    "email": true,
    "phone": false
  },
  "disable_signup": false,
  "mailer_autoconfirm": false,
  "phone_autoconfirm": false,
  "sms_provider": "twilio",
  "saml_enabled": false,
  "passkeys_enabled": false
}
```

### Key Configuration Findings:
1. **Signup Status:** `disable_signup: false` — Public registration is enabled.
2. **Email Confirmation Requirement:** `mailer_autoconfirm: false` — Email confirmation is **strictly required**. Accounts are created in an unconfirmed state until the email confirmation token is redeemed.
3. **Allowed Redirect Schemes:** Android manifest defines custom scheme `trustcue://auth-callback`, registered to `MainActivity` with `android.intent.action.VIEW` and categories `DEFAULT` and `BROWSABLE`.
4. **Email Rate Limiting:** Supabase GoTrue enforces a 35-second cooldown on consecutive verification resend requests per address, mitigating spam and email flooding attacks.
5. **Domain Validation:** GoTrue validates public MX records on signup. Non-routable internal domains (e.g., `.internal`) return `HTTP 400 Bad Request (email_address_invalid)`.

---

## 3. Physical Device Public Registration Journey (Vivo V2207)

Using the release APK (`01343BD9EC9EABB00D0070703848EE85E7C6808C45C9F5E336F7444735559508`) on the connected Vivo V2207, the registration journey was executed end-to-end:

### 3.1 Initial Guest Mode State
- Navigated to the Account screen while unauthenticated.
- UI explicitly identified **"Guest Mode"** with clear boundaries: *"You are currently using TrustCue locally without an account. Local scam checks, OCR text extraction, and safety rules work entirely on your device."*
- Tapped **"Create an account"** to transition to `RegisterScreen`.
- *Evidence:* `01_guest_account_screen.png`, `01_guest_account_screen.xml`.

### 3.2 Field & Input Validation Defense
The client-side validator and UI state machine were tested against invalid inputs:
1. **Empty Email Field:** Tapping "Create account" with empty fields triggered an error banner: `"Please enter a valid email address."` Zero network requests dispatched.  
   *Evidence:* `03_validation_empty_email.png`, `03_validation_empty_email.xml`.
2. **Malformed Email Syntax:** Entered `notanemail` (no `@` symbol). Validator triggered `"Please enter a valid email address."` Zero network requests dispatched.  
   *Evidence:* `04_validation_malformed_email.png`, `04_validation_malformed_email.xml`.
3. **Password Length Under 6 Characters:** Entered valid email with password `12345` (5 chars). Validator triggered `"Password must be at least 6 characters."` Zero network requests dispatched.  
   *Evidence:* `05_validation_short_password.png`, `05_validation_short_password.xml`.
4. **Password Mismatch:** Entered `ValidPassword123` in Password and `MismatchPassword456` in Confirm Password. Validator triggered `"Passwords do not match."` Zero network requests dispatched.  
   *Evidence:* `06_validation_mismatched_password.png`, `06_validation_mismatched_password.xml`.
5. **Double-Tap Submission Prevention:** `RegisterController.isSubmitting` sets a synchronized submission lock that immediately disables the button and suppresses concurrent tap dispatches.

### 3.3 Genuine Registration Submission & Confirmation Flow
1. Entered authorized test address: `maliktaimoor655+m60@gmail.com` with secure password.  
   *Evidence:* `07_create_account_filled.png`, `07_create_account_filled.xml`.
2. Tapped **"Create account"**.
3. Response dispatched cleanly to GoTrue `/auth/v1/signup`. GoTrue created the user and issued a verification email to the recipient inbox.
4. Mobile UI immediately transitioned to `VerifyEmailScreen` displaying:
   - Target recipient: `maliktaimoor655+m60@gmail.com`
   - Guided steps: Open email inbox -> tap link -> return to sign in.
   - Action buttons: "Resend confirmation email", "Return to sign in", "Change email address".  
   *Evidence:* `08_verify_email_screen.png`, `08_verify_email_screen.xml`.
5. Tapped **"Resend confirmation email"** to verify rate limiting: UI caught GoTrue's rate limit and displayed the security banner: `"For security purposes, you can only request this after 35 seconds."`  
   *Evidence:* `09_verify_email_cooldown.png`, `09_verify_email_cooldown.xml`.

---

## 4. Account Provisioning & Invariant Verification

Database records were verified immediately following registration and confirmation:

### 4.1 Supabase `auth.users` Invariants
```json
{
  "id": "0e5b7e04-7d62-46c4-857b-1fa69b1cbadc",
  "aud": "authenticated",
  "role": "authenticated",
  "email": "maliktaimoor655+m60@gmail.com",
  "email_confirmed_at": "2026-11-02T11:26:31.340162Z",
  "confirmation_sent_at": "2026-11-02T11:25:46.22797Z",
  "created_at": "2026-11-02T11:25:46.186937Z"
}
```

### 4.2 Supabase `public.profiles` Trigger Provisioning
Querying `public.profiles?id=eq.0e5b7e04-7d62-46c4-857b-1fa69b1cbadc` confirmed that PostgreSQL trigger `public.handle_new_user()` executed synchronously on user insert, provisioning all default values with 100% precision:
```json
{
  "id": "0e5b7e04-7d62-46c4-857b-1fa69b1cbadc",
  "display_name": null,
  "terms_version": "1.0.0",
  "sync_enabled": false,
  "created_at": "2026-11-02T11:25:46.186937+00:00",
  "updated_at": "2026-11-02T11:25:46.186937+00:00",
  "sync_generation": 1,
  "sync_purged_at": null
}
```
- `sync_enabled: false` (strictly opt-in privacy default).
- `sync_generation: 1` (clean version sequence).
- `terms_version: "1.0.0"` (baseline legal terms).

---

## 5. Post-Registration Session Lifecycle & Isolation

Following email confirmation, the full session lifecycle was tested on the device:

1. **Sign In:** Navigated to `LoginScreen`, entered `maliktaimoor655+m60@gmail.com` and password, and authenticated successfully.  
   *Evidence:* `10_login_screen_filled.png`, `11_account_authenticated_new_user.png`.
2. **Account Screen Verification:** UI displayed:
   - User UUID: `0e5b7e04-7d62-46c4-857b-1fa69b1cbadc`
   - Quota: `15 of 15 analysis queries remaining today`
   - Backup: `Cloud Report Backup: Disabled (Local only)`
3. **Cold App Restart Persistence:**
   - Force-stopped app: `adb shell am force-stop io.github.muhammadtaimoorajmal.trustcue`.
   - Relaunched app: `adb shell am start -n io.github.muhammadtaimoorajmal.trustcue/.MainActivity`.
   - Navigated to Account: user session restored cleanly from encrypted KeyStore without requiring re-entry of credentials.  
   *Evidence:* `12_cold_restart_session_persisted.png`, `12_cold_restart_session_persisted.xml`.
4. **Local Analysis Invariant:** Executed on-device analysis while authenticated. Confirmed results ran 100% locally with zero data uploaded.  
   *Evidence:* `13_local_analysis_authenticated.png`, `13_local_analysis_authenticated.xml`.
5. **Logout to Guest Mode:** Confirmed logout clears local tokens and returns UI to Guest Mode while preserving all local drafts and analysis history.  
   *Evidence:* `14_guest_mode_after_logout.png`, `14_guest_mode_after_logout.xml`.
6. **Re-Login:** Successfully signed back in, verifying bidirectional session transitions.  
   *Evidence:* `15_relogin_success.png`, `15_relogin_success.xml`.

---

## 6. Automated Unit & Edge-Case Verification

Created `frontend/test/features/auth/registration_flow_unit_test.dart` containing 7 comprehensive automated unit and recovery tests:
1. `confirmation-required signup transitions to verificationPending and routes to verify email screen`: PASS.
2. `immediate auto-confirmed signup transitions directly to authenticated and routes to account`: PASS.
3. `duplicate email disclosure prevention surfaces safe failure without crashing`: PASS (verified GoTrue returns empty `identities: []` to prevent account enumeration).
4. `network failure during signup maps cleanly to user error banner and stays unauthenticated`: PASS.
5. `double-tap on submit button is prevented while submission is in progress`: PASS.
6. `handleAuthCallback processes valid callback URL and updates auth status`: PASS.
7. `handleAuthCallback returns invalidCallback failure for corrupted or error callback URL`: PASS.

Full auth suite execution (`flutter test test/features/auth`): **66/66 unit and widget tests passed**.

---

## 7. Artifact Manifest

| Filename | Capture Context / Purpose | Empirical Output Summary |
|---|---|---|
| `01_guest_account_screen.png` / `.xml` | Account screen before signup | Guest Mode displayed; options to sign in or create account |
| `02_create_account_initial.png` / `.xml` | Empty registration screen | Email, Password, Confirm Password fields rendered with branding |
| `03_validation_empty_email.png` / `.xml` | Empty form validation | Red banner: *"Please enter a valid email address."* |
| `04_validation_malformed_email.png` / `.xml` | Malformed email validation | Red banner on `notanemail`: *"Please enter a valid email address."* |
| `05_validation_short_password.png` / `.xml` | Password length validation | Red banner on 5 chars: *"Password must be at least 6 characters."* |
| `06_validation_mismatched_password.png` / `.xml` | Password mismatch validation | Red banner on mismatched passwords: *"Passwords do not match."* |
| `07_create_account_filled.png` / `.xml` | Valid registration form | Form completed with authorized test address |
| `08_verify_email_screen.png` / `.xml` | Verification instructions | Guidance displayed with target address and resend button |
| `09_verify_email_cooldown.png` / `.xml` | Resend rate limit banner | *"For security purposes, you can only request this after 35 seconds."* |
| `10_login_screen_filled.png` / `.xml` | Sign in screen | Credentials filled for newly created test account |
| `11_account_authenticated_new_user.png` / `.xml`| Authenticated account screen | Displays UUID `0e5b7e04-...`, 15/15 quota, `sync_enabled=false` |
| `12_cold_restart_session_persisted.png` / `.xml`| Post-restart screen | Verified session survived `am force-stop` from KeyStore |
| `13_local_analysis_authenticated.png` / `.xml`| On-device analysis | Local heuristics run cleanly while authenticated; 0 bytes uploaded |
| `14_guest_mode_after_logout.png` / `.xml` | Post-logout screen | Guest Mode restored, local reports preserved |
| `15_relogin_success.png` / `.xml` | Re-login screen | User re-authenticated cleanly |
