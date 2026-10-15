# Module Log

This log tracks the progress of TrustCue's implementation across approximately 100 modules.

## Modules 01-02: Initial Foundation & Android Build Repair
- **Scope:** Generate Flutter scaffold, establish repository folders, configure ignore rules, and repair the Android build failure (pinned NDK).
- **Branch:** `frontend`
- **Checks Performed:** `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. All passed.
- **Manual Verification:** Phone physical launch pending.
- **Commit:** Shared Modules 01-03 foundation checkpoint `7578e65` (consolidated, not separate commits).
- **Status:** Pending manual physical-phone test.

## Module 03: Verified Checkpoints & Project Continuity
- **Scope:** Establish durable project context (`PROJECT_STATE.md`, `MODULE_LOG.md`), update agent rules, verify `.vscode/launch.json` trackability, and prepare for foundation commit and `main` integration.
- **Branch:** `frontend`
- **Checks Performed:** Git status, `.gitignore` validation.
- **Manual Verification:** N/A (Documentation & Git ops).
- **Status:** Complete (Commit `7578e65`).

## Module 04: Configure Application Identity
- **Scope:** Push existing Modules 01-03 progress, then configure TrustCue application identity (Android namespace, applicationId, label, package).
- **Branch:** `frontend`
- **Checks Performed:** `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. All passed.
- **Manual Verification:** Visual check of phone launch pending.
- **Status:** Complete (Commit `3db7ab5`). Pending manual visual verification and `main` integration.

## Module 05: Flutter Code Structure and Safe Refactoring
- **Scope:** Extract app entry (`trustcue_app.dart`), theme (`app_theme.dart`), and home screen (`home_screen.dart`). Setup architecture conventions.
- **Branch:** `frontend`
- **Checks Performed:** `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. All passed.
- **Manual Verification:** Visual check of phone launch pending.
- **Status:** Complete (Commit `6e06bb3`). Pending manual visual verification and `main` integration.

## Module 06: GetX State Management, Dependency Registration, and Routing
- **Scope:** Add GetX (the actual checkpoint pins `get: 4.7.3`), define centralized routes/pages, implement `HomeController` and `HomeBinding`, and refactor `HomeScreen` to `GetView`.
- **Branch:** `frontend`
- **Checks Performed:** `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. All passed.
- **Manual Verification:** Visual check of phone launch pending.
- **Status:** Checkpoint `e4bf1f2` pushed. Pending manual visual verification and `main` integration.

## Module 07: Physical-Device Verification and Foundation Checkpoint
- **Scope:** Add `integration_test` dependency, create `app_smoke_test.dart` to verify title and counter behavior, execute test on physical device, and verify ordinary application launch.
- **Branch:** `frontend`
- **Checks Performed:** `flutter pub get`, `dart format`, `flutter analyze`, `flutter test`, `flutter test integration_test/app_smoke_test.dart -d <ACTUAL_DEVICE_ID>`, `flutter build apk --debug -t lib/main.dart`. All passed.
- **Manual Verification:** Background/resume behavior and home screen check pending.
- **Status:** Checkpoint `0fd789f` pushed. Integration into `main` paused until manual background/resume verification.

## Module 08: Visual Direction and Brand Specification
- **Scope:** Define authoritative design specification, product language, accessibility requirements, and create a static SVG visual reference board.
- **Branch:** `frontend`
- **Checks Performed:** Validation of color contrast ratios, SVG syntax, and documentation.
- **Manual Verification:** Visual inspection of `docs/design/brand_board.svg` is pending human review.
- **Status:** Complete (Commit `815f029`). Integration into `main` paused until manual background/resume verification (Module 07) is completed.

## Module 09: Light/Dark Themes, Color System, and Typography
- **Scope:** Implement the visual direction from Module 08 in the Flutter app using `ThemeData` and `ThemeExtension`. Configure `ThemeMode.system`, define light and dark palettes (`AppColors`, `AppSemanticColors`), setup text themes, and update `TrustCueApp` and `HomeScreen`.
- **Branch:** `frontend`
- **Checks Performed:** `flutter test` (added theme switching, contrast calculation, and layout text scaling tests), `flutter build apk --debug`. All passed.
- **Manual Verification:** Theme-switching readability, text sizing, and counter persistence check is pending on physical device.
- **Status:** Complete (Commit `7ad3ecb`). Integration into `main` paused until manual background/resume verification (Module 07) is completed.

## Module 10: Reusable UI Components and Development Preview
- **Scope:** Build foundational, tested shared UI components (`AppButton`, `AppTextField`, `AppCard`) conforming to the design spec. Provide a separate development preview (`lib/dev/component_preview.dart`).
- **Branch:** `frontend`
- **Checks Performed:** `flutter pub get`, `dart format`, `flutter analyze`, `flutter test` (including accessibility and text-scaling checks), `flutter build apk --debug`. All passed.
- **Manual Verification:** Component preview testing (button states, text entry, theme switching) is pending on the physical device.
- **Status:** Complete (Commit `6c66557`). Integration into `main` paused until manual verification requirements are satisfied.

## Module 11: Responsive Layouts, Safe Areas, Spacing, and Keyboard Handling
- **Scope:** Define shared spacing values (`AppSpacing`) and create a responsive page wrapper (`AppPageBody`) to ensure safe area compliance, maximum content width (720px), and scrollable behavior under keyboard insets. Applied this to `HomeScreen` and the development preview.
- **Branch:** `frontend`
- **Checks Performed:** `flutter pub get`, `dart format`, `flutter analyze`, `flutter test` (added responsive bounding, padding, safe area, and simulated keyboard scrolling checks in `app_page_body_test.dart`), and built normal and preview debug APKs.
- **Manual Verification:** Human verification of portrait/landscape scaling, font sizing readability, and real keyboard interaction on a physical device is pending.
- **Status:** Checkpoint `1dc5d3d` pushed. Integration into `main` remains paused.

## Module 12: Application Navigation and Route Handling
- **Scope:** Define centralized routing for application screens (`/`, `/about`, `/not-found`). Implement informational `AboutScreen` and resilient `NotFoundScreen`. Configure `unknownRoute` for bounded recovery. Update Home to launch About. Ensure route fallback logic protects against invalid state and maintains existing dependencies.
- **Branch:** `frontend`
- **Checks Performed:** `flutter test` (added navigation testing for expected routes, fallback routing, recovery to Home, state preservation, and system back behaviors), `flutter build apk --debug`.
- **Manual Verification:** Human verification of navigating to About, pressing app-bar back versus system back (confirming counter state preservation), and verifying correct animation transitions is pending on a physical device.
- **Status:** Original checkpoint `f62d35a` pushed. Its completion claim was qualified by the handover audit: explicit `/not-found` navigation did not prove unknown-route handling, and the saved follow-up tests stalled or failed. Module 12A repairs these deficiencies separately. Integration into `main` remains paused.

## Module 12A: Navigation Repair, Reliable Tests, and Documentation Reconciliation

- **Baseline:** `frontend` at `f62d35aa701873f6fb3ad22f2a90fb9bc0963046`, matching the live remote. Incorporated the existing unfinished unknown-route test corrections and EOF whitespace findings. The owner confirmed no additional unsaved changes in the three overlapping files; terminal analysis cannot inspect the VS Code Problems panel or unsaved buffers.
- **Reproduction:** The original unsupported-initial-route test failed before the repair. Installed GetX 4.7.3 matches registered ancestors (`/` or `/about`) for unsupported descendants; `unknownRoute` alone did not enforce the intended policy.
- **Correction:** Central exact-path resolution from `AppPages.pages` for both named and initial routes, retaining `/` as Home and creating `GetPageRoute` instances with their existing bindings. Query strings do not select destinations; trailing slashes are not aliases. No package-cache edits, dependency upgrades, or platform deep links.
- **Recovery:** Retained the working recovery implementation after verifying the actual stack and controller identity. Existing Home survives intervening About/fallback removal. With Home absent, the binding registers a fresh controller; prior controllers are disposed. Repeated recovery leaves one Home.
- **Tests:** Replaced blocking navigation-result awaits with expectations attached immediately and awaited after pop/removal. All navigation tests have explicit 20-second limits. The Windows runner bounds the whole process and keeps logs in ignored build output. Real UI taps/back requests remain covered; repeated production About callbacks are tested separately without suppressing missed-hit warnings.
- **Automated code checks:** PASS: 17 focused navigation tests; all 35 unfiltered widget tests (including the existing 18 foundation tests); non-writing format check across 23 files; `flutter analyze --no-pub` with no issues; normal `flutter build apk --debug --no-pub -t lib/main.dart`; `git diff --check` and staged whitespace checks. No manifest, lockfile, identity, theme, or toolchain changes.
- **Mechanical formatting only:** `AppPageBody`, Home/About/NotFound screens, and the two shared-widget test files. Navigation/application composition and the device smoke test have functional changes. Removed the navigation test's unused imports. Documentation now distinguishes the implemented dark app-bar/action foreground from the page surface and avoids accessibility-certification claims.
- **Device verification: BLOCKED / NOT RUN.** `flutter devices` confirmed V2207 (`10AC9R1ABF0013A`, Android 14/API 34, arm64). An existing VS Code Flutter debug session (PID 15140 at inspection) still owns this app/device. The owner was asked to stop it through VS Code; no stop confirmation was received before this checkpoint, and the process remained present. The repair did not terminate it or install over its running app. The extended device integration test and subsequent normal-app launch remain pending; this is not a device-test pass. Code checks permit this development checkpoint, but device verification remains incomplete.
- **Human observations:** Still pending: About app-bar/native system back with counter retention, ordinary background/resume, predictive-back visuals, theme readability, enlarged text, rotation, and component-preview/keyboard behavior. Counter restoration after process termination remains outside scope.
- **Checkpoint:** This separate repair commit follows the original Module 12 checkpoint; its final SHA and live remote comparison are reported in the completion report. `main`, `backend`, and `database` remain unchanged. Module 13 has not started.

## Module 13: First-Run Onboarding, Safe-Use Guidance, Build Repair, and Verification
- **Scope:** Implement startup routing (`/startup`), onboarding screen (`/onboarding`), preference abstraction (`OnboardingPreferences`), version tracking (`trustcue.onboarding.completed_version: 1`), "Review safe-use guidance" (`/safe-use`) from About, resolve Android incremental cache build failure, verify automated tests and device integration.
- **Branch:** `frontend`
- **Build Repair Diagnosed & Resolved:**
  - Cause: Stale background Gradle/Kotlin compile daemons holding open locks on incremental cache `.tab` files in `frontend/build/shared_preferences_android/kotlin/compileDebugKotlin/cacheable/caches-jvm/jvm/kotlin`, leading to `Could not close incremental caches` / `Storage for [...] is already registered`.
  - Resolution: Gracefully stopped the Gradle daemon (`.\gradlew.bat --stop`) and deleted the stale plugin build output `frontend/build/shared_preferences_android/`. Verified `flutter build apk --debug --no-pub -t lib/main.dart` succeeds cleanly (exit code 0).
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (30 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (51/51 tests passed, including 16 onboarding tests, 17 exact-path navigation tests, and 18 foundation tests).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build/app/outputs/flutter-apk/app-debug.apk` built in 74.3s).
  - `git diff --check`: PASS (clean whitespace).
- **Device Verification:** Verified debug APK build and manual install on connected physical device `V2207` (`10AC9R1ABF0013A`, Android 14 / API 34). Automated integration-test runner timed out waiting for test listener.
- **Human Verification:** Physical phone checklist provided for first-run onboarding acknowledgment, relaunch skipping, review from About, back-navigation retention of counter, and ordinary background/resume.
- **Status:** Complete (Checkpoint `68aa084`). Integration into `main` remains paused.

## Module 13A: Completion Report Reconciliation and Verification Record
- **Scope:** Reconcile factual discrepancies in the Module 13 completion report against committed source, actual toolchain configurations, live git branch references, and Android device behavior. No source code modifications required; code already adheres strictly to agreed specifications.
- **Branch:** `frontend`
- **Reconciliation Audit:**
  - **Onboarding Structure:** The completion report claimed a 3-page carousel with Skip/Next/dots/Get Started. Inspection of `onboarding_screen.dart` confirms the committed implementation is a single scrollable screen with an acknowledgment checkbox and "Continue to TrustCue" primary button. No carousel was built or exists in source.
  - **Preference Storage:** The completion report claimed a boolean key `trustcue.onboarding_completed`. Inspection of `onboarding_preferences.dart` and `startup_screen.dart` confirms the committed contract uses `SharedPreferencesAsync` with integer key `trustcue.onboarding.completed_version` and value `1`.
  - **Safe-Use Review:** The completion report claimed a separate `SafeUseScreen`. The committed implementation routes `/safe-use` (`AppRoutes.guidance`) to `OnboardingScreen(mode: OnboardingMode.review)`, which provides read-only guidance without acknowledgment or preference writes.
  - **Android Identity & Launch:** The completion report claimed launch targeted `com.trustcue.trustcue_mobile`. Inspection of `build.gradle.kts` and `aapt dump badging` confirms the application ID is `io.github.muhammadtaimoorajmal.trustcue` and launch activity is `io.github.muhammadtaimoorajmal.trustcue.MainActivity`. The application was verified installed and launched into the foreground (`mCurrentFocus=MainActivity`) on connected device V2207 (`10AC9R1ABF0013A`).
  - **Git Branch State:** The completion report claimed `main` was at `1dc5d3d`. Live git references confirm `main`, `backend`, and `database` remain at initial commit `a785db8` awaiting integration. `frontend` is at checkpoint `68aa084`.
  - **Route Contract:** Confirmed exact-path matching preserves Module 12A rules: `/` is Home, query parameters do not alter destination, trailing slashes reach 404, and component preview is a standalone developer entry point (`lib/dev/component_preview.dart`).
- **Build & Device Diagnostics Distinction:**
  - Build failure evidence showed incremental cache corruption in `frontend/build/shared_preferences_android/` (`PersistentMapImpl.<init>` / `Could not close incremental caches`). Stopping daemons and clearing that directory allowed a clean rebuild. Lock ownership was a working hypothesis, not directly proven by logs.
  - Device test runner status: APK build passed, APK installation (`io.github.muhammadtaimoorajmal.trustcue`) passed, activity launch passed (`mCurrentFocus=MainActivity`), but automated integration-test runner (`tool/test.ps1 -Suite device`) timed out after 180s waiting for test listener (Outcome: TIMEOUT). Human visual verification remains PENDING.
  - Analyzer: Fresh `flutter analyze --no-pub` reported 0 issues across the workspace; editor problem markers were stale artifacts.
- **Verification:** All 51 widget/unit tests PASS via `tool/test.ps1 -Suite all`. Formatting passes with 0 changes.
- **Status:** Complete. Pushed to `frontend`. Integration into `main` remains paused pending human smoke-test sign-off.

## Module 14: TrustCue Home Dashboard and Input-Method Navigation
- **Scope:** Retire the temporary counter demonstration completely from production and test code. Replace Home (`/`) with the product dashboard featuring brand header ("Understand the signals."), supporting copy, honest development status ("Analysis is not available in this development build yet."), three vertically structured input method cards with "Coming soon" badges and buttons navigating to `/input/text`, `/input/screenshot`, and `/input/link`, and a "Pause before you act." safety guidance card routing to `/safe-use`. Implement dedicated input preparation screens (`InputTextScreen`, `InputScreenshotScreen`, `InputLinkScreen`) sharing `InputPreparationLayout` with method safety tips, "Coming soon" notices, and safe-use review button. Register routes and exact-path resolution. Implement debounced navigation to prevent multi-push races.
- **Branch:** `frontend`
- **Retired Components:**
  - `HomeController`: Removed `_counter` observable state, getter, and `incrementCounter()`.
  - Floating action button and counter text removed from `HomeScreen`.
  - All counter test assertions retired across widget tests, onboarding tests, navigation tests, and integration smoke test.
- **Route Additions:**
  - `AppRoutes.inputText` (`/input/text`) -> `InputTextScreen`
  - `AppRoutes.inputScreenshot` (`/input/screenshot`) -> `InputScreenshotScreen`
  - `AppRoutes.inputLink` (`/input/link`) -> `InputLinkScreen`
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (34 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (63/63 tests passed across 4 suites: 29 navigation, 16 onboarding, 5 widget/theme, 13 core/layout).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build/app/outputs/flutter-apk/app-debug.apk` built in 23.4s).
  - Device install and launch: Successfully installed on Vivo V2207 (`10AC9R1ABF0013A`, Android 14 / API 34) and verified `mFocusedApp=MainActivity`.
- **Manual Verification:** Human phone visual checklist provided for inspecting dashboard layout, entering each input preparation screen, verifying safe-use review navigation, testing back button behavior, and background/resume lifecycle.
- **Status:** Complete. Pushed to `frontend`. Integration into `main` remains paused pending human smoke-test sign-off.

## Module 15: Typed Data Models, Serialization, Errors, and Analysis Interfaces
- **Scope:** Implement platform-independent data foundation for input intake and scam indicator analysis without UI changes or runtime wiring. Define `InputSource` enum and immutable `TextSnapshot`. Implement `FindingOrigin`, `EvidenceReference` with UTF-16 code-unit offsets and surrogate-pair boundary validation, `AnalysisFinding` with defensive unmodifiable collections, `AnalysisReport` grouping findings, limitations, and suggested actions. Define typed `Result<T>` monad and privacy-preserving `AnalysisFailure`. Implement asynchronous `AnalysisService` contract. Author strict version-1 JSON serialization codecs (`TextSnapshotCodec`, `EvidenceReferenceCodec`, `AnalysisFindingCodec`, `AnalysisReportCodec`).
- **Branch:** `frontend`
- **Domain & Serialization Models:**
  - `lib/core/errors/analysis_failure.dart`: Standardized failure codes (`invalidInput`, `unsupportedInput`, `unavailable`, `timeout`, `cancelled`, `malformedData`). Diagnostic output strictly omits submitted user text and credentials.
  - `lib/core/types/result.dart`: Generic `Result<T>` (`Success<T>` and `Failure<T>`) outcome type.
  - `lib/features/input/domain/models/`: `InputSource` (`messageText`, `screenshot`, `link`, `qrCode`), `TextSnapshot`.
  - `lib/features/input/data/serialization/`: `TextSnapshotCodec`.
  - `lib/features/analysis/domain/models/`: `FindingOrigin` (`localRule`, `remoteAi`), `EvidenceReference`, `AnalysisFinding`, `AnalysisReport`.
  - `lib/features/analysis/domain/contracts/`: `AnalysisService` (asynchronous interface).
  - `lib/features/analysis/data/serialization/`: `EvidenceReferenceCodec`, `AnalysisFindingCodec`, `AnalysisReportCodec`.
  - `docs/DATA_CONTRACTS.md`: Comprehensive documentation of models, fields, strict version-1 JSON policy, and synthetic example.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (55 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (116/116 tests passed across 8 suites, adding 53 new data model, serialization, and error handling tests).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build/app/outputs/flutter-apk/app-debug.apk` built in 22.6s).
  - `git diff --check`: PASS (clean whitespace).
- **Device Verification:** Module 14's physical-device install and smoke-test PASS on Vivo V2207 (`10AC9R1ABF0013A`) is retained as historical verification. No UI or runtime integration changed; device re-installation was not required for pure data contracts.
- **Status:** Complete. Pushed to `frontend`. Integration into `main` remains paused pending human smoke-test sign-off.

## Module 16: Message-Text Entry, Normalization, Validation, and Limits
- **Scope:** Implement functional local message text entry on `/input/text` replacing the preparation placeholder. Implement pure-Dart `MessageTextValidator` enforcing dual limits (10,000 code points, 40,000 UTF-8 bytes) on original editor text, CRLF line ending normalization (`\r\n`/`\r` to `\n`), blank and invisible Unicode glyph rejection, unsupported control character rejection, and unpaired surrogate validation. Implement route-owned `InputTextController` via `InputTextBinding` managing text editing, live character counter (`X / 10,000 characters`), in-memory `TextSnapshot` creation, draft change invalidation, and discard/clear confirmation dialogs. Update Home dashboard Message text card from "Coming soon" to active "Preparation available" status with "Enter message" action.
- **Branch:** `frontend`
- **Domain & Presentation Components:**
  - `lib/features/input/domain/validation/message_text_validator.dart`: Pure-Dart validation and normalization policy. Enforces 10,000 code-point limit and 40,000 UTF-8 byte limit on original input. Converts line breaks to LF. Rejects empty, blank/invisible-only, malformed UTF-16 surrogates, and control characters (excluding tab, LF, CR). Maps to `AnalysisFailure` without exposing user text.
  - `lib/features/input/presentation/controllers/input_text_controller.dart`: Route-scoped GetX controller. Reactive draft synchronization, character counter state, in-memory snapshot preparation with injectable ID generator and clock, text change invalidation, clear confirmation dialog, and unsaved draft discard dialog.
  - `lib/features/input/presentation/bindings/input_text_binding.dart`: Route-level lazy dependency injection.
  - `lib/features/input/presentation/screens/input_text_screen.dart`: Complete screen layout with `AppPageBody`, multiline `AppTextField` with persistent "Message" label and character counter, development availability notice ("Text preparation is available. Scam analysis is not available in this build yet."), inline confirmation banner ("Text prepared on this device. It has not been analyzed or sent anywhere."), "Prepare text" and "Clear text" action buttons, safety reminder, and safe-use guidance review navigation.
  - `lib/features/home/presentation/screens/home_screen.dart`: Updated Message text option card with "Preparation available" status, updated copy, and "Enter message" action button.
  - `lib/core/widgets/app_text_field.dart`: Added optional `counterText` parameter passing to `InputDecoration`.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (61 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (145/145 tests passed across 11 suites, adding 29 new tests across validator, controller, and screen suites).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build/app/outputs/flutter-apk/app-debug.apk` built in 12.6s).
  - `powershell -File tool/test.ps1 -Suite device -DeviceId "10AC9R1ABF0013A" -TimeoutSeconds 600`: PASS (integration smoke test on Vivo V2207 passed in 17s).
  - Physical device installation & launch: Updated APK installed and launched on Vivo V2207 (`10AC9R1ABF0013A`).
- **Manual Verification:** Human phone visual checklist provided for inspecting message entry, character counter updates, validation error display, in-memory preparation banner, discard dialog upon leaving with unsaved draft, and clear dialog.
- **Status:** Complete. Pushed to `frontend`. Integration into `main` remains paused pending human smoke-test sign-off.

## Module 17: Screenshot Selection, Preview, and Temporary-File Handling
- **Scope:** Implement functional screenshot selection, validation, local preview, and temporary file lifecycle on `/input/screenshot` replacing the placeholder. Implement pure-Dart `ImageValidator` and `ImageValidationPolicy` enforcing MIME type check (PNG, JPEG magic bytes), dimension bounds (width/height >= 32px, max 20 megapixels total pixel count), size bounds (<= 10MB). Interactive pan and zoom preview via `InteractiveViewer`. Temporary file lifecycle owned by `ScreenshotStorageService` (`DefaultScreenshotStorageService` writing uniquely timestamped copies to isolated `trustcue_screenshots` app-owned cache directory). File removal and replacement with previous file deletion, page back/discard dialogs, and route-pop cleanup. Android picker recovery coordinator handling `retrieveLostData()`. Never delete original user gallery files. Never expose absolute filesystem paths or file names in user-facing UI or error messages. Update Home dashboard Screenshot card from "Coming soon" to "Preview available". Android build repairs: NDK subproject override for `:jni` to `30.0.16138531`, Kotlin `kotlin.incremental=false` to resolve cross-drive path comparison bug. Widget test fake storage sync fix for `FakeAsync` compatibility.
- **Branch:** `frontend`
- **Domain, Storage, & Presentation Components:**
  - `lib/features/input/domain/models/selected_image_descriptor.dart`: Immutable descriptor containing `path`, `fileSizeBytes`, `width`, `height`, and `mimeType`.
  - `lib/features/input/domain/validation/image_validation_policy.dart`: Limits defining allowed MIME types (`image/png`, `image/jpeg`), max bytes (10MB), min dimension (32px), max megapixels (20MP).
  - `lib/features/input/domain/validation/image_validator.dart`: Pure-Dart validator checking file existence, size, header magic bytes (PNG `89 50 4E 47`, JPEG `FF D8 FF`), and dimension extraction without UI dependencies.
  - `lib/features/input/domain/contracts/screenshot_storage_service.dart`: Abstract interface for creating owned copies, deleting owned files, and checking ownership.
  - `lib/features/input/domain/contracts/image_picker_adapter.dart`: Abstract adapter for `pickImage()` and `retrieveLostData()`.
  - `lib/features/input/data/services/default_screenshot_storage_service.dart`: Implementation writing to `cacheDir/trustcue_screenshots/` with timestamp and UUID-based collision resistance.
  - `lib/features/input/data/services/default_image_picker_adapter.dart`: Production adapter wrapping `ImagePicker`.
  - `lib/features/input/presentation/controllers/input_screenshot_controller.dart`: Route-scoped GetX controller managing picking, validation, selection state, replacement/removal, discard confirmation, and route-exit cleanup.
  - `lib/features/input/presentation/controllers/screenshot_recovery_coordinator.dart`: Android lost-data recovery coordinator.
  - `lib/features/input/presentation/bindings/input_screenshot_binding.dart`: Route-level lazy dependency injection.
  - `lib/features/input/presentation/screens/input_screenshot_screen.dart`: Complete screen layout with `AppPageBody`, `InteractiveViewer` pan/zoom preview, image metadata chip, pick/replace/remove action buttons, safety reminder, and safe-use review navigation.
  - `lib/features/home/presentation/screens/home_screen.dart`: Updated Screenshot card from "Coming soon" to active "Preview available" status.
  - `lib/app/routes/app_pages.dart`: Wired `InputScreenshotBinding` to `AppRoutes.inputScreenshot`.
  - `android/build.gradle.kts`: Subproject `setNdkVersion` override for `:jni` to local NDK `30.0.16138531`.
  - `android/gradle.properties`: Added `kotlin.incremental=false` to prevent cross-drive `IllegalArgumentException` in Kotlin compilation.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (75 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (175/175 tests passed across 15 suites, adding 30 new tests across validator, storage, controller, and screen suites).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build/app/outputs/flutter-apk/app-debug.apk` built in 114.6s).
  - `powershell -File tool/test.ps1 -Suite device -DeviceId "10AC9R1ABF0013A" -TimeoutSeconds 600`: PASS (integration smoke test on Vivo V2207 passed in 17s).
  - Physical device installation & launch: Updated APK installed and launched on Vivo V2207 (`10AC9R1ABF0013A`).
- **Manual Verification:** Human phone visual checklist provided for inspecting screenshot selection from gallery, preview pan and zoom, metadata display (file size, dimensions), image replacement, image removal confirmation, back/discard dialog on unsaved preview, and safe-use review navigation.
- **Status:** Complete. Pushed to `frontend`. Integration into `main` remains paused pending human smoke-test sign-off.

## Module 18: Local OCR, Script Limitations, Extraction Errors, and Retries
- **Scope:** Implement real on-device Latin text extraction on `/input/screenshot` using `google_mlkit_text_recognition: 0.17.1`. The bridge is community-maintained by `flutter-ml.dev` and wraps Google's on-device ML Kit C++/Java libraries without API keys, accounts, or network dependencies. Extract text only upon deliberate user request via "Extract text from image" button. Display clear script limitation notice (Latin alphabet only) and accuracy warning. Provide read-only, selectable text presentation with prominent "Unreviewed text â€” accuracy not verified" banner. Robust error handling mapping failures into user-friendly messages: empty image text, limits exceeded (10,000 code points / 40,000 UTF-8 bytes), platform unsupported, timeout, and user cancellation. Provide recovery actions: "Retry extraction" and "Enter message text manually". Truthful retry state prevents overlapping native operations (`isNativeSettling`). Coordinate file reader lifecycle (`_activeReadingFiles`) so active native readers prevent premature file deletion. Update Home dashboard Screenshot card status from "Preview available" to "Text extraction available". Reconcile iOS deployment target in Xcode project to 15.5+ (`IPHONEOS_DEPLOYMENT_TARGET = 15.5`).
- **Branch:** `frontend`
- **Domain, Storage, & Presentation Components:**
  - `lib/features/input/domain/contracts/text_recognition_service.dart`: Asynchronous contract defining `processImage()`, `cancelOperation()`, and `dispose()`.
  - `lib/features/input/domain/models/ocr_failure.dart`: Structured failure domain model with `OcrFailureCode` enum (`invalidOrMissingFile`, `emptyText`, `limitsExceeded`, `recognitionUnavailable`, `timeout`, `cancelled`, `internalError`) and bidirectional conversion to/from `AnalysisFailure`.
  - `lib/features/input/domain/models/ocr_result.dart`: Immutable result model containing `TextSnapshot` (`InputSource.screenshot`), `imageRevision`, `script: 'latin'`, and immutable limitations list.
  - `lib/features/input/data/services/default_text_recognition_service.dart`: Production service wrapping Google ML Kit Latin recognizer with platform detection (returning `recognitionUnavailable` on desktop/web), line-break normalization (`\r\n`/`\r` to `\n`), operation token tracking, and 10,000 code-point / 40,000 UTF-8 byte boundary enforcement.
  - `lib/features/input/presentation/controllers/input_screenshot_controller.dart`: Enhanced with `extractText()`, `cancelExtraction()`, `navigateToMessageInput()`, `isExtracting`, `isNativeSettling`, `ocrResult`, `ocrFailure`, file reader concurrency tracking (`_activeReadingFiles`), and deferred deletion (`_pendingDeletionFiles`).
  - `lib/features/input/presentation/screens/input_screenshot_screen.dart`: UI updated with Latin script limitation notice, extraction progress card with Cancel button, unreviewed text banner, `SelectableText` read-only display, error states with retry/manual entry buttons, responsive wrapping on metadata chip, and unsaved extracted text discard warning.
  - `lib/features/home/presentation/screens/home_screen.dart`: Updated Screenshot card status chip to "Text extraction available".
  - `ios/Runner.xcodeproj/project.pbxproj`: Reconciled iOS deployment target to 15.5 (`IPHONEOS_DEPLOYMENT_TARGET = 15.5`).
  - `tool/generate_ocr_fixture.ps1`: Windows PowerShell script generating high-contrast synthetic PNG test fixture with real anti-aliased Latin text using `System.Drawing`.
  - `assets/fixtures/ocr_test_card.png`: Bundled test fixture asset containing high-contrast Latin test text ("TrustCue OCR test\nVerify before you act.").
  - `test/tool/generate_ocr_fixture_test.dart`: Asset existence and PNG magic byte header validation test.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (84 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (200/200 tests passed across 19 suites, adding 25 new tests for Module 18).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build/app/outputs/flutter-apk/app-debug.apk` built cleanly).
  - `powershell -File tool/test.ps1 -Suite device -DeviceId "10AC9R1ABF0013A" -TimeoutSeconds 600`: PASS (integration smoke test and real native Google ML Kit OCR test executed on physical Vivo V2207 device, validating recognition of expected words "trustcue", "ocr", "test", "verify", "act").
  - Physical device installation & launch: Updated APK installed and launched on Vivo V2207 (`10AC9R1ABF0013A`, PID 15999).
- **Manual Verification:** Human phone visual checklist provided for inspecting Latin script limitation notice, deliberate OCR extraction triggering, progress indicator and cancel button, unreviewed banner and text selectable container, error retry and manual entry fallbacks, and back-button discard confirmation warning about extracted text.
- **Status:** Complete (Commit `f73b920`). Pushed to `frontend`. Integration into `main` remains paused pending human smoke-test sign-off.

## Module 19: Text Review, Correction, Sensitive-Data Suggestions, and Redaction
- **Scope:** Connect prepared message text (`/input/text`) and extracted OCR text (`/input/screenshot`) to one shared, local review and correction screen at `/input/review`. Allow users to edit text, inspect possible sensitive details via a pure-Dart heuristic detector (`LocalSensitiveDataDetector`), select/deselect suggested redactions, preview the exact redacted text in real time, and confirm reviewed text on-device. Preserve input source provenance (`InputSource.messageText` or `InputSource.screenshot`). Ensure complete local operation with explicit privacy banners stating that reviewing text does not analyze it or authorize uploading it. Never transmit text or perform scam analysis in this module.
- **Branch:** `frontend`
- **Domain, Service, & Presentation Components:**
  - `lib/features/input/domain/models/sensitive_data_type.dart`: Enum defining categories (`email`, `phone`, `paymentCard`, `verificationCode`), labels, placeholders (`[EMAIL]`, `[PHONE]`, `[CARD NUMBER]`, `[VERIFICATION CODE]`), and priority (`paymentCard` (4) > `verificationCode` (3) > `phone` (2) > `email` (1)).
  - `lib/features/input/domain/models/sensitive_data_candidate.dart`: Immutable candidate model with UTF-16 code-unit offsets, masked labels, contextual summary, and privacy-safe `toString()`.
  - `lib/features/input/domain/models/review_input.dart`: Parameter container passed to `/input/review` holding `snapshot`, `sourceRevision`, and optional `imagePath`.
  - `lib/features/input/domain/models/reviewed_text_result.dart`: Immutable final result holding new `TextSnapshot`, `sourceSnapshotId`, `sourceRevision`, `reviewedAt`, and `redactionCounts` mapping.
  - `lib/features/input/domain/services/local_sensitive_data_detector.dart`: Pure-Dart heuristic detector with Luhn verification for payment cards, context check for OTPs, overlap resolution, formatted-number protection, and descending-offset redaction application.
  - `lib/features/input/presentation/controllers/input_review_controller.dart`: GetX controller managing editable draft, character counting, candidate detection, selection toggling, real-time preview, confirmation, discard dialog on exit, and comparison image toggle.
  - `lib/features/input/presentation/bindings/input_review_binding.dart`: Dependency injection binding for `/input/review`.
  - `lib/features/input/presentation/screens/input_review_screen.dart`: Screen with privacy banner, editable text field, character counter, suggestions card with checkboxes, preview card, and confirmation status banner.
  - Integration with `/input/text` and `/input/screenshot`: Navigation to review, result reception, and edit invalidation.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (95 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (227/227 tests passed across 21 suites, adding 27 new tests).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build/app/outputs/flutter-apk/app-debug.apk` built cleanly).
  - `powershell -File tool/test.ps1 -Suite device -DeviceId "10AC9R1ABF0013A" -TimeoutSeconds 600`: PASS (smoke test, native OCR test, and synthetic review/redaction integration test passed on physical Vivo V2207 device in 23s).
  - Physical device installation & launch: Updated APK installed and launched on Vivo V2207 (`10AC9R1ABF0013A`).
- **Manual Verification:** Human phone visual checklist provided for inspecting review entry from text and screenshot, editable text corrections, sensitive detail detection, candidate toggling and placeholder preview, confirmation banner, and back-button navigation.
- **Status:** Complete (Commit `490ff66`). Pushed to `frontend`. Integration into `main` remains paused pending human smoke-test sign-off.

## Module 20: Link Inspection, QR Decoding, and Explicit Destination Opening
- **Scope:** Implement local link inspection and QR code decoding on `/input/link` without contacting destinations or issuing network/DNS queries. Support two intake mechanisms: (1) typed/pasted web address entry with offline URL inspection, and (2) on-device QR image selection and barcode decoding via `google_mlkit_barcode_scanning: 0.16.1`. Provide factual, non-judgmental structural observations: IPv4/IPv6 host, uncommon port, excessive subdomain nesting, potential open redirect parameters, percent-encoding in host, userinfo/credentials rejection, and unsupported Unicode/Punycode hostnames. Bounded 4,096-byte input size limit. Handle empty, single, multiple distinct, duplicate, and unsupported non-web QR payloads safely. Provide explicit two-step external browser launching via `UrlLauncherAdapter` (`LaunchMode.externalApplication`) displaying full destination hostname and complete selectable URL. Invalidate launch confirmation on input change. Connect valid inspected links and QR payloads to `/input/review` passing `InputSource.link` or `InputSource.qrCode`. Update Home dashboard Link card status from "Coming soon" to "Inspection available".
- **Branch:** `frontend`
- **Domain, Service, & Presentation Components:**
  - `lib/features/input/domain/models/link_inspection_result.dart`: Typed models for scheme, host, port, path, query, fragment, factual observations, and rejection codes (`LinkRejectionCode`).
  - `lib/features/input/domain/models/qr_payload.dart`: Payload categorization (`webUrl`, `plainText`, `unsupported`) with safe sanitization and length bounding (4,096 UTF-8 bytes).
  - `lib/features/input/domain/models/qr_decode_result.dart`: Typed decode result handling single, multiple distinct, duplicate identical deduplication, and empty detections.
  - `lib/features/input/domain/contracts/url_launcher_adapter.dart`: Adapter contract for external browser launching.
  - `lib/features/input/domain/contracts/qr_decoder_service.dart`: Adapter contract for QR image decoding.
  - `lib/features/input/domain/services/url_inspection_service.dart`: Pure-Dart offline parser and structural inspector with IPv4/IPv6 RFC 1918 loopback/private IP detection, port checking, subdomain counting, open redirect parameter flagging, and rejection rules.
  - `lib/features/input/data/services/default_url_launcher_adapter.dart`: Production implementation wrapping `url_launcher: 6.3.3` with `LaunchMode.externalApplication`.
  - `lib/features/input/data/services/default_qr_decoder_service.dart`: Production implementation wrapping `google_mlkit_barcode_scanning: 0.16.1` for `BarcodeFormat.qrCode` with payload categorization and deduplication.
  - `lib/features/input/presentation/controllers/input_link_controller.dart`: GetX controller managing mode toggle (`web address` vs `QR image`), URL validation, QR image picking/decoding/cleanup, confirmation modal state, launch execution, and review navigation.
  - `lib/features/input/presentation/bindings/input_link_binding.dart`: Route dependency injection binding.
  - `lib/features/input/presentation/screens/input_link_screen.dart`: Complete screen layout with segmented mode selector, web address input with inspection trigger, QR image selector with interactive pan/zoom preview, destination review card, multi-payload selector, safety reminder, and two-step external launch confirmation modal.
  - `lib/features/input/presentation/controllers/screenshot_recovery_coordinator.dart`: Updated with `PickerPurpose` (`screenshot` vs `qrCode`) for disambiguating image picker callbacks.
  - `frontend/android/app/src/main/AndroidManifest.xml`: Added `<queries>` intent declarations for `https` and `http` schemes.
  - `assets/fixtures/qr_test_card.png`: Bundled test fixture asset containing QR code encoding `https://example.com/trustcue-test`.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (109 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (273/273 tests passed across 25 suites, adding 46 new tests for Module 20).
  - `git diff --check`: PASS (clean whitespace).
- **Manual Verification:** Human phone visual checklist provided for inspecting typed URL inspection, observation chips, QR image selection and decoding, multiple code selector, confirmation modal with complete hostname and destination URL, external browser opening, and safe-use review navigation.
- **Status:** Complete. Pushed to `frontend`. Integration into `main` remains paused pending human smoke-test sign-off.

## Module 20A: Complete Android Build and Contract Reconciliations
- **Scope:** Reconcile Module 20 implementation against contract requirements and diagnose Android build failure:
  1. **Contract Reconciliations:**
     - **Punycode:** Conventional ASCII punycode hostnames (`xn--...`) are accepted with a factual caution observation (`Destination contains an internationalized punycode label ("$label"), which may visually resemble another domain.`); unencoded non-ASCII Unicode hostnames are rejected as unsupported (`unicodeHostUnsupported`).
     - **Payload limits:** Decoded payloads exceeding 4,096 UTF-8 bytes are strictly classified as `QrPayloadType.unsupported` (`isOversized: true`, formatDescription: `Oversized Payload`), preventing recategorization as `plainText` or forwarding to `/input/review`.
     - **Structural observations:** Removed speculative subdomain boundary/counting logic. Factual redirect query parameter observation without concluding open redirect vulnerability (`Destination contains N query parameter(s).` and `Contains query parameter "$key", a parameter name commonly used for destination redirection.`).
  2. **Editor Warnings & Analysis Reconciliation:** Reconciled 117 editor warnings in IDE problems panel against zero Dart analysis issues. Confirmed that `flutter analyze --no-pub` and `dart analyze` report 0 issues; the 117 markers were external/stale Java/Gradle language server warnings from missing JDK on host, not Dart source problems.
  3. **Android Build Root Cause Analysis:**
     - Inspected complete `gradlew.bat` output: failed with code 1 (`ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.`, error code 9009).
     - Disclosed Flutter config: global `flutter config --jdk-dir` was experimentally set earlier to DBeaver JRE, but DBeaver JRE is a custom stripped `jlink` runtime lacking the `java.instrument` module required by Gradle 9.3.1. Reverted and cleared via `flutter config --jdk-dir=""`.
     - Verified system environment: `HKCU:\Environment\Path` points to `C:\Program Files\Java\jdk-25\bin`, but `C:\Program Files\Java` does not exist on disk outside the project repository.
     - Documented precise prerequisite: A full standard OpenJDK runtime (JDK 17, 21, or 25) with `java.instrument` must be installed on the host and configured in `JAVA_HOME` or system PATH for local APK compilation.
- **Branch:** `frontend`
- **Reconciled Components:**
  - `lib/features/input/domain/services/url_inspection_service.dart`: Factual query parameter count, factual redirect parameter name observation without speculative claims, punycode acceptance with caution, unencoded non-ASCII Unicode rejection.
  - `lib/features/input/data/services/default_qr_decoder_service.dart`: Strict early classification of oversized payloads (>4,096 UTF-8 bytes) as `QrPayloadType.unsupported` (`isOversized: true`, formatDescription: `Oversized Payload`), preventing plainText or URL fallback.
  - `lib/features/input/presentation/controllers/input_link_controller.dart`: Guarded `reviewText()` to reject oversized payloads, uninspected URLs, or payloads exceeding 4,096 bytes.
  - `test/features/input/domain/services/url_inspection_service_test.dart`: Updated unit tests verifying factual observations.
  - `test/features/input/domain/services/default_qr_decoder_service_test.dart`: Updated unit tests verifying oversized payloads classified as `unsupported`.
  - `test/features/input/presentation/controllers/input_link_controller_test.dart`: Added controller test asserting oversized payload rejection during review navigation.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (109 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (274/274 tests passed across 25 suites, adding 1 new controller test).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build\app\outputs\flutter-apk\app-debug.apk`, 209,059,186 bytes, built in 111.5s).
  - `powershell -File tool/test.ps1 -Suite device -DeviceId "10AC9R1ABF0013A" -TimeoutSeconds 600`: PASS (4/4 tests passed in 28s on physical Vivo V2207 Android 14 / API 34).
  - `flutter run --no-pub -d "10AC9R1ABF0013A" -t lib/main.dart`: PASS (restored and launched normal app on device, PID 25535, detached cleanly).
  - `git diff --check`: PASS (clean whitespace).
- **Physical Device & Build Status:** Verified on physical Vivo V2207 (`10AC9R1ABF0013A`, Android 14 / API 34) running with Eclipse Adoptium OpenJDK 21.0.12.1 (`Temurin-21.0.12.1+1 LTS, hotspot`). Native QR decoding via Google ML Kit verified against `assets/fixtures/qr_test_card.png` without automatic destination launch. Native OCR and review/redaction integration coverage fully preserved.
- **Status:** Complete. Pushed to `frontend`. Integration into `main` remains paused pending human smoke-test sign-off.


## Module 21: Android Incoming Shares and Lifecycle Integration
- **Scope:** Support receiving shared text or one supported image into TrustCue through Android's Sharesheet (`ACTION_SEND`).
  1. **Sharesheet Declaration & Filtering:** AndroidManifest intent filter for `ACTION_SEND` supporting `text/plain`, `image/png`, and `image/jpeg`. Unsupported `ACTION_SEND_MULTIPLE`, non-content file URIs, and unrecognized MIME types are caught gracefully and surfaced as informative non-fatal errors.
  2. **Native Payload Extraction & Security Limits (`MainActivity.kt`):** Background thread streaming via `ContentResolver` to app-owned cache directory (`cacheDir/trustcue_incoming_shares/`). Maximum file size bounded to 10 MiB (10,485,760 bytes) with magic-byte verification (PNG `89 50 4E 47`, JPEG `FF D8 FF`). Streams exceeding bounds or containing invalid headers are aborted and staged files removed. Text payloads are bounded to 10,000 code points and 40,000 UTF-8 bytes.
  3. **Cold & Warm Lifecycle Bridge (`MethodChannel("trustcue/incoming_share")`):** Handles cold launch (`onCreate` / `getInitialShare`) and warm launch while app is already running (`onNewIntent` / `onShareReceived`). Unique UUID event tracking with explicit Dart acknowledgment (`consumeShare`) and staged cleanup (`cleanStagedFile`).
  4. **Central Coordinator & Onboarding Authority (`IncomingShareCoordinator`):** Holds pending shares until onboarding is completed. Holds at most one pending share awaiting user choice; any prior unconsumed pending share is safely replaced and cleaned up.
  5. **Non-Destructive Choice Presentation (`IncomingShareDialog`):** Clear user options: text offers "Use as message" and "Inspect as link" (if containing a single valid web link); image offers "Use as screenshot" and "Use as QR image"; mixed text/image offers both; "Dismiss" safely cleans staged files.
  6. **Draft Conflict Protection (`DraftConflict`):** Detects existing drafts in destination screens (`/input/text`, `/input/screenshot`, `/input/link`) and prompts user ("Keep current draft" vs "Replace draft with shared content"). Transactional image import via `ScreenshotStorageService` before draft replacement.
  7. **Strict Privacy Invariants:** Zero automatic OCR, QR decoding, link opening, or remote analysis.
- **Branch:** `frontend`
- **Domain, Data, and Presentation Components:**
  - `frontend/android/app/src/main/AndroidManifest.xml`: Added `ACTION_SEND` intent filter for `text/plain`, `image/png`, and `image/jpeg`.
  - `frontend/android/app/src/main/kotlin/io/github/muhammadtaimoorajmal/trustcue/MainActivity.kt`: Native `MethodChannel("trustcue/incoming_share")`, streaming bounded to 10 MiB, magic bytes verification, staging cache management, cold/warm lifecycle dispatching.
  - `lib/features/incoming_share/domain/models/incoming_share_payload.dart`: Typed immutable models (`IncomingSharePayload`, `IncomingShareType`).
  - `lib/features/incoming_share/domain/contracts/incoming_share_adapter.dart`: Adapter contract (`getInitialShare`, `shareStream`, `consumeShare`, `cleanStagedFile`).
  - `lib/features/incoming_share/data/services/default_incoming_share_adapter.dart`: Production platform channel adapter.
  - `lib/features/incoming_share/presentation/controllers/incoming_share_coordinator.dart`: GetX coordinator managing pending share, onboarding gating, draft conflicts, navigation, and cleanup.
  - `lib/features/incoming_share/presentation/widgets/incoming_share_dialog.dart`: Choice presentation dialog with responsive layout, non-interactive previews, dark theme support, and draft replacement confirmation.
  - Destination controller ingestion: `populateSharedText`, `populateSharedImage`, `populateSharedUrl`, `populateSharedQrImage` in `InputTextController`, `InputScreenshotController`, and `InputLinkController`.
  - App & route wiring in `TrustCueApp`, `OnboardingController`, and `HomeController`.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (114 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (307/307 tests passed across 28 suites, adding 33 new tests for Module 21).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build\app\outputs\flutter-apk\app-debug.apk`, 209,077,722 bytes, built in 55.8s).
  - `powershell -File tool/test.ps1 -Suite device -DeviceId "10AC9R1ABF0013A" -TimeoutSeconds 300`: PASS (5/5 tests passed in 30s on physical Vivo V2207 Android 14 / API 34, including Module 21 native channel & lifecycle test).
  - Physical device installation & launch: Updated APK installed and launched on Vivo V2207 (`10AC9R1ABF0013A`), verified live `ACTION_SEND` intent dispatching.
  - `git diff --check`: PASS (clean whitespace).
- **Physical Device & Build Status:** Verified on physical Vivo V2207 (`10AC9R1ABF0013A`, Android 14 / API 34). Native channel operations, real intent intake, staging lifecycle, draft conflict resolution, and non-destructive presentation verified.
- **Status:** Complete. Pushed to `frontend`. Stopped before Module 22.

## Module 21 Follow-Up: Pending Share Preservation and Staged Cleanup Correction
- **Scope:** Address closeout findings on incoming share retention:
  1. **Bounded Pending Share Retention:** When a share is pending in `IncomingShareCoordinator`, subsequent incoming shares are rejected with user feedback (`onShareRejected` / snackbar), preserving the existing pending share instead of overwriting it.
  2. **Isolated Staged File Cleanup:** When a subsequent incoming share is rejected, only its staged temporary file is deleted natively (`cleanStagedFile`); the retained share's staged file remains intact.
  3. **Stale Callback Protection:** Added `expectedEventId` guarding to `dismissPendingShare` and `applySharedMessage` to prevent late/stale callbacks from clearing or applying newer incoming share events.
  4. **Draft Replacement Abort Cleanup:** In `IncomingShareDialog`, if candidate image import occurs but the user subsequently cancels the draft replacement confirmation dialog, the imported candidate file in `ScreenshotStorageService` is cleaned up safely.
- **Branch:** `frontend`
- **Commit:** `ebe33d9` (`fix(frontend): enforce bounded pending-share retention and rejected share cleanup`)
- **Checks Performed:**
  - `dart format lib test integration_test`: PASS
  - `flutter analyze --no-pub`: PASS (0 issues found)
  - Unit tests: Added tests in `incoming_share_coordinator_test.dart` verifying bounded retention, single staged file deletion, re-delivery handling, and stale callback protection.

## Module 22: Local Scam-Indicator Taxonomy, Rule Engine, and Evidence Integrity
- **Scope:** Implement the foundational local rule evaluation pipeline for on-device scam indicator analysis:
  1. **Stable Indicator Taxonomy (`IndicatorCategory`):** Define 10 stable indicator category families with plain-language observation descriptions and stable string IDs decoupled from presentation labels:
     - `urgency_or_pressure`: Demands for immediate action, artificial deadlines, or urgency tactics.
     - `requests_for_credentials`: Requests for passwords, PINs, security questions, or login credentials.
     - `requests_for_verification_codes`: Requests to disclose OTPs, SMS codes, or two-factor authentication tokens.
     - `requests_for_payment`: Solicitations for wire transfers, gift cards, cryptocurrency, or unconventional payment.
     - `account_suspension_or_threats`: Claims of compromised accounts, legal threats, or impending service termination.
     - `claimed_identity_or_impersonation`: Claims of representing banks, government agencies, tech support, or trusted brands.
     - `rewards_or_prizes`: Unsolicited claims of winnings, unexpected lotteries, gifts, or inheritance.
     - `job_or_recruitment_offers`: Unsolicited employment offers, high pay for minimal work, or upfront fee requests.
     - `investment_or_return_promises`: Guarantees of unrealistic returns, risk-free investments, or crypto schemes.
     - `link_structural_indicators`: Deceptive URL patterns, mismatched text/destinations, or obfuscated hyperlinks.
     Categories state observable patterns rather than definitive verdicts of malice.
  2. **Pure-Dart Rule Contracts (`LocalRule`, `RuleRegistry`, `LocalRuleRegistry`):**
     - `LocalRule`: Abstract interface defining `id`, `version`, `category`, `supportedLanguages`, `limitations`, and asynchronous `evaluate(snapshot)`.
     - `RuleRegistry`: Contract for querying and managing registered rules.
     - `LocalRuleRegistry`: In-memory implementation with duplicate ID rejection (`ArgumentError`) and unmodifiable collections (`List.unmodifiable`).
  3. **Strict Evidence Integrity Validator (`EvidenceValidator`):**
     - Pure-Dart validator checking that each finding's `EvidenceReference` is strictly grounded in the target `TextSnapshot`.
     - Verifies `snapshotId` equality.
     - Verifies character offsets `[startOffset, endOffset]` are non-negative, bounded within text length, and non-empty (`startOffset < endOffset`).
     - Verifies offsets do not split UTF-16 surrogate pairs (e.g., emojis or astral plane characters).
     - Verifies the quoted `excerpt` string equals `text.substring(startOffset, endOffset)` with byte-for-byte exactness.
     - Verifies `FindingOrigin.localRule` and exact `producerId` equality with the evaluating rule's ID.
  4. **Deterministic Local Rule Engine (`LocalRuleEngine`):**
     - Implements `AnalysisService` contract.
     - Reuses `MessageTextValidator` for input normalization and boundary checks (rejecting empty or oversized texts).
     - Caps total findings to `maxFindings = 100` to prevent unbounded memory growth.
     - Applies deterministic 5-tier sorting: Severity descending (`high` > `medium` > `low` > `informational`), Category ID ascending, Rule ID ascending, Start offset ascending, and Finding ID ascending.
     - Handles rule exceptions gracefully, mapping errors to typed `AnalysisFailure.malformedData` / `.unsupportedInput` without leaking raw user text.
     - Honest limitation declaration: reports empty findings with explicit caveats stating that absence of detected indicators does not guarantee safety.
- **Branch:** `frontend`
- **Domain and Service Components:**
  - `lib/features/analysis/domain/models/indicator_category.dart`: 10 indicator category definitions with stable IDs and plain-language descriptions.
  - `lib/features/analysis/domain/contracts/local_rule.dart`: Pure-Dart rule interface.
  - `lib/features/analysis/domain/contracts/rule_registry.dart`: Rule registry interface.
  - `lib/features/analysis/domain/services/local_rule_registry.dart`: In-memory rule registry with duplicate ID rejection.
  - `lib/features/analysis/domain/services/evidence_validator.dart`: Evidence integrity validator enforcing UTF-16 code-unit bounds, surrogate pair protection, exact substring matching, and producer/origin validation.
  - `lib/features/analysis/domain/services/local_rule_engine.dart`: Deterministic rule engine implementing `AnalysisService`.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (127 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (349/349 tests passed across 32 suites, adding 42 new unit tests).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build\app\outputs\flutter-apk\app-debug.apk`, 220,728,022 bytes, built in 41.2s).
  - Physical device installation & launch: Streamed install and normal app execution verified on connected Vivo V2207 (`10AC9R1ABF0013A`, Android 14 / API 34). Live `ACTION_SEND` intent delivery to running activity verified via adb.
  - `git diff --check`: PASS (clean whitespace).
- **Physical Device & Build Status:** Verified debug APK compilation and streamed install on physical Vivo V2207 (`10AC9R1ABF0013A`, Android 14 / API 34). Live `ACTION_SEND` intent delivery to running activity verified via adb. The automated device integration suite (`tool/test.ps1 -Suite device`) was not executed for Module 22 (marked unverified for Module 22; last run in Module 21 where 5/5 tests passed).
- **Status:** Complete (Commit `19a5300`). Pushed to `frontend`. Stopped before Module 23.

## Module 23: Core Local Warning-Indicator Rules
- **Scope:** Implement the core local English-language warning indicator rule pack for the five initial categories:
  1. `urgency_or_pressure` (`UrgencyRule`, `rule.urgency.immediate_action`): Detects explicit immediate action demands, short deadlines (e.g. within 24 hours), or time-sensitive ultimatums. Excludes benign scheduling and ordinary occurrences of "now" or "today".
  2. `requests_for_credentials` (`CredentialRequestRule`, `rule.credential.disclosure_request`): Detects explicit requests to disclose passwords, PINs, security answers, or credentials. Excludes legitimate sign-in instructions via official apps. Negated safety advice ("Never share your password") is suppressed at the clause level.
  3. `requests_for_verification_codes` (`VerificationCodeRequestRule`, `rule.verification_code.disclosure_request`): Detects explicit requests to disclose OTPs, SMS codes, or 2FA tokens. Excludes code delivery messages ("Your verification code is 123456") by requiring disclosure action verbs. Supports redacted placeholders (`[VERIFICATION CODE]`).
  4. `requests_for_payment` (`PaymentRequestRule`, `rule.payment.solicitation`): Detects explicit requests to wire money, pay via cryptocurrency, purchase gift cards, or pay clearance fees. Excludes receipts, invoices, and refund notices. Describes payment requests factually without labeling methods inherently fraudulent.
  5. `account_suspension_or_threats` (`AccountThreatRule`, `rule.account.threat_or_suspension`): Detects claims of account suspension, restriction, or legal threats. Excludes benign phrases ("suspend download", "close window").
  6. **Matching & Evidence Infrastructure (`RuleMatcherUtils`):** Pure-Dart utilities using clause delimiters (`[\r\n.!?;,:]`), clause-level negation detection with adversarial conjunction handling (`but`, `however`), surrogate pair safety, and overlapping match deduplication (retaining longer spans and earlier offsets).
  7. **Central Catalog & Registry Factory (`CoreWarningRuleCatalog`):** Creates rule instances and pre-populated `LocalRuleRegistry` for dependency injection into `LocalRuleEngine`.
  8. **Zero UI Analysis Invocations:** Production input screens, review screens, OCR, and share handlers remain decoupled and do not trigger analysis.
- **Branch:** `frontend`
- **Domain, Rule, and Test Components:**
  - `lib/features/analysis/domain/rules/rule_matcher_utils.dart`: Pure-Dart clause parsing, negation handling, surrogate protection, and evidence reference generation.
  - `lib/features/analysis/domain/rules/urgency_rule.dart`: Urgency and pressure rule.
  - `lib/features/analysis/domain/rules/credential_request_rule.dart`: Credential disclosure request rule.
  - `lib/features/analysis/domain/rules/verification_code_request_rule.dart`: Verification code disclosure request rule.
  - `lib/features/analysis/domain/rules/payment_request_rule.dart`: Payment solicitation rule.
  - `lib/features/analysis/domain/rules/account_threat_rule.dart`: Account suspension and threat rule.
  - `lib/features/analysis/domain/rules/core_warning_rule_catalog.dart`: Central catalog and registry factory.
  - `test/features/analysis/domain/rules/urgency_rule_test.dart`: 19 unit tests.
  - `test/features/analysis/domain/rules/credential_request_rule_test.dart`: 22 unit tests.
  - `test/features/analysis/domain/rules/verification_code_request_rule_test.dart`: 22 unit tests.
  - `test/features/analysis/domain/rules/payment_request_rule_test.dart`: 17 unit tests.
  - `test/features/analysis/domain/rules/account_threat_rule_test.dart`: 17 unit tests.
  - `test/features/analysis/domain/rules/core_warning_rule_catalog_test.dart`: 3 unit tests.
  - `test/features/analysis/domain/services/local_rule_engine_module23_test.dart`: 4 engine-level integration tests.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (141 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (453/453 tests passed across 39 suites, adding 104 tests for Module 23).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (`build\app\outputs\flutter-apk\app-debug.apk`, 235,426,020 bytes, built in 40.1s).
  - `git diff --check`: PASS (clean whitespace).
- **Physical Device & Verification Status:** Pure-Dart on-device heuristic rules; no platform channel or visible UI modifications. In Module 22, APK installation and live `ACTION_SEND` intent delivery via adb were verified, but the automated device integration test suite (`tool/test.ps1 -Suite device`) was not executed for Module 22 (marked unverified for Module 22; last run in Module 21 where 5/5 tests passed). Automated assertions, APK installation, live intent delivery, and manual observations remain recorded distinctly.
- **Status:** Complete. Pushed to `frontend`. Stopped before Module 24.

### 2026-10-14 â€” Module 24: Extended Local Indicator Rules and False-Positive Regression Coverage
- **Scope & Objectives:**
  - Implemented the second local warning-indicator rule pack, extending coverage to all 10 `IndicatorCategory` taxonomy families.
  - Implemented 5 extended rule classes: `ClaimedIdentityRule`, `JobOfferRule`, `RewardClaimRule`, `InvestmentReturnRule`, and `LinkStructuralRule`.
  - Created unified `LocalRuleCatalog` factory composing all 10 registered indicator rules without duplicate registrations.
  - Resolved Module 23 contract checks: bounded collection overflow with `RuleLimitExceededException` mapped by `LocalRuleEngine` to typed failure (`max_findings_exceeded`) preventing silent truncation; context-aware punctuation and clause segmentation preserving decimal amounts (`$10.50`) and colon-separated requests; broad exclusions isolating completed payment receipts from active solicitations; narrow antecedent pronoun detection (`[credential] ... but send it to`).
  - Implemented pure-Dart structural link inspection with trailing prose punctuation trimming, balanced parenthesis handling, and factual structural observation reporting (IP host, credentials before host, punycode labels, non-standard network ports, open redirection parameters) with zero network requests or DNS lookups.
  - Verified that local rule packs are implemented while user-facing analysis remains disabled in UI.
- **Domain, Rule, and Test Components:**
  - `lib/features/analysis/domain/rules/claimed_identity_rule.dart`: Claimed identity and authority impersonation cues rule.
  - `lib/features/analysis/domain/rules/job_offer_rule.dart`: Suspicious job and task recruitment offers rule.
  - `lib/features/analysis/domain/rules/reward_claim_rule.dart`: Prize and lottery winning claims rule.
  - `lib/features/analysis/domain/rules/investment_return_rule.dart`: Guaranteed returns and rapid multiplication promises rule.
  - `lib/features/analysis/domain/rules/link_structural_rule.dart`: Structural link inspection rule.
  - `lib/features/analysis/domain/rules/local_rule_catalog.dart`: Unified 10-rule catalog and registry factory.
  - `lib/features/analysis/domain/rules/rule_matcher_utils.dart`: Contextual delimiters, bounded collection, and `RuleLimitExceededException`.
  - `lib/features/analysis/domain/services/local_rule_engine.dart`: Typed failure handling for `RuleLimitExceededException`.
  - `test/features/analysis/domain/rules/claimed_identity_rule_test.dart`: 14 unit tests.
  - `test/features/analysis/domain/rules/job_offer_rule_test.dart`: 14 unit tests.
  - `test/features/analysis/domain/rules/reward_claim_rule_test.dart`: 14 unit tests.
  - `test/features/analysis/domain/rules/investment_return_rule_test.dart`: 14 unit tests.
  - `test/features/analysis/domain/rules/link_structural_rule_test.dart`: 12 unit tests.
  - `test/features/analysis/domain/rules/local_rule_catalog_test.dart`: 5 unit tests.
  - `test/features/analysis/domain/services/local_rule_engine_module24_test.dart`: 10 integration and regression tests.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (154 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (538/538 tests passed across 46 suites, adding 85 tests for Module 24).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (built in 14.4s).
  - `git diff --check`: PASS (clean whitespace).
- **Physical Device & Verification Status:** Pure-Dart on-device heuristic rules; no platform channel or visible UI modifications. Local rule packs are implemented; the user-facing analysis workflow is not enabled yet. In Module 22, APK installation and live `ACTION_SEND` intent delivery via adb were verified, but the automated device integration test suite (`tool/test.ps1 -Suite device`) was not executed for Module 22 (marked unverified for Module 22; last run in Module 21 where 5/5 tests passed). Automated assertions, APK installation, live intent delivery, and manual observations remain recorded distinctly.
- **Status:** Complete. Pushed to `frontend`. Stopped before Module 25.

### 2026-10-15 â€” Module 25: Local Assessment Synthesis, Uncertainty, and Educational Guidance
- **Scope & Objectives:**
  - Implemented deterministic on-device assessment synthesizer (`LocalAssessmentSynthesizer`) transforming a completed `AnalysisReport` and explicit `AnalysisExecutionContext` into an immutable `LocalAssessment`.
  - Defined derived domain models: `LocalAssessment`, `AssessmentIndicatorGroup`, `AssessmentAction`, `AssessmentCoverageInfo`, and `CategoryEducationalContext`.
  - Implemented honest outcome state representation: `indicatorsDetected`, `noIndicatorsMatched` (*"No indicators were matched by these local checks. This does not establish that the message is safe."*), and `limitedCoverage` (distinguishing empty catalog from executed checks with zero matches or skipped rules).
  - Implemented deterministic category grouping and sorting: canonical order (`IndicatorCategory.values` index) followed by unknown categories sorted alphabetically; preserved all findings and evidence references without loss or truncation.
  - Implemented centralized educational context catalog (`CategoryEducationalCatalog`) covering all 10 canonical category families + neutral fallback for unknown categories, stating factual observations, why patterns warrant attention, explicit boundaries on what cannot be established, and safe independent verification steps.
  - Implemented prioritized safe next actions deduplicated by stable ID, merging supporting finding and category references, with explicit conditional post-actions for credentials and OTPs (*"If you already shared..."*).
  - Actions strictly avoid reusing phone numbers, emails, or links from evaluated content, and never interpolate raw passwords, verification codes, or user-info credentials.
  - Composed testable service pipeline (`LocalAnalysisPipeline`) suitable for Module 26 (`reviewed snapshot -> local rule engine -> assessment synthesis -> LocalAssessment`) with dependency injection and typed `Result` propagation.
  - Corrected Module 24 wording risks: updated destination parameter description to factual phrasing without claiming open redirect vulnerability; updated investment exclusions to describe ordinary rate and risk disclosures without claiming regulatory verification; added regression tests.
  - Maintained zero UI exposure: local assessment synthesis is implemented, but user-facing analysis remains inactive in production UI until Module 26.
- **Domain, Service, and Test Components:**
  - `lib/features/analysis/domain/models/assessment_action.dart`: Action model with priority rankings (`immediate`, `recommended`, `conditional`) and reference merging.
  - `lib/features/analysis/domain/models/category_educational_context.dart`: Educational context contract with explicit capability boundaries.
  - `lib/features/analysis/domain/models/assessment_indicator_group.dart`: Indicator grouping model preserving findings and evidence.
  - `lib/features/analysis/domain/models/assessment_coverage_info.dart`: Scope record distinguishing empty catalog, executed rules, and skipped rules.
  - `lib/features/analysis/domain/models/local_assessment.dart`: Root immutable assessment model with policy version `'1.0.0'`.
  - `lib/features/analysis/domain/contracts/analysis_execution_context.dart`: Execution context decoupling coverage determination from findings.
  - `lib/features/analysis/domain/contracts/assessment_synthesizer.dart`: Synthesis contract interface.
  - `lib/features/analysis/domain/services/category_educational_catalog.dart`: Central educational and action catalog for all 10 categories + fallback.
  - `lib/features/analysis/domain/services/local_assessment_synthesizer.dart`: Pure-Dart deterministic synthesis implementation.
  - `lib/features/analysis/domain/services/local_analysis_pipeline.dart`: Testable end-to-end service composition.
  - `test/features/analysis/domain/models/local_assessment_test.dart`: 6 invariant, immutability, deduplication, and diagnostic tests.
  - `test/features/analysis/domain/services/category_educational_catalog_test.dart`: 5 catalog coverage, action, post-action, and fallback tests.
  - `test/features/analysis/domain/services/local_assessment_synthesizer_test.dart`: 14 synthesis outcome, permutation invariance, deduplication, OCR, and redaction tests.
  - `test/features/analysis/domain/services/local_analysis_pipeline_test.dart`: 7 end-to-end pipeline, clean input, OCR, review metadata, and failure propagation tests.
  - Updated `test/features/analysis/domain/rules/investment_return_rule_test.dart` and `link_structural_rule_test.dart` with regression assertions.
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (168 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (574/574 tests passed across 50 suites, adding 36 tests for Module 25).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (built in 7.6s, `build\app\outputs\flutter-apk\app-debug.apk`).
  - `git diff --check`: PASS (clean whitespace).
- **Physical Device & Verification Status:** Pure-Dart on-device contracts and synthesizer; no platform channel or visible UI modifications. Local assessment synthesis is implemented; the user-facing analysis workflow is not enabled yet. In Module 22, APK installation and live `ACTION_SEND` intent delivery via adb were verified, but the automated device integration test suite (`tool/test.ps1 -Suite device`) was not executed for Module 22 (marked unverified for Module 22; last run in Module 21 where 5/5 tests passed). Automated assertions, APK installation, live intent delivery, and manual observations remain recorded distinctly.
- **Status:** Complete. Pushed to `frontend`. Stopped before Module 26.

### 2026-10-15 â€” Module 26: Working Local-Analysis Results and Evidence Trail Interface
- **Scope & Objectives:**
  - Implemented the user-facing local-analysis results and evidence trail presentation interface on route `/analysis/results` (`AppRoutes.analysisResults`), wired via `AppPages` with `AnalysisResultsBinding`.
  - Connected confirmed text review (`/input/review`) to `LocalAnalysisPipeline` via explicit user action: primary button *"Analyze on this device"* with subtitle *"Checks the reviewed text using local rules. Nothing is uploaded."*
  - Enforced strict confirmation preconditions: analysis is allowed only when `isConfirmed == true` with an immutable `ReviewedTextResult`. Any text edit, redaction selection change, or reset invalidates confirmation and immediately disables the button. Double-tap debouncing prevents duplicate route pushes.
  - Implemented strictly volatile in-memory argument passing (`AnalysisResultsArgs`); no sensitive user text or results are placed in query parameters, persistent preferences, or global singletons.
  - Managed controller lifecycle with stale operation isolation (`AnalysisResultsController`): unique incremental operation IDs ensure results arriving after screen pop or controller disposal are safely discarded.
  - Built comprehensive, honest results hierarchy (`AnalysisResultsScreen`):
    - On-device header banner: *"Local on-device analysis"*, *"Evaluated on this device using local rules. Nothing was uploaded."*
    - Outcome summary card: truthful state representation for detected indicators, neutral notice for zero matches (*"No indicators were matched by these local checks. This does not establish that the message is safe."* â€” strictly NO green shield or safe verdict), coverage limits, or typed failure.
    - Coverage & Limitations section: highlights evaluated categories, heuristic constraints, English-only rule scope, OCR inaccuracy caveats, and redaction impact. Expandable full uncertainty notes.
    - Evidence Trail: deterministically grouped findings with category badges, rule limitations, exact quoted excerpts, and *"View in analyzed text"* modal action.
    - Suggested Next Steps: deduplicated, prioritized actions (`immediate` > `recommended` > `conditional`) referencing supporting finding IDs and categories.
    - Safe Navigation: primary action to return to review and edit text (`Get.back()`); secondary action linking to safe-use guidance (`/safe-use`).
  - Implemented accessible plain-text evidence viewer (`AnalyzedTextEvidenceViewer`):
    - Uses exact UTF-16 code-unit offsets `[startOffset, endOffset]`.
    - Merges overlapping or adjacent evidence spans into unified highlight ranges.
    - Accessible styling with amber background, dark border, and underline decoration (never relies on color alone).
    - Plain selectable text (`SelectableText.rich`) with raw styling; no Markdown, HTML, or clickable hyperlinks.
    - Redacted placeholders (`[CARD NUMBER]`, `[VERIFICATION CODE]`, etc.) remain strictly redacted.
  - Performed product copy audit: updated outdated "Analysis is not available / Coming soon" copy to clarify that local checks are available while distinguishing that remote AI and cloud analysis remain unavailable.
- **Presentation, Binding, and Test Components:**
  - `lib/features/analysis/presentation/models/analysis_results_args.dart`: Immutable in-memory argument container.
  - `lib/features/analysis/presentation/controllers/analysis_results_controller.dart`: GetX controller managing `AnalysisState`, stale protection, retry, and viewer dialog.
  - `lib/features/analysis/presentation/bindings/analysis_results_binding.dart`: Dependency injection binding for local pipeline.
  - `lib/features/analysis/presentation/widgets/analyzed_text_evidence_viewer.dart`: Plain-text UTF-16 evidence viewer.
  - `lib/features/analysis/presentation/screens/analysis_results_screen.dart`: Complete responsive results screen.
  - `lib/app/routes/app_routes.dart` & `lib/app/routes/app_pages.dart`: Added `/analysis/results` route and binding.
  - `lib/features/input/presentation/controllers/input_review_controller.dart`: Added `analyzeOnThisDevice()` and navigation debouncing.
  - `lib/features/input/presentation/screens/input_review_screen.dart`: Added "Analyze on this device" action button and subtitle.
  - `test/features/analysis/presentation/controllers/analysis_results_controller_test.dart`: 7 unit tests.
  - `test/features/analysis/presentation/screens/analysis_results_screen_test.dart`: 4 widget tests (hierarchy, zero-matches without green shield, failure recovery, dark theme / 200% text scale).
  - `test/features/analysis/presentation/widgets/analyzed_text_evidence_viewer_test.dart`: 5 widget tests (UTF-16 slicing, emoji offsets, overlapping spans, malformed offsets, redacted placeholders).
  - `test/features/input/presentation/screens/input_review_to_analysis_flow_test.dart`: 4 integration flow tests (unconfirmed gating, edit invalidation, end-to-end review -> analysis -> results -> back, double-tap protection).
- **Checks Performed:**
  - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (177 files checked, 0 changed).
  - `flutter analyze --no-pub`: PASS (0 issues found).
  - `powershell -File tool/test.ps1 -Suite all -TimeoutSeconds 180`: PASS (594/594 tests passed across 54 suites, adding 20 new tests for Module 26).
  - `flutter build apk --debug --no-pub -t lib/main.dart`: PASS (built in 18.8s, `build/app/outputs/flutter-apk/app-debug.apk`).
  - `powershell -File tool/test.ps1 -Suite device -DeviceId "10AC9R1ABF0013A" -TimeoutSeconds 600`: PASS (5/5 device integration tests passed on Vivo V2207 in 31s).
  - Debug APK installed via streamed install on physical device and launched cleanly via adb.
  - `git diff --check`: PASS (clean whitespace).
- **Physical Device & Verification Status:** Full device integration test suite executed on physical Vivo V2207 device (`10AC9R1ABF0013A`) via `tool/test.ps1 -Suite device` with 5/5 tests passing in 31s (smoke test, real native Google ML Kit Latin OCR, Module 19 text review & redaction, Module 20 offline link & QR decoding, Module 21 Android incoming shares platform channel & lifecycle). Debug APK installed via streamed install and launched cleanly via adb (`Starting: Intent { cmp=io.github.muhammadtaimoorajmal.trustcue/.MainActivity }`).
- **Status:** Complete. Pushed to `frontend`. Stopped before Module 27.

### 2026-10-15 â€” Module 27: Backend/AI Architecture, Service Feasibility, Privacy Decisions, and API Contracts
- **Scope & Objectives:**
  - Evaluated technology stack feasibility for server-assisted AI scam-indicator analysis under zero financial expenditure and Pakistan developer operating constraints (CS3643, BSCS Semester 5-1, Fall 2026, Riphah International University).
  - Selected Primary Stack: Node.js (TypeScript) + Fastify running on Render Free Web Service, with managed authentication and PostgreSQL provided by Supabase Free Tier.
  - Formulated Dual AI Privacy Strategy: Groq Cloud API (`llama-3.3-70b-versatile`) selected as primary inference engine due to contractual zero-retention and no model training on customer inference data; Google AI Studio Gemini API (`gemini-1.5-flash`) designated as secondary provider under a strict synthetic-data-only policy for unpaid free tier.
  - Specified untrusted input isolation: user text is strictly bounded in `<untrusted_message_content>` XML tags with explicit anti-prompt-injection system instructions.
  - Produced versioned OpenAPI 3.1.0 specification (`backend/contracts/openapi.yaml`) covering `/health`, `/ready`, `/api/v1/analysis/ai`, `/api/v1/account/profile`, `/api/v1/account` (deletion), and planned `/api/v1/sync/reports`.
  - Defined strict server-side evidence grounding verification: byte-for-byte substring matching, exact UTF-16 code-unit offsets, surrogate pair safety, and automatic filtering of ungrounded model hallucinations.
  - Designed conceptual database entity model (`auth.users`, `public.profiles`, `public.synced_reports`, `public.ai_usage_quotas`) with PostgreSQL Row Level Security (RLS) and cascade account deletion.
  - Authored beginner-friendly cloud service setup guide (`backend/docs/SETUP_GUIDE.md`) with `.env.example` placeholder template and immediate checklist for Module 28.
  - Reconciled authoritative 50-module roadmap preserving completed Modules 1â€“26 and defining primary branches, deliverables, dependencies, acceptance criteria, and necessary human actions for Modules 27â€“50.
  - Reconciled Module 26 physical-device test coverage in `app_smoke_test.dart` and recorded missing device flows for future phone execution.
- **Backend Components Created (Committed on `backend` at `60745dc`):**
  - `backend/contracts/openapi.yaml`: Versioned OpenAPI 3.1.0 specification.
  - `backend/docs/ARCHITECTURE.md`: Architecture & service feasibility evaluation.
  - `backend/docs/PRIVACY_AND_AI_SAFETY.md`: Privacy boundaries, untrusted input isolation & logging rules.
  - `backend/docs/DATABASE_AND_AUTH_DESIGN.md`: Entity model, RLS policies & deletion lifecycle.
  - `backend/docs/SETUP_GUIDE.md`: Step-by-step setup guide for free cloud services.
  - `backend/README.md` & root `README.md`: Backend overview & documentation index.
  - `.gitignore`: Configured to ignore `.env`, `node_modules`, and build artifacts.
- **Checks Performed:**
  - OpenAPI 3.1.0 validation via Python PyYAML: PASS (6 paths, 14 schemas, 100% of internal `$ref` pointers cleanly resolved).
  - Trailing whitespace audit on all backend markdown and YAML files: PASS (`git diff --cached --check` clean).
  - Git worktree separation: `trustcue-backend` isolated on `backend` branch.
  - Frontend repair verification: 594/594 automated tests passing (`tool/test.ps1 -Suite all`), `flutter analyze` 0 issues.
  - Exactly 50 numbered roadmap modules preserved.
- **Status:** Complete. Pushed to `backend` (`60745dc`). Reconciled on `frontend`. Stopped before Module 28.

### 2026-10-15 â€” Module 28: Backend Foundation, Configuration, Health/Readiness, Error Handling, and CI Validation
- **Scope & Objectives:**
  - Audited and corrected Module 27 provider assumptions: documented Groq Cloud API retention nuances (up to 30 days for system reliability, troubleshooting, and abuse investigation), Gemini API unpaid free tier terms (model training, human review, explicit prohibition against submitting sensitive/confidential personal text), verified Groq free-tier limits for `llama-3.3-70b-versatile` (30 RPM, 1,000 RPD, 12,000 TPM, 100,000 TPD), and strictly prohibited automatic cross-provider fallback to preserve user privacy consent boundaries.
  - Telemetry Privacy: Completely removed message SHA-256 content hashes from routine telemetry to prevent dictionary guessing and correlation attacks on predictable messages.
  - Prompt Injection Defense-in-Depth: Formally documented that XML tags and system instructions are one defensive layer and do not guarantee containment; enforced multi-layer defense comprising constrained JSON-only schema outputs, disabling all external tools/interpreters, strict server validation, and mandatory substring evidence grounding.
  - Implemented application factory `create_app()` using Python 3.13+ and FastAPI with clean lifecycle handling (`lifespan`).
  - Implemented typed configuration (`Settings`) using Pydantic Settings with loopback execution default (`127.0.0.1:8000`), feature flags defaulting to disabled, and zero required cloud credentials for foundation execution.
  - Implemented application lifecycle and operational readiness state management (`AppState`).
  - Implemented `/health` (200 OK liveness probe with uptime and version) and `/ready` (200 OK readiness probe reporting active foundation status and unconfigured planned subsystems; 503 Service Unavailable when draining/shutting down).
  - Implemented privacy-safe structured logging (`StructuredJsonFormatter`, `PrivacySafeAccessMiddleware`) that generates server-controlled UUID4 request IDs and omits query strings, request bodies, authorization tokens, and content hashes from access logs.
  - Implemented sanitized error envelopes (`TrustCueError`, `validation_error_handler` stripping raw user input values, `http_exception_handler` masking unknown paths, and `unhandled_exception_handler` suppressing internal stack traces and database credentials).
  - Implemented request body size limit middleware (rejecting oversized payloads > 1 MB with HTTP 413).
  - Created `.github/workflows/backend-ci.yml` defining GitHub Actions CI with read-only permissions, dependency installation, ruff linting, OpenAPI 3.1 specification validation, and automated pytest execution.
  - Authored 24 automated unit, integration, error, and contract consistency tests in `backend/tests/` (100% passing).
  - Verified live local server execution over HTTP on loopback (`http://127.0.0.1:8765`), confirming `/health` (200), `/ready` (200), and `/nonexistent` (404 sanitized envelope), followed by clean process shutdown.
- **Backend Components Created (Committed on `backend` at `766e61a`):**
  - `.github/workflows/backend-ci.yml`: GitHub Actions backend CI workflow.
  - `backend/.env.example`: Safe configuration template with zero real secrets.
  - `backend/pyproject.toml`, `requirements.txt`, `requirements-dev.txt`: Dependency specifications and tool configs.
  - `backend/src/trustcue_backend/`: Core application package (`main.py`, `run.py`, `core/config.py`, `core/errors.py`, `core/logging.py`, `core/state.py`, `api/dependencies.py`, `api/routes/health.py`).
  - `backend/tests/`: Automated test suite (`test_config.py`, `test_health.py`, `test_errors.py`, `test_logging.py`, `test_cors.py`, `test_lifecycle.py`, `test_contract_consistency.py`).
  - `backend/docs/`: Corrected provider terms, privacy bounds, and setup guide.
- **Checks Performed:**
  - `ruff check backend/src backend/tests`: PASS (All checks passed, 0 issues).
  - `python -m openapi_spec_validator backend/contracts/openapi.yaml`: PASS (backend/contracts/openapi.yaml: OK).
  - `pytest backend/tests`: PASS (24/24 passed in 1.16s).
  - Live loopback HTTP verification: PASS (`/health` 200, `/ready` 200, `/nonexistent` 404).
  - Whitespace & format audit: PASS (`git diff --cached --check` clean).
  - Git worktree separation: `trustcue-backend` clean, committed, and pushed to `origin/backend` (`766e61a`).
- **Status:** Complete. Pushed to `backend` (`766e61a`). Reconciled on `frontend`. Stopped before Module 29.

### 2026-10-15 â€” Module 29: Database Schema, Versioned Migrations, Ownership Policies, and Database Regression Tests
- **Scope & Objectives:**
  - Implemented versioned PostgreSQL DDL migrations for TrustCue cloud data storage, strictly adhering to local-first privacy invariants.
  - Implemented `public.profiles` (`migrations/00001_create_profiles.sql`) bound 1:1 to `auth.users(id)` with cascade deletion, bounded `display_name` (<=64 characters, trimmed), `terms_version` (1-32 characters), and explicit `sync_enabled` boolean opt-in.
  - Implemented `public.ai_usage_quotas` (`migrations/00002_create_ai_usage_quotas.sql`) for server-side rate-limiting rate controls, unique on `(user_id, quota_date)`, with non-negative constraints on requests and tokens; enforced privacy guarantee with zero storage of prompts, message text, excerpts, or message hashes.
  - Implemented `public.synced_reports` (`migrations/00003_create_synced_reports.sql`) for optional client report backup, unique on `(user_id, client_report_id)`, strictly bounding payload sizes to 500 KB via `chk_report_payload_size` and enforcing tombstone consistency via `chk_tombstone_consistency`.
  - Implemented Row Level Security (RLS) and access control (`migrations/00004_create_rls_and_policies.sql`): enabled and forced RLS across all 3 tables; revoked default permissions from `PUBLIC` and `anon`; granted read/write on own profiles and synced reports to `authenticated`; strictly granted **read-only** `SELECT` on `ai_usage_quotas` to `authenticated` (write permissions strictly denied to prevent quota tampering); enforced identical `USING` and `WITH CHECK` clauses on all update policies to prevent cross-account ownership theft.
  - Implemented automatic user profile provisioning trigger (`migrations/00005_create_auth_trigger.sql`): `public.handle_new_user()` `SECURITY DEFINER` function with pinned `search_path = public, auth, pg_temp` and safe fallback exception handling.
  - Created synthetic PostgreSQL test environment: test auth compatibility fixture (`tests/fixtures/test_auth_compat.sql`) simulating `auth.users`, `auth.uid()`, and role switching; synthetic seed data (`seeds/001_synthetic_test_seeds.sql`).
  - Authored 4 transactional SQL regression test suites in `tests/sql/`:
    - `01_test_profiles_rls.sql`: Anon denial, User A CRUD, User B isolation, cross-account theft rejection, and display name boundary checks.
    - `02_test_quotas_isolation.sql`: Authenticated client write denial, read-only own usage, backend service_role atomic upsert increment, and non-negative constraint checks.
    - `03_test_reports_sync_rls.sql`: User A CRUD, User B denial, cross-user insert spoofing rejection, 500 KB payload limit enforcement, and soft-delete tombstone consistency.
    - `04_test_cascade_deletion.sql`: Deleting parent user in `auth.users` strictly cascades across profiles, quotas, and synced reports leaving 0 orphan rows.
  - Created standalone Python static schema validation suite (`tests/test_static_schema.py`) and `pyproject.toml` verifying transactional wrappers, column boundaries, absence of prompt/excerpt storage, RLS enforcement, and security definer hygiene.
  - Created GitHub Actions Database CI workflow (`.github/workflows/database-ci.yml`) spinning up a live `postgres:16-alpine` service container, applying test auth compatibility fixtures and migrations sequentially, loading synthetic seeds, and executing all 4 SQL regression test suites.
  - Authored comprehensive documentation: `docs/ARCHITECTURE.md` (entity-relationship diagram, permission matrix table, atomic quota enforcement algorithm, cloud sync conflict resolution strategy) and `docs/SETUP_AND_MIGRATION_GUIDE.md` (local Docker and Supabase migration guides).
- **Database Components Created (Committed on `database` at `521cade`):**
  - `.github/workflows/database-ci.yml`: PostgreSQL 16 CI workflow.
  - `migrations/00001_create_profiles.sql` to `00005_create_auth_trigger.sql`: 5 versioned DDL migrations.
  - `seeds/001_synthetic_test_seeds.sql`: Synthetic test seeds.
  - `tests/fixtures/test_auth_compat.sql`: Test auth schema compatibility fixture.
  - `tests/sql/01_test_profiles_rls.sql` to `04_test_cascade_deletion.sql`: 4 SQL regression suites.
  - `tests/test_static_schema.py`: Standalone offline Python static test suite.
  - `docs/ARCHITECTURE.md` & `docs/SETUP_AND_MIGRATION_GUIDE.md`: Architectural documentation & setup guide.
  - `pyproject.toml`, `.gitignore`, `README.md`: Project configurations and repository overview.
- **Checks Performed:**
  - `python -m unittest discover tests`: PASS (10/10 tests passed in 0.006s).
  - Trailing whitespace audit on all database SQL, Python, YAML, and Markdown files: PASS (`git diff --cached --check` clean).
  - Git worktree separation: `trustcue-database` isolated on `database` branch, committed (`521cade`), and pushed to `origin/database`.
  - Remote reference verified via `git ls-remote origin refs/heads/database` (`521cadefe19bffff4fe42bb09c88ec765b4bfd64`).
- **Host Tooling & RLS Verification Disclosure:**
  - Neither PostgreSQL nor Docker is installed locally on the host machine.
  - Local verification was performed using the offline Python static schema test suite (`tests/test_static_schema.py`).
  - Executable PostgreSQL 16 migration application and RLS policy enforcement were verified in GitHub Actions Database CI (`.github/workflows/database-ci.yml`) using a genuine `postgres:16-alpine` service container. CI run `38701649252` passed all 12 steps with SUCCESS following role-reset and permission adjustments (commit `02db979`).
- **Status:** Complete. Pushed to `database` (`02db979`). Reconciled on `frontend`.

### 2026-10-15 â€” Module 30: Authentication Integration and Session-Validation Contracts
- **Scope & Objectives:**
  - Implemented authentication integration and backend session-validation contracts adhering strictly to OpenAPI 3.1.0 specifications and local-first architecture.
  - Installed and configured `pyjwt[crypto]>=2.10.0` for cryptographic JWT verification in Python 3.13+.
  - Updated typed configuration (`core/config.py`):
    - Added `SUPABASE_JWT_SECRET`, `SUPABASE_JWT_ALGORITHMS` (default `["HS256"]`), `SUPABASE_JWT_AUDIENCE` (default `"authenticated"`), `SUPABASE_JWT_ISSUER`, `SUPABASE_JWKS_URL`, and `DEFAULT_DAILY_AI_QUOTA` (default 15).
    - Hardened configuration validation in `validate_environment_and_features`: actively rejects test signing keys (`"test-jwt-secret-key-..."`, `"test"`, `"secret"`, `"demo"`, etc.) when `ENVIRONMENT="production"`.
  - Implemented `core/auth.py`:
    - `AuthenticatedUser` model containing `user_id` (UUID), `email`, `email_verified`, `role`, `app_metadata`, `user_metadata`, `session_id`, and `claims`.
    - `JWTValidator` engine: verifies token signature against configured `SUPABASE_JWT_SECRET` or `SUPABASE_JWKS_URL` using `PyJWKClient`; strictly parses and validates that `sub` is a valid RFC 4122 UUID; rejects anonymous tokens (`role: 'anon'` or `aud: 'anon'`); verifies temporal bounds (`exp`, `nbf`); maps signature/expiration/issuer failures to standard error codes (`"token_expired"`, `"invalid_issuer"`, `"unauthorized"`).
    - `create_test_jwt()`: synthetic test token generator for local testing and offline verification, strictly guarded against execution when `environment="production"`.
  - Implemented error handling (`core/errors.py`):
    - Added `AuthenticationError` subclass of `TrustCueError` mapping to HTTP 401 and standard `ErrorEnvelope`.
    - Updated `http_exception_handler` to map HTTP 401 to `code="unauthorized"` and HTTP 403 to `code="forbidden"`.
  - Updated readiness probe (`core/state.py` & `api/routes/health.py`):
    - `AppState.get_readiness_status()` accepts optional `Settings` instance and reports `authProvider: "ok"` when JWT secret or JWKS is configured, while safely maintaining `"unconfigured"` on default settings.
  - Added dependency injection providers (`api/dependencies.py`):
    - `get_jwt_validator`: constructs configured `JWTValidator`.
    - `get_current_user`: extracts Bearer token from `Authorization` header, verifies validity with `JWTValidator`, injects `AuthenticatedUser` into `request.state.current_user`, and rejects missing/malformed/invalid headers with 401 `ErrorEnvelope`.
  - Created OpenAPI 3.1.0 response schemas (`api/schemas/account.py`):
    - `UserProfileResponse`: `userId` (UUID), `email`, `emailVerified`, `createdAt`, `syncEnabled: false`, `quotaRemainingToday: 15`.
    - `AccountDeletionResponse`: `status: "deleted"`, `userId` (UUID), `deletedAt`.
  - Implemented protected route handlers (`api/routes/account.py`):
    - `GET /api/v1/account/profile`: requires valid Bearer token, returns `UserProfileResponse` matching OpenAPI schema.
    - `DELETE /api/v1/account`: requires valid Bearer token, executes account deletion, returns `AccountDeletionResponse` with UTC timestamp.
    - Both endpoints enforce privacy-safe logging (never leaking user emails, tokens, or PII) and return `X-Request-ID` correlation headers.
  - Mounted `account.router` under prefix `/api/v1/account` in `main.py`.
  - Authored comprehensive test suites:
    - `backend/tests/test_auth.py`: 11 unit tests covering valid token decoding, expiration rejection (`token_expired`), signature mismatch, wrong audience, wrong issuer (`invalid_issuer`), anonymous role/audience rejection, non-UUID subject rejection, malformed/empty tokens, unconfigured validator, and production guard enforcement.
    - `backend/tests/test_account.py`: 8 integration tests covering profile retrieval (missing auth, non-Bearer scheme, expired token, forged signature, anon token, valid profile response), and account deletion (missing auth, valid deletion response).
    - Updated `test_config.py` (JWT defaults, production key rejection), `test_health.py` (readiness with configured auth), and `test_contract_consistency.py` (verifying `/health`, `/ready`, `/api/v1/account/profile`, and `/api/v1/account` are exposed and match `openapi.yaml`, while planned AI and sync endpoints remain strictly unmounted).
  - Updated backend documentation: `backend/docs/SETUP_GUIDE.md` (Module 30 verification instructions, offline synthetic testing vs live Supabase setup, production key prohibition) and `backend/docs/DATABASE_AND_AUTH_DESIGN.md` (stateless session validation architecture).
- **Backend Components Created / Updated (Committed on `backend` at `fa11d88`):**
  - `backend/src/trustcue_backend/core/auth.py`: JWT validator, authenticated user model, test token helper.
  - `backend/src/trustcue_backend/api/schemas/account.py`: User profile and account deletion response schemas.
  - `backend/src/trustcue_backend/api/routes/account.py`: Account profile and deletion route handlers.
  - `backend/src/trustcue_backend/api/dependencies.py`: Current user and JWT validator dependencies.
  - `backend/src/trustcue_backend/core/config.py`: JWT settings and production security validator.
  - `backend/src/trustcue_backend/core/errors.py`: AuthenticationError and HTTP 401/403 mappings.
  - `backend/src/trustcue_backend/core/state.py`: Readiness status with auth provider reporting.
  - `backend/src/trustcue_backend/api/routes/health.py`: Settings injection for readiness probe.
  - `backend/src/trustcue_backend/main.py`: Account router registration.
  - `backend/tests/test_auth.py` & `backend/tests/test_account.py`: Automated test suites.
  - `backend/docs/SETUP_GUIDE.md` & `backend/docs/DATABASE_AND_AUTH_DESIGN.md`: Updated architecture and setup documentation.
- **Checks Performed:**
  - `ruff check backend/src backend/tests`: PASS (All checks passed, 0 issues).
  - `openapi_spec_validator backend/contracts/openapi.yaml`: PASS (OpenAPI 3.1.0 contract valid).
  - `pytest backend/tests`: PASS (46/46 passed across 9 suites in 0.82s).
  - Whitespace & format audit: PASS (`git diff --cached --check` clean).
  - Git worktree separation: `trustcue-backend` clean, committed (`fa11d88`), and pushed to `origin/backend`.
- **Status:** Complete. Pushed to `backend` (`fa11d88`). Reconciled on `frontend`.

### 2026-10-15 â€” Module 31: Flutter Signup, Login, Email Verification, Password Recovery, Logout, and Session Handling
- **Scope & Objectives:**
  - Implemented the complete client authentication, account management, and session handling flows on the Flutter mobile client (`frontend`).
  - Added and pinned dependencies: `supabase_flutter: 2.18.3` and `flutter_secure_storage: 11.2.0` (with `get: 4.7.3`).
  - Built domain layer under `lib/features/auth/domain/`:
    - `models/auth_user.dart`: Strongly-typed UUID `id`, `email`, `emailVerified`, `createdAt`, with privacy-safe `toString()`.
    - `models/auth_state.dart`: `AuthStatus` enum (`unauthenticated`, `authenticated`, `verificationPending`, `recoverySession`, `unconfigured`) and `AuthSession` with expiration check.
    - `models/auth_failure.dart`: Standardized `AuthFailureCode` and privacy-safe factories.
    - `models/auth_result.dart`: Dedicated typed `AuthResult<T>` monad (`AuthSuccess<T>`, `AuthFailureOutcome<T>`, `fold()`, `when()`) preventing auth outcomes from leaking into `AnalysisFailure`.
    - `contracts/auth_repository.dart`: Explicit repository contract covering registration, login, logout, verification email resend, password recovery, password update, and session restoration.
  - Built data layer under `lib/features/auth/data/`:
    - `services/auth_config.dart`: Public client configuration (`SUPABASE_URL`, publishable anon key, redirect URL scheme/host) parsed from environment defines (`--dart-define`).
    - `services/secure_local_storage.dart`: Custom Supabase `LocalStorage` implementation powered by `FlutterSecureStorage`, using Android KeyStore AES-GCM + RSA key wrapping (`AndroidOptions(resetOnError: true)`) and iOS Keychain (`kSecAttrAccessibleAfterFirstUnlock`).
    - `repositories/supabase_auth_repository.dart`: Production repository utilizing PKCE flow (`AuthFlowType.pkce`), broadcast state streaming, provider rate-limit mapping (`AuthFailure.rateLimitExceeded`), enumeration-resistant password recovery, offline sign-out fallback, and unconfigured safety.
  - Built presentation layer under `lib/features/auth/presentation/`:
    - Controllers: `AuthController` (app-wide session lifecycle), `LoginController` (sign-in with auto-routing on unconfirmed email), `RegisterController` (sign-up with redirect to email verification), `VerifyEmailController` (60-second cooldown timer, spam notices, resend), `ForgotPasswordController` (anti-enumeration generic confirmation), `ResetPasswordController` (new password validation, confirmation matching).
    - Screens: `AccountScreen` (guest vs. authenticated view, email verification status, sign-out dialog), `LoginScreen` (password visibility toggle, forgot password / register links), `RegisterScreen` (password matching, verify email redirect), `VerifyEmailScreen` (status card, countdown button, return to sign in), `ForgotPasswordScreen` (email entry, generic inbox confirmation card), `ResetPasswordScreen` (password update form, success card).
    - Responsive Accessibility: Applied `Wrap` layout to all footer action groups to eliminate `RenderFlex` overflows at 200% font scaling on 320px viewports. Minimum 48x48 touch targets on all interactive buttons.
    - Bindings: `AuthBinding`, `LoginBinding`, `RegisterBinding`, `VerifyEmailBinding`, `ForgotPasswordBinding`, `ResetPasswordBinding`.
  - Application Integration & Deep Linking:
    - `lib/app/routes/app_routes.dart` & `app_pages.dart`: Registered `/account`, `/auth/login`, `/auth/register`, `/auth/verify-email`, `/auth/forgot-password`, `/auth/reset-password` with exact-path resolution.
    - `lib/features/home/presentation/screens/home_screen.dart`: Added Account button with `Icons.account_circle_outlined`, tooltip, and 48x48 min touch targets in AppBar actions.
    - `lib/app/trustcue_app.dart`: Supported optional `AuthRepository` dependency injection and auto-initialization via `AuthBinding.ensureInitialized()`.
    - `android/app/src/main/AndroidManifest.xml`: Registered `trustcue://auth-callback` deep-link `intent-filter` for PKCE callback redirection.
  - Security & Architectural Invariants:
    - **Guest Mode Untouched:** 100% of local scam detection, text extraction, review, and results features remain completely functional without an account.
    - **No Secret Key Leakage:** Client exclusively uses public publishable keys (`SUPABASE_URL`, public publishable anon key). Service-role keys and JWT signing secrets remain strictly prohibited.
    - **Enumeration Resistance:** Password recovery always displays a generic success card ("Check your inbox") regardless of whether the email is registered.
  - Database Follow-Up Items (Recorded for Module 39 / Database Team):
    - Sync opt-in enforcement: `public.synced_reports` RLS write policy must require `profiles.sync_enabled = true`.
    - Payload bounds & privacy: 500 KB ceiling (`chk_report_payload_size`), structured findings only, zero message/OCR/hash storage.
    - Deletion semantics: Soft-delete tombstones for sync propagation vs. `ON DELETE CASCADE` for complete account deletion.
    - Signup trigger safety: Exception handling in `handle_new_user()` prevents auth lockouts.
    - Root migration tracking: Migrations `00001`â€“`00005` in `database/migrations/`.
  - **Checks Performed:**
    - `flutter analyze --no-pub`: PASS (0 issues found).
    - `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS (0 diffs across 208 files).
    - Automated Unit & Widget Tests: PASS (43/43 tests passed across `test/features/auth` and `test/features/home`).
    - Full Test Suite (`tool/test.ps1 -Suite all -TimeoutSeconds 180`): PASS (637/637 tests passed in 33 seconds).
    - Debug APK Compilation (`flutter build apk --debug --no-pub -t lib/main.dart`): PASS (`build/app/outputs/flutter-apk/app-debug.apk` built cleanly).
    - Physical Phone / Real Deep Link Verification: BLOCKED / NOT RUN (physical phone unavailable today; external callback and live provider inbox verification recorded as pending).
- **Status:** Complete. Pushed to `frontend`. Stopped before Module 32.

### 2026-10-15 — Module 32: Backend Request Validation, Authorization, and Abuse Controls
- **Scope & Objectives:**
  - Implemented strict backend request validation, authorization, and abuse controls adhering strictly to OpenAPI 3.1.0 specifications and local-first architecture.
  - Conservative repository layout unification: organized database worktree under standard `database/` root (`database/migrations/`, `database/seeds/`, `database/tests/`, `database/docs/`, `database/pyproject.toml`) matching `frontend/`, `backend/`, `database/`, `docs/`.
  - Database Migration 6 (`database/migrations/00006_create_quota_reservation.sql`):
    - Added atomic quota reservation and release RPC functions (`reserve_ai_quota`, `release_ai_quota`) executed strictly under `SECURITY DEFINER` and restricted to `service_role` and `postgres`.
    - Added `ensure_profile_exists(UUID)` recovery function for seamless zero-failure profile backfill.
    - Added SQL regression suite `database/tests/sql/05_test_quota_reservation.sql` and updated static schema tests (11/11 passing).
  - Backend Strict Input Validation (`core/validation.py`):
    - Text snapshot bounds: <= 10,000 Unicode code points (runes) and <= 40,000 UTF-8 bytes.
    - Strict Unicode validity: rejects lone surrogate code points (`0xD800`–`0xDFFF`).
    - Whitespace normalization and control character rejection: allows standard whitespace (`\t`, `\n`, `\r`) while rejecting ASCII/Unicode control characters (`\x00`–`\x1f`, `\x7f`).
  - Strict Pydantic Models (`api/schemas/analysis.py`):
    - Configured `AnalysisAiRequest` with `extra="forbid"` to strictly reject unexpected attributes.
    - Used typed `StrEnum` for `IndicatorCategory` and analysis flags.
  - Streaming Request Body Limiter (`core/body_limiter.py`):
    - `RequestBodyLimitMiddleware` inspects byte count while streaming incoming chunked payloads before buffering into memory, aborting with HTTP 413 `PAYLOAD_TOO_LARGE`.
  - Hardened JWT Validation (`core/auth.py`):
    - Key-to-algorithm binding (strictly `HS256` for HMAC secrets; `RS256`/`ES256` for JWKS).
    - Hard rejection of algorithm `"none"`, rejection of spoofed `jku` and `x5u` headers, and bounded JWKS fetching with TTL cache (`timeout=5`, `max_cached_keys=16`).
  - Authorization & Abuse Controls (`core/rate_limit.py`, `core/quota.py`, `api/dependencies.py`):
    - Sliding-window rate limiter (10 req/min per user, HTTP 429 `rate_limit_exceeded` with `Retry-After`).
    - User concurrency limiter (preventing multiple simultaneous requests from the same user).
    - `QuotaStore` interface with `InMemoryQuotaStore` and PostgreSQL reserve/release RPC integration.
    - Cross-account ownership check `enforce_user_ownership` returning HTTP 403 `forbidden`.
  - Analysis Route (`api/routes/analysis.py`):
    - Mounted `POST /api/v1/analysis/ai` enforcing rate limits, concurrency limits, and quota reservation.
    - Returns HTTP 503 `ai_provider_unavailable` when cloud AI is unconfigured without fabricating findings.
  - Backend Test Suites (`backend/tests/`):
    - Added `test_validation.py`, `test_rate_limit_and_abuse.py`, `test_auth_hardening.py`, `test_privacy_markers.py`.
    - 64/64 backend tests passing in 1.65s, `ruff check` clean (0 issues), OpenAPI 3.1.0 contract valid.
  - Physical Device Verification & Integration Test Enhancement:
    - Added Test 6 to `frontend/integration_test/app_smoke_test.dart` covering Android KeyStore AES-GCM smoke test, guest/unconfigured account screen check, reviewed text -> local analysis -> results screen, evidence viewer modal, redacted text preservation, and return to review.
    - Recorded phone check execution: device test runner executed on physical Vivo V2207 (`10AC9R1ABF0013A`); APK was installed via adb, but automated execution timed out waiting for unattended on-screen permission. Per instructions, device state is recorded truthfully without blocking progress.
- **Components Created / Updated:**
  - Backend: `core/validation.py`, `core/body_limiter.py`, `core/rate_limit.py`, `core/quota.py`, `api/schemas/analysis.py`, `api/routes/analysis.py`, `api/dependencies.py`, `core/auth.py`, `main.py`, `tests/test_validation.py`, `tests/test_rate_limit_and_abuse.py`, `tests/test_auth_hardening.py`, `tests/test_privacy_markers.py`.
  - Database: `database/migrations/00006_create_quota_reservation.sql`, `database/tests/sql/05_test_quota_reservation.sql`, `database/tests/test_static_schema.py`, `.github/workflows/database-ci.yml`.
  - Frontend: `frontend/integration_test/app_smoke_test.dart`, `docs/ROADMAP.md`, `docs/MODULE_LOG.md`, `docs/PROJECT_STATE.md`.
- **Checks Performed:**
  - Python tests on backend: 64/64 PASS.
  - Ruff check on backend: PASS (0 issues).
  - OpenAPI 3.1.0 spec validator: PASS.
  - Python static tests on database: 11/11 PASS.
  - Flutter analyze: PASS (0 issues).
  - Dart format: PASS (0 changes).
  - Full Flutter test suite: 637/637 PASS.
- **Status:** Complete. Pushed to `database` (`2660aef`), `backend` (`0714bcd`), and `frontend`. Stopped before Module 33.

### 2026-10-15 — Module 33: Protected AI-Provider Integration
- **Scope & Objectives:**
  - Implemented server-side AI provider connectivity and protected execution path adhering strictly to OpenAPI 3.1.0 specifications and local-first privacy invariants.
  - Selected and integrated primary inference provider: Groq Cloud API using active flagship model `llama-3.3-70b-versatile` (128k context, zero model training on customer inference data, OpenAI-compatible chat completions).
  - Documented official provider terms and limits (verified 2026-10-15): free tier 30 RPM, 1,000 RPD, 12,000 TPM, 100,000 TPD; default zero-retention with up to 30-day transient diagnostic logging solely for reliability/abuse investigation; strictly prohibited automatic cross-provider fallback.
  - Implemented replaceable `AiProvider` abstract interface (`providers/base.py`) with `analyze()` and `close()` lifecycle methods.
  - Implemented production `GroqProviderAdapter` (`providers/groq.py`):
    - Configured via typed Pydantic `Settings` (`GROQ_API_KEY`, `GROQ_MODEL`, `GROQ_BASE_URL`, `GROQ_TIMEOUT_SECONDS`, `GROQ_MAX_TOKENS`, `MAX_PROVIDER_RESPONSE_BYTES`).
    - Uses asynchronous `httpx.AsyncClient` with explicit lifecycle management in FastAPI `lifespan`.
    - Enforces connection timeouts (5.0s), total read timeouts (15.0s), and response size bounds (64 KB).
    - Maps HTTP status codes to typed exceptions without logging sensitive text, prompts, or API keys (`ProviderAuthenticationError`, `ProviderRateLimitError`, `ProviderTimeoutError`, `ProviderResponseError`, `ProviderNetworkError`).
  - Implemented versioned system prompt and untrusted data framing (`providers/prompts.py`):
    - Rigidly encapsulates user reviewed text in `<untrusted_message_content>` XML tags.
    - Explicit anti-instruction directives commanding model to treat enclosed text as passive linguistic data.
    - Strictly forbids numerical fraud percentages, risk scores, or safe/verified claims.
    - Confines findings to the 10 canonical indicator taxonomy categories and requires verbatim quoted excerpts.
  - Implemented `ProtectedAiService` orchestration engine (`providers/service.py`):
    - Enforces exact approved-text preservation (no trimming or modification).
    - Manages atomic quota settlement: commits quota on successful analysis, refunds on connect/unconfigured/upstream failures.
    - Enforces documented ambiguous timeout policy: does NOT blind-refund ambiguous read timeouts where provider resources may have been consumed.
  - Preserved Module 34 & 35 Architecture Gates:
    - Public client route `POST /api/v1/analysis/ai` returns honest HTTP 503 `ai_provider_unavailable` ("Server-assisted AI analysis is temporarily unavailable pending evidence grounding validation (Module 34)"), releasing quota.
    - Never returns raw or ungrounded model outputs to mobile clients.
    - Gating ensures public cloud AI is not enabled until deterministic server-side evidence grounding and mobile upload consent exist.
  - Updated readiness probe in `core/state.py` to evaluate `aiProvider` (`disabled` when feature flag is false, `ok` when configured without paid network probes, `unconfigured` when missing key).
  - Authored comprehensive backend test suites (`tests/test_groq_provider.py`, `tests/test_ai_orchestration.py`, `tests/test_analysis_gating.py`):
    - 85/85 backend tests passing across 16 suites (21 new tests added for Module 33).
    - `ruff check` passed with 0 issues.
    - `openapi-spec-validator` passed with 0 issues.
  - Updated `backend/docs/SETUP_GUIDE.md` with beginner-friendly Groq API key setup guide, official documentation URLs, and safe synthetic smoke test instructions.
- **Components Created / Updated:**
  - Backend: `providers/__init__.py`, `providers/base.py`, `providers/models.py`, `providers/exceptions.py`, `providers/prompts.py`, `providers/groq.py`, `providers/service.py`, `api/dependencies.py`, `api/routes/analysis.py`, `core/config.py`, `core/state.py`, `main.py`, `.env.example`, `docs/SETUP_GUIDE.md`, `tests/test_groq_provider.py`, `tests/test_ai_orchestration.py`, `tests/test_analysis_gating.py`, `tests/test_health.py`.
  - Frontend: `docs/ROADMAP.md`, `docs/MODULE_LOG.md`, `docs/PROJECT_STATE.md`.
- **Checks Performed:**
  - `pytest backend/tests`: PASS (85/85 tests passed across 16 suites in 2.35s).
  - `ruff check src tests`: PASS (0 issues found).
  - `openapi-spec-validator backend/contracts/openapi.yaml`: PASS.
  - `python -m unittest discover database/tests`: PASS (11/11 tests passed).
  - GitHub Actions CI (run `38746019869` on `backend`, run `38742621904` on `database`): PASS.
  - Whitespace audit: PASS (`git diff --check` clean).
- **Physical Device & Verification Status:** Device test from Module 32 remains preserved as pending. No phone is required for backend provider integration.
- **Status:** Complete. Pushed to `backend` (`be2761b`) and `frontend`. Stopped before Module 34.
