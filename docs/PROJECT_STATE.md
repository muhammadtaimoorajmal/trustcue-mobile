# TrustCue Project State

## Purpose & Workflow
TrustCue is a mobile application designed to explain potential scam indicators in suspicious digital communication. It supports privacy-conscious analysis, providing evidence-based explanations and safe verification steps.
**Core Workflow:** Screenshot/text input -> local extraction -> privacy review -> deterministic checks -> protected AI analysis -> evidence-linked explanations -> local history.

## Technology & Constraints
- **Stack:** Flutter and Dart (with eventual GetX integration).
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

## Implementation Status
- **Implemented:** Flutter foundation generated, repository layout created, VS Code debug config added, Android build successfully repaired, TrustCue application identity configured (`io.github.muhammadtaimoorajmal.trustcue`), Flutter code structure refactored, GetX (v4.7.3) state management/routing foundation implemented. Added physical-device integration test (Module 07). TrustCue visual direction and brand specification defined (Module 08). Light/dark themes, color system, and typography implemented (Module 09).
- **Checkpoints:** Modules 01-03 foundation committed (7578e65). Module 04 identity configuration committed (3db7ab5). Module 05 refactor committed (6e06bb3). Module 06 GetX foundation committed (e4bf1f2). Module 07 integration tests added (0fd789f). Module 08 design specification committed (815f029). Module 09 theme implementation pending push. Development checkpoints are pushed when automated checks pass, with manual verification tracked honestly without blocking pushes.
- **Planned:** The project will be developed over approximately 100 small modules, culminating in Google Play Store preparation.
- **Outstanding Blockers / Manual Actions:** Awaiting manual verification of background/resume lifecycle on the physical Android phone. Integration into `main` remains paused until this manual test is completed. iOS configuration remains untested on Windows.

## Academic Assessment
This project is part of CS3643, BSCS Semester 5-1, Fall 2026. The academic assessment stages are separate from the implementation modules:
- 20 quiz marks
- 15 assignment marks
- 45 midterm project marks
- 20 final project marks

