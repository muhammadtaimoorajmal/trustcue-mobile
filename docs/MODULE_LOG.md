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
- **Scope:** Implement real on-device Latin text extraction on `/input/screenshot` using `google_mlkit_text_recognition: 0.17.1`. The bridge is community-maintained by `flutter-ml.dev` and wraps Google's on-device ML Kit C++/Java libraries without API keys, accounts, or network dependencies. Extract text only upon deliberate user request via "Extract text from image" button. Display clear script limitation notice (Latin alphabet only) and accuracy warning. Provide read-only, selectable text presentation with prominent "Unreviewed text — accuracy not verified" banner. Robust error handling mapping failures into user-friendly messages: empty image text, limits exceeded (10,000 code points / 40,000 UTF-8 bytes), platform unsupported, timeout, and user cancellation. Provide recovery actions: "Retry extraction" and "Enter message text manually". Truthful retry state prevents overlapping native operations (`isNativeSettling`). Coordinate file reader lifecycle (`_activeReadingFiles`) so active native readers prevent premature file deletion. Update Home dashboard Screenshot card status from "Preview available" to "Text extraction available". Reconcile iOS deployment target in Xcode project to 15.5+ (`IPHONEOS_DEPLOYMENT_TARGET = 15.5`).
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
