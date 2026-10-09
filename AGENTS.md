# TrustCue Agent Rules

These rules must be strictly followed by any AI agent working on the TrustCue repository:

1. **Repository Root:** The root of the repository is `trustcue-mobile`. Do not initialize or scaffold outside of this directory.
2. **Component Locations:**
   - `frontend/`: The Flutter application, client services, and local-storage adapters.
   - `backend/`: Server APIs and protected AI-provider integration.
   - `database/`: Database definitions, migrations, synthetic fixtures, and DB docs. Database-related Dart code may also live inside the Flutter package.
3. **Branch Responsibilities:** Do not create divergent branches unless specified. Work within the assigned module's existing branch (e.g., `frontend`, `backend`, `database`).
4. **Module Scope:** Only implement what is requested in the current module. Do not skip ahead or implement future features prematurely.
5. **Zero-Budget Requirement:** Development must require zero financial expenditure. Do not provision paid services or assume an AI/backend provider without approval.
6. **Privacy Rules:** The application must communicate uncertainty when analyzing data. Do not guarantee that a message is safe or fraudulent, do not invent scam-probability percentages, and do not present simulated results as real analysis.
7. **Verification Reports:** Ensure all execution reports are truthful. A blocked required check must remain explicitly PARTIAL or BLOCKED. Never replace missing evidence with a claim of success.


8. **Continuity & Context:** Read `AGENTS.md`, `docs/PROJECT_STATE.md`, `docs/MODULE_LOG.md`, and actual Git status before editing. Reconcile written notes with the real repository.
9. **Execution Precision:** Preserve the established folder layout and working functionality. Implement only the requested module. Add dependencies only when required for that module. Keep client services inside the Flutter package where appropriate.
10. **Manual Actions:** Explain necessary manual actions using a clear format: Action needed, Where, Steps, Expected result, Confirmation needed, and If it fails (diagnostics).
11. **Verification & Checkpoints:** Report checks as passed, failed, blocked, or not run. Update project notes before the module’s checkpoint. Commit and push completed, verified module work to its designated branch. Verify the remote commit and include evidence in the completion report. Keep incomplete work explicitly marked as incomplete.
12. **Safety Guidelines:** Never force-push, reset history, delete unrelated work, or expose secrets.
