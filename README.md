# TrustCue

TrustCue is a Mobile Application Development project for CS3643, BSCS Semester 5-1, Fall 2026, at Riphah International University.
The application is designed to help people worldwide understand potential scam indicators in suspicious digital communication.

## Project Status
The current foundation includes first-run onboarding with a locally remembered safe-use acknowledgment, review from About, the product Home dashboard with input method navigation cards (`/input/text`, `/input/screenshot`, `/input/link`), functional local message text entry and validation on `/input/text` (`MessageTextValidator`, dual limits of 10,000 code points and 40,000 UTF-8 bytes, CRLF line normalization, and in-memory `TextSnapshot` preparation), screenshot selection, validation, and local pan/zoom preview on `/input/screenshot` (`ImageValidator`, PNG/JPEG magic byte validation, dimensions <= 20MP, size <= 10MB, and transactional temporary-file lifecycle management without touching user gallery originals), local on-device Latin text recognition via Google ML Kit (`google_mlkit_text_recognition: 0.17.1`, Latin script notices, selectable read-only extracted text, unreviewed accuracy banner, retry/manual entry error fallbacks, and native reader lifecycle coordination), typed input and analysis data contracts (`TextSnapshot`, `EvidenceReference`, `AnalysisFinding`, `AnalysisReport`, `AnalysisService`, and version-1 codecs), GetX state/bindings and exact named-route resolution, fallback screens, light/dark themes, responsive components, a separate component preview, and widget/device tests. The temporary counter demonstration is retired. Text correction/redaction, actual scam analysis, AI integration, report storage, and backend features are not implemented yet. The acknowledgment is an introduction, not consent to upload content. See the module log for Module 12A's routing repair, Module 13's onboarding checkpoint, Module 14's dashboard implementation, Module 15's data contracts, Module 16's message text entry, Module 17's screenshot preview, and Module 18's on-device OCR.

## Repository Structure
- `frontend/`: The Flutter application (TrustCue), including its client services and future local-storage adapters.
- `backend/`: Future server APIs and protected AI-provider integration.
- `database/`: Future database definitions, migrations, synthetic fixtures, and documentation.

## Project Documentation
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

Startup reads only `trustcue.onboarding.completed_version` (integer `1`), with a labeled loading state and Retry on read failure. Missing, invalid, or old values show onboarding. Successful acknowledgment waits for saving before replacing onboarding with Home; failures stay retryable. About's “Review safe-use guidance” action reuses the content without saving or asking again. The temporary analysis-unavailable wording must be updated only when analysis is implemented. General preferences/history are not implemented, and the temporary counter demonstration is retired in Module 14.

On Windows, run the focused navigation suite first with a bounded runner, then the unfiltered suite (both execute `flutter test --no-pub --reporter expanded`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test.ps1 -Suite navigation -TimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test.ps1 -Suite all -TimeoutSeconds 180
```

Navigation widget tests also have explicit 20-second per-test limits. The runner stores logs in ignored `build/test-runner/`, propagates failures, and stops only its own process tree if the wall-clock limit expires. From the repository root, run `git diff --check` before checkpointing. Tests cover selected accessibility properties, not comprehensive accessibility certification.

### Verified Toolchain
- **Flutter:** 3.47.4
- **Dart SDK:** 3.13.3
- **NDK:** 30.0.16138531 (installed metadata: r30-beta3; pinned in `frontend/android/app/build.gradle.kts`)
- **Gradle Wrapper:** 9.3.1
- **Java:** 25 runtime, Java/Kotlin 17 compilation targets
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
