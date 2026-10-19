# TrustCue

TrustCue is a Mobile Application Development project for CS3643, BSCS Semester 5-1, Fall 2026, at Riphah International University.
The application is designed to help people worldwide understand potential scam indicators in suspicious digital communication.

## Project Status
The application foundation is implemented across 49 comprehensive modules:
- **Core Mobile Client (Modules 01–46):** First-run onboarding with remembered safe-use acknowledgment; Home dashboard with direct input method routing (`/input/text`, `/input/screenshot`, `/input/link`); local message text validation (`MessageTextValidator`, 10k code points, 40k UTF-8 bytes); screenshot selection, validation, and local pan/zoom preview (`ImageValidator`, 20MP / 10MB limits); local on-device Latin OCR via Google ML Kit (`google_mlkit_text_recognition: 0.17.1`); shared text review and PII redaction (`LocalSensitiveDataDetector` covering payment cards via Luhn, OTPs, phone numbers, and emails); link inspection and on-device QR decoding (`UrlInspectionService`, `google_mlkit_barcode_scanning: 0.16.1`); Android Sharesheet receiver; pure-Dart deterministic 10-rule heuristics engine (`UrgencyRule`, `CredentialRequestRule`, `AccountThreatRule`, etc.); local assessment synthesis and evidence spans; optional remote Groq AI scam analysis with explicit pre-upload consent; pure-local SQLite report persistence; local report history, full-text search, and filtering (`/history`); Supabase GoTrue authentication, email verification, password recovery, and encrypted hardware token storage (`flutter_secure_storage: 11.2.0`); optional opted-in metadata-only cloud report sync; dedicated Privacy Center (`/privacy`) with retention policies and scoped purgers; Education Center across 10 categories; bilingual English/Urdu localization; user-controlled plain text and PDF export; and extensive accessibility (WCAG 2.1 AA) and native physical device benchmarks.
- **Hosted Backend & Cloud Integration (Module 47):** Production FastAPI web service deployed and live on Render (`https://trustcue-backend.onrender.com`); hosted Supabase PostgreSQL migrations 00007–00008 applied and verified; `ENABLE_CLOUD_SYNC` enabled; atomic purge/push synchronization with generation fencing; and live authenticated AI proxy and quota verification.
- **Android Release Packaging & Signing (Module 48):** Production release configuration with R8 code and resource shrinking (`isMinifyEnabled = true`, `isShrinkResources = true`); custom hardened ProGuard rules; official TrustCue visual identity, adaptive launcher drawables, and branded splash screen; 4096-bit RSA release signing architecture with fail-safe Gradle verification; release artifacts generated (`app-release.aab` and `app-release.apk`) verified with `apksigner` (APK Signature Scheme v2); zero secrets packaged; and live installation, process, and functional verification on physical Vivo V2207 Android 14.
- **Google Play Store Listing & Compliance (Module 49):** Complete Google Play Store listing metadata (title, short description, full description adhering to Google Play 2026 content and metadata guidelines); store graphic assets (512x512 icon, 1024x500 feature graphic, authentic device-captured 9:16 screenshots); exhaustive code-backed Data Safety section and declarations; standalone responsive HTML and Markdown Privacy Policy (`docs/privacy/privacy_policy.html`); compliant two-pathway Account Deletion resource (`docs/privacy/account_deletion.html`); and reviewer access credentials guide and closed testing track strategy (distinguishing prepared artifacts from pending owner actions). See [Play Store Listing](docs/PLAY_STORE_LISTING_MODULE_49.md) and [Data Safety Disclosures](docs/DATA_SAFETY_AND_DISCLOSURES_MODULE_49.md).
- **Final Audit, Real-Device Testing & Handover Dossier (Module 50):** Comprehensive reconciliation of all 50 roadmap modules; execution of real-world test fixtures (`Testing Data/`) spanning 26 scam scenarios, 6 benign counterexamples (No indicators matched in the six tested benign fixtures.), 57 offline-inspected links, 19 screenshot OCR tests, and 9 QR code inspections on physical Vivo V2207 (Android 14 API 34); generalized heuristic rule improvements across 5 local warning rules; 1,040 automated tests passing (885 Flutter, 142 backend, 13 database); strict four-branch repository structure (`main`, `frontend`, `backend`, `database`) enforced with `main` untouched (`a785db8`); reproducible cloud-configured release builds via `frontend/scripts/build_release.ps1` with APK/AAB cryptographic provenance verified; and ongoing device-attached live sync and missing acceptance checks. See [Final Audit & Acceptance Register](docs/FINAL_AUDIT_AND_ACCEPTANCE_REGISTER_MODULE_50.md) and [Fixture Acceptance Matrix](docs/FIXTURE_ACCEPTANCE_MATRIX_MODULE_50.md).

## Repository Structure
- `frontend/`: The Flutter application (TrustCue), including its client services and future local-storage adapters.
- `backend/`: Server APIs, configuration, health probes, and protected AI-provider integration (on `backend` branch).
- `database/`: Database schema, versioned migrations, ownership policies, fixtures, SQL regression suites, and CI (on `database` branch).

## Project Documentation
- [Final Audit & Acceptance Register (Module 50)](docs/FINAL_AUDIT_AND_ACCEPTANCE_REGISTER_MODULE_50.md)
- [Fixture Acceptance Matrix (Module 50)](docs/FIXTURE_ACCEPTANCE_MATRIX_MODULE_50.md)
- [Project State](docs/PROJECT_STATE.md)
- [Module Log](docs/MODULE_LOG.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Data Contracts](docs/DATA_CONTRACTS.md)
- [Design Specification](docs/DESIGN_SPEC.md)
- [Design Brand Board](docs/design/brand_board.svg)

## Development & Phone Verification
To verify the development baseline, navigate to the `frontend/` directory and run the following checks:

```bash
cd frontend
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub -t lib/main.dart
```

These commands assume dependencies are already resolved. On a fresh checkout, run `flutter pub get` with the installed compatible SDK and review any manifest/lockfile changes; GetX is pinned exactly to `4.7.3`.

Module 13 adds `shared_preferences: 2.5.6` and uses `SharedPreferencesAsync`. On Windows, new Pub downloads can stay project-local by setting `$env:PUB_CACHE = Join-Path (Get-Location) '.pub-cache'` in the current terminal before `flutter pub get`; `.pub-cache/` is ignored. This is a process-scoped setting, not a global environment change. Flutter's SDK lock/cache and the existing Gradle cache still require their normal external-directory access.

Startup reads only `trustcue.onboarding.completed_version` (integer `1`), with a labeled loading state and Retry on read failure. Missing, invalid, or old values show onboarding. Successful acknowledgment waits for saving before replacing onboarding with Home; failures stay retryable. About's “Review safe-use guidance” action reuses the content without saving or asking again. Local report history, full-text search, and filtering are implemented on `/history`, and the temporary counter demonstration is retired.

On Windows, run the focused navigation suite first with a bounded runner, then the unfiltered suite (both execute `flutter test --no-pub --reporter expanded`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test.ps1 -Suite navigation -TimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test.ps1 -Suite all -TimeoutSeconds 180
```

Navigation widget tests also have explicit 20-second per-test limits. The runner stores logs in ignored `build/test-runner/`, propagates failures, and stops only its own process tree if the wall-clock limit expires. From the repository root, run `git diff --check` before checkpointing. Tests cover selected accessibility properties, not comprehensive accessibility certification.

### Verified Toolchain
- **Flutter:** 3.47.4 (stable channel)
- **Dart SDK:** 3.13.3
- **NDK:** 30.0.16138531 (installed metadata: r30-beta3; pinned in `frontend/android/app/build.gradle.kts`)
- **Gradle Wrapper:** 9.3.1
- **Java:** Eclipse Adoptium OpenJDK 21.0.12.1 (Temurin-21.0.12.1+1 LTS, hotspot) runtime, Java/Kotlin 17 compilation targets
- **Android SDK:** Compile SDK 36, Target SDK 36, Minimum SDK 24 (verified via `aapt dump badging`, aligned with Google ML Kit requirements)
- **Local SQLite Database:** `trustcue_local.db` (`database_constants.dart`)
- **Platform limits:** iOS identity/build verification remains future work (scaffold bundle ID `com.trustcue.trustcueMobile` differs from Android). Internal route tests do not establish platform deep-link support.

### Physical Phone Testing via VS Code
1. Enable **Developer Options** and **USB Debugging** on your Android device.
2. Connect your device via USB (select "File Transfer" or "PTP" mode if prompted).
3. Open a terminal and run `flutter devices` to ensure your device is listed and authorized. If it says "unauthorized", check your phone screen to accept the USB debugging prompt.
4. Open `trustcue-mobile` as the VS Code workspace root so `.vscode/launch.json` resolves `frontend/` correctly. Go to **Run and Debug** (`Ctrl+Shift+D`).
5. Select **"TrustCue Mobile"** from the dropdown configuration and click the green Play button to launch.
6. Verify the Home dashboard renders the headline ("Understand the signals."), development status notice, and three input option cards. Tap any input method card to inspect its preparation screen, return to Home via back arrow or system back gesture, and check safe-use guidance review. Background/resume should stay responsive while the process remains alive.

### Running Integration Tests
To run automated device integration tests, first get your device identifier by running:
```bash
flutter devices
```
Then run the integration test suite, replacing `<ACTUAL_DEVICE_ID>` with your specific device ID:
```bash
flutter test --no-pub integration_test/app_smoke_test.dart -d "<ACTUAL_DEVICE_ID>"
```

Stop an existing VS Code debug session through its Stop button before installing the integration-test build. For a bounded Windows run, use `powershell -NoProfile -ExecutionPolicy Bypass -File tool/test.ps1 -Suite device -DeviceId "<ACTUAL_DEVICE_ID>" -TimeoutSeconds 600`. The device test body has a two-minute timeout. Afterward, restore the normal application using the command below.

Human confirmation is still needed for Home dashboard visual layout, input option navigation, return-to-home behavior, ordinary background/resume, native back animations, theme readability, enlarged text, rotation, and real keyboard/component-preview behavior. Report each observation explicitly; on failure provide the action, expected/actual result, terminal error, and screenshot or recording. Automated framework back tests do not verify native predictive-back visuals. Integration into `main` remains gated on outstanding verification.

The device test preserves the previous onboarding value, changes only that key, and restores it in teardown. It verifies real-adapter save/read and startup reconstruction; that reconstruction is not a process restart. Widget tests use injected fake storage and never access developer preferences. For human onboarding checks, read/scroll the introduction, acknowledge and continue, normally stop/relaunch without clearing data, confirm onboarding is skipped, then review from About and return. Also check readability and background/resume. No clearing app data or uninstalling is needed.

### Component Preview
To launch the standalone component development preview on your connected phone:
```bash
flutter run -d "ACTUAL_DEVICE_ID" -t lib/dev/component_preview.dart
```

To restore the normal application after checking the preview:
```bash
flutter run -d "ACTUAL_DEVICE_ID" -t lib/main.dart
```
