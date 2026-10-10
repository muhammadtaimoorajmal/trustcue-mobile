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
- **NDK pinned to `30.0.16138531`**: The default requested NDK (`28.2.13676358`) failed to install via the background Android `sdkmanager`. We explicitly pinned to a completely installed local NDK candidate to fix the Android build block without requiring global system changes.
- **Gradle & JVM:** Gradle 9.3.1 running on Java 25 (with Java 17 JVM target compatibility).
- **Installed NDK metadata:** The pinned `30.0.16138531` installation identifies itself as `r30-beta3`; its compiler and Android debug build were verified. No toolchain migration is part of Module 12A.
- **Platform limits:** Android identity is `io.github.muhammadtaimoorajmal.trustcue`. The iOS scaffold still uses `com.trustcue.trustcueMobile`; iOS identity/build verification remains future work. Platform deep-link support has not been configured or verified.

## Implementation Status
- **Implemented:** Flutter foundation generated, repository layout created, VS Code debug config added, Android build successfully repaired, TrustCue application identity configured, Flutter code structure refactored, GetX (v4.7.3) state management/routing foundation implemented. Added physical-device integration test (Module 07). TrustCue visual direction and brand specification defined (Module 08). Light/dark themes, color system, and typography implemented (Module 09). Reusable UI components (`AppButton`, `AppTextField`, `AppCard`) and development component preview created (Module 10). Responsive layout constraints (`AppPageBody`), safe area handling, and keyboard behavior implemented (Module 11). Application navigation, route handling, informational `AboutScreen`, and `NotFoundScreen` fallback added (Module 12).
- **Checkpoints:** Modules 01-03 foundation committed (7578e65). Module 04 identity configuration committed (3db7ab5). Module 05 refactor committed (6e06bb3). Module 06 GetX foundation committed (e4bf1f2). Module 07 integration tests added (0fd789f). Module 08 design specification committed (815f029). Module 09 theme implementation committed (7ad3ecb). Module 10 reusable UI components committed (6c66557). Module 11 checkpoint `1dc5d3d` and original Module 12 checkpoint `f62d35a` are pushed. The handover exposed Module 12 routing/test deficiencies; Module 12A repairs these in a separate development checkpoint. Development checkpoints are pushed when automated checks pass, with manual verification tracked honestly without blocking pushes.
- **Planned:** The project will be developed over approximately 100 small modules, culminating in Google Play Store preparation.
- **Module 12A verification:** Exact-path production routing now rejects unknown paths, including descendants of registered routes and handles unsupported startup routes consistently. All 17 navigation tests and all 35 widget tests pass; formatting, analysis, and the normal debug APK build pass. The working recovery method retains an existing Home or binds a fresh one after removal, with stack/controller lifecycle regression coverage. The new device test and normal-app launch are blocked by an existing VS Code debug session that must be released before installation. See `MODULE_LOG.md` for the exact blocker and remaining human observations. Onboarding/Module 13 has not started.
- **Outstanding Blockers / Manual Actions:** Awaiting manual verification of normal background/resume lifecycle and component preview on the physical Android phone. Integration into `main` remains paused until this manual test is completed. Note: Ordinary background/resume should remain responsive and existing in-memory state should remain intact while the application process and controller remain alive. Android may terminate a background process, and state restoration after process recreation is not implemented or required by this module. iOS configuration remains untested on Windows.

## Academic Assessment
This project is part of CS3643, BSCS Semester 5-1, Fall 2026. The academic assessment stages are separate from the implementation modules:
- 20 quiz marks
- 15 assignment marks
- 45 midterm project marks
- 20 final project marks

