# TrustCue Project State

## Purpose & Workflow
TrustCue is a mobile application designed to explain potential scam indicators in suspicious digital communication. It supports privacy-conscious analysis, providing evidence-based explanations and safe verification steps.
**Core Workflow:** Screenshot/text input -> local extraction -> privacy review -> deterministic checks -> protected AI analysis -> evidence-linked explanations -> local history.

## Technology & Constraints
- **Stack:** Flutter and Dart, with implemented GetX state management, bindings, and navigation. GetX is pinned exactly to `4.7.3` in both manifest and lockfile.
- **Budget:** Zero-budget development. Note: Eventual Play Console registration has a separate cost outside of development.
- **Privacy & AI:** Requires privacy-conscious handling, protected AI credentials, cautious findings, and honest limitations. The app must communicate uncertainty and not invent scam-probability percentages.

## Repository Layout & Branch Workflow
- `frontend/`: The complete Flutter application, including client-side services.
- `backend/`: Future server APIs and protected AI integration.
- `database/`: Database definitions, migrations, fixtures, and DB documentation.
- `docs/`: Shared project documentation.
- `.vscode/`: Narrowly selected portable workspace configuration.
- **Branch Workflow:** Development happens in isolated branches (`frontend`, `backend`, `database`) that map to module responsibilities. Commits are eventually integrated into `main` after verification.

## Verified Environment Decisions
- **NDK pinned to `30.0.16138531` & subproject override**: The default requested NDK (`28.2.13676358`) failed to install via the background Android `sdkmanager`. In Module 17, `frontend/android/build.gradle.kts` applies `setNdkVersion("30.0.16138531")` to all plugin subprojects (such as `:jni`) after evaluation, ensuring consistent NDK targeting across transitive native dependencies.
- **Gradle & JVM:** Gradle 9.3.1 running on Java 25 (with Java 17 JVM target compatibility).
- **Installed NDK metadata:** The pinned `30.0.16138531` installation identifies itself as `r30-beta3`; its compiler and Android debug build were verified. No toolchain migration is part of Module 12A.
- **Kotlin cross-drive incremental compilation:** `frontend/android/gradle.properties` sets `kotlin.incremental=false` to resolve a known Kotlin bug (`IllegalArgumentException: this and base files have different roots`) when building subprojects with dependencies across drive `C:` (pub cache) and `D:` (workspace).
- **Platform limits:** Android identity is `io.github.muhammadtaimoorajmal.trustcue`. The iOS scaffold still uses `com.trustcue.trustcueMobile`; iOS identity/build verification remains future work. Platform deep-link support has not been configured or verified.

## Implementation Status
- **Implemented:** Flutter foundation generated, repository layout created, VS Code debug config added, Android build successfully repaired, TrustCue application identity configured, Flutter code structure refactored, GetX (v4.7.3) state management/routing foundation implemented. Added physical-device integration test (Module 07). TrustCue visual direction and brand specification defined (Module 08). Light/dark themes, color system, and typography implemented (Module 09). Reusable UI components (`AppButton`, `AppTextField`, `AppCard`) and development component preview created (Module 10). Responsive layout constraints (`AppPageBody`), safe area handling, and keyboard behavior implemented (Module 11). Application navigation, route handling, informational `AboutScreen`, and `NotFoundScreen` fallback added (Module 12/12A). First-run onboarding (`/onboarding`), startup route (`/startup`), non-sensitive preference persistence (`OnboardingPreferences`, `shared_preferences: 2.5.6`), guidance review from About (`/safe-use`), and Android incremental cache build repair implemented (Module 13/13A). Home dashboard and input-method preparation navigation (`/input/text`, `/input/screenshot`, `/input/link`), retirement of temporary counter demonstration, debounced navigation, and safety guidance card implemented (Module 14). Platform-independent typed data models (`TextSnapshot`, `EvidenceReference`, `AnalysisFinding`, `AnalysisReport`), `AnalysisService` contract, `Result<T>` monad, and version-1 JSON serialization codecs implemented (Module 15). Message text entry, pure-Dart validation policy (`MessageTextValidator`), dual limit enforcement (10,000 code points, 40,000 UTF-8 bytes), line-break normalization (`\r\n`/`\r` to `\n`), route-owned controller (`InputTextController`), in-memory snapshot creation, discard confirmation dialogs, and Home dashboard active card update implemented (Module 16). Screenshot selection, pure-Dart `ImageValidator` and `ImageValidationPolicy` (PNG/JPEG magic bytes, <= 20MP, <= 10MB), interactive pan/zoom preview, app-owned temporary storage lifecycle (`ScreenshotStorageService`), Android lost-data recovery coordinator (`ScreenshotRecoveryCoordinator`), discard/removal dialogs, and Home dashboard active card update implemented (Module 17).
- **Checkpoints:** Modules 01-03 foundation committed (7578e65). Module 04 identity configuration committed (3db7ab5). Module 05 refactor committed (6e06bb3). Module 06 GetX foundation committed (e4bf1f2). Module 07 integration tests added (0fd789f). Module 08 design specification committed (815f029). Module 09 theme implementation committed (7ad3ecb). Module 10 reusable UI components committed (6c66557). Module 11 checkpoint `1dc5d3d` committed. Module 12 checkpoint `f62d35a` and Module 12A repair checkpoint `b133586` committed. Module 13 committed (`68aa084`). Module 13A reconciliation verified and documented (`9270341`). Module 14 dashboard and input navigation committed (`ed9e699`). Module 15 typed data contracts committed (`2fae68a`). Module 16 message text entry committed (`2c4149c`). Module 17 screenshot selection and preview pending commit. `main`, `backend`, and `database` branches remain at initial commit `a785db8` awaiting integration.
- **Planned:** The project follows an authoritative 50-module roadmap (defined in `docs/ROADMAP.md`), culminating in Google Play Store preparation.
- **Module 17 verification:** Pure-Dart `ImageValidator` magic bytes (PNG/JPEG), dimension limits (min 32px, max 20MP), and size limits (10MB) verified. `ScreenshotStorageService` copy creation, unique naming, and isolated deletion verified without touching user originals. `InputScreenshotController` selection, validation, replacement, removal, discard confirmation, and route cleanup verified. `InputScreenshotScreen` preview rendering, pan/zoom, error states, and safe-use review navigation verified. All 175 automated tests pass cleanly across 15 suites (adding 30 new tests across validator, storage, controller, and screen suites). Formatting (75 files) and static analysis report 0 issues. Normal debug APK builds cleanly in ~114s. On-device integration smoke test (`tool/test.ps1 -Suite device`) executed on Vivo V2207 (`10AC9R1ABF0013A`, Android 14 / API 34) and passed cleanly in 17s; updated APK successfully installed and launched.
- **Outstanding Blockers / Manual Actions:** Awaiting manual visual verification of screenshot selection from gallery, interactive pan/zoom preview, image metadata chip, image replacement, removal confirmation dialog, discard dialog on back navigation, safe-use guidance review preservation, and ordinary background/resume lifecycle on the physical Android phone. Integration into `main` remains paused until this manual test gate is cleared. iOS configuration remains untested on Windows.

## Academic Assessment
This project is part of CS3643, BSCS Semester 5-1, Fall 2026. The academic assessment stages are separate from the implementation modules:
- 20 quiz marks
- 15 assignment marks
- 45 midterm project marks
- 20 final project marks

