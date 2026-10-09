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
- **Implemented:** Flutter foundation generated, repository layout created, VS Code debug config added, Android build successfully repaired, TrustCue application identity configured (`io.github.muhammadtaimoorajmal.trustcue`), and Flutter code structure refactored (separated app entry, theme, and home screen).
- **Checkpoints:** Modules 01-03 foundation committed (7578e65). Module 04 identity configuration committed (3db7ab5). Module 05 refactor committed. Development checkpoints are pushed when automated checks pass, with manual verification tracked honestly without blocking pushes.
- **Planned:** The project will be developed over approximately 100 small modules, culminating in Google Play Store preparation.
- **Outstanding Blockers / Manual Actions:** Awaiting manual visual verification of the newly configured TrustCue app launching on the physical Android phone. iOS configuration remains untested on Windows.

## Academic Assessment
This project is part of CS3643, BSCS Semester 5-1, Fall 2026. The academic assessment stages are separate from the implementation modules:
- 20 quiz marks
- 15 assignment marks
- 45 midterm project marks
- 20 final project marks

