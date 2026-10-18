# TrustCue Revised Roadmap (50 Modules)

This roadmap outlines the complete 50-module development plan for TrustCue, replacing the earlier 95-module breakdown. It consolidates closely related tasks while preserving rigorous privacy, deterministic rule, evidence-trail, testing, and Google Play preparation requirements.

## Overview & Branching Architecture

- **`frontend` Branch:** Client Flutter application, UI, local analysis, on-device adapters, and shared project documentation.
- **`backend` Branch:** Server APIs, protected AI provider integration, rate limiting, and backend-specific documentation/contracts.
- **`database` Branch:** Schema definitions, PostgreSQL migrations, fixtures, RLS policies, and database documentation.
- **`main` Branch:** Integrated, fully verified release line (gated by end-to-end and physical device verification).

---

## Documentation Ownership Policy

To prevent divergent or conflicting project roadmaps across branches:
1. **Shared Project Documentation:** The authoritative 50-module roadmap (`docs/ROADMAP.md`), project-wide state (`docs/PROJECT_STATE.md`), and consolidated module log (`docs/MODULE_LOG.md`) are maintained and versioned on the **`frontend`** branch.
2. **Backend Documentation:** Backend-specific architecture, OpenAPI specifications, database entity design, and cloud setup guides reside on the **`backend`** branch under `backend/docs/` and `backend/contracts/`.
3. **Database Documentation:** Executable PostgreSQL migrations, schema DDL, and database fixtures reside on the **`database`** branch under `database/`.

---

## The 50-Module Schedule

| Module | Scope | Status | Branch |
|---|---|---|---|
| **01** | Workspace validation and Flutter scaffold | Completed (`7578e65`) | `frontend` |
| **02** | Android build repair (pinned NDK) and VS Code launch setup | Completed (`7578e65`) | `frontend` |
| **03** | Durable project context, Git hygiene, working rules | Completed (`7578e65`) | `frontend` |
| **04** | Application identity and metadata | Completed (`3db7ab5`) | `frontend` |
| **05** | Entry point, app, theme, and feature structure | Completed (`6e06bb3`) | `frontend` |
| **06** | GetX state, bindings, and routing foundation | Completed (`e4bf1f2`) | `frontend` |
| **07** | Device smoke-test foundation | Completed (`0fd789f`) | `frontend` |
| **08** | Visual direction and brand specification | Completed (`815f029`) | `frontend` |
| **09** | Light/dark themes and typography | Completed (`7ad3ecb`) | `frontend` |
| **10** | Reusable components (`AppButton`, `AppTextField`, `AppCard`) and component preview | Completed (`6c66557`) | `frontend` |
| **11** | Responsive layout (`AppPageBody`), safe areas, spacing, keyboard behavior | Completed (`1dc5d3d`) | `frontend` |
| **12** | Application navigation, About, fallback screen, and route recovery (includes Module 12A repair) | Completed (`b133586`) | `frontend` |
| **13** | First-run onboarding, safe-use guidance, build repair, preference persistence, and verification (includes Module 13A reconciliation) | Completed (`68aa084`) | `frontend` |
| **14** | Home dashboard and input-method navigation | Completed (`ed9e699`) | `frontend` |
| **15** | Typed input/finding/report contracts, serialization, errors, service interfaces | Completed (`2fae68a`) | `frontend` |
| **16** | Pasted-text input, normalization, validation, and limits | Completed (`2c4149c`) | `frontend` |
| **17** | Screenshot selection, preview, temporary-file lifecycle | Completed (`1ac80c4`) | `frontend` |
| **18** | On-device OCR integration, supported scripts, failures, retries | Completed (`f73b920`) | `frontend` |
| **19** | Extracted-text correction, sensitive-data detection, redaction review | Completed (`490ff66`) | `frontend` |
| **20** | URL parsing, QR decoding, destination review, safe-opening boundaries (includes Module 20A contract & build reconciliation) | Completed | `frontend` |
| **21** | Android incoming-share input and lifecycle handling | Completed | `frontend` |
| **22** | Warning taxonomy, rule engine, evidence locations, rule contracts | Completed | `frontend` |
| **23** | Urgency, credentials, verification-code, payment, and account-threat rules | Completed | `frontend` |
| **24** | Impersonation, job/reward/investment, URL heuristics, false-positive safeguards | Completed | `frontend` |
| **25** | Local assessment aggregation, uncertainty, evidence validation, safe-action catalog | Completed | `frontend` |
| **26** | Working local-analysis results and Evidence Trail interface | Completed (`027a0cc`) | `frontend` |
| **27** | Architecture, feasibility, privacy and API contracts | Completed (`60745dc`) | `backend` |
| **28** | Backend foundation and configuration | Completed (`766e61a`) | `backend` |
| **29** | Database schema, migrations and ownership policies | Completed (`02db979`) | `database` |
| **30** | Authentication integration and session-validation contracts | Completed (`fa11d88`) | `backend` |
| **31** | Flutter signup/login/verification/recovery/logout flows | Completed | `frontend` |
| **32** | Backend validation, authorization and abuse controls | Completed (`0714bcd`) | `backend` |
| **33** | Protected AI-provider integration | Completed (`be2761b`) | `backend` |
| **34** | AI output/evidence validation and adversarial tests | Completed (`1f093f8`) | `backend` |
| **35** | Mobile upload consent and optional AI workflow | Completed | `frontend` |
| **36** | Local report persistence and migrations | Completed | `frontend` |
| **37** | History, search, report details and deletion | Completed | `frontend` |
| **38** | Account/profile settings and account deletion | Completed | `frontend` / `backend` |
| **39** | Optional account-owned backup/sync and isolation | Completed (`56056b2`) | `frontend` / `backend` / `database` |
| **40** | Privacy, retention and consent controls | Completed | `frontend` |
| **41** | Education, synthetic examples, feedback and localization | Completed | `frontend` |
| **42** | User-controlled privacy-reviewed export/sharing | Completed | `frontend` |
| **43** | Complete workflow integration and offline/retry/lifecycle handling | Completed | `frontend` |
| **44** | Security and privacy testing | Completed | `frontend` / `backend` / `database` |
| **45** | Accessibility and usability verification | Completed | `frontend` |
| **46** | End-to-end, real-device, performance and storage verification | Planned | `frontend` / `backend` |
| **47** | CI, deployment, migrations and recovery procedures | Planned | `frontend` / `backend` |
| **48** | Android release configuration, branding, signing and AAB | Planned | `frontend` |
| **49** | Play Console listing, disclosures, internal/required testing and release candidates | Planned | `frontend` |
| **50** | Final audit, approved main integration, release and maintenance handover | Planned | `frontend` / `backend` / `database` / `main` |

---

## Detailed Specification for Modules 27–50

### Module 27: Architecture, Feasibility, Privacy, and API Contracts
- **Primary Branch:** `backend`
- **Deliverable:** Technology feasibility matrix, dual AI privacy strategy, OpenAPI 3.1.0 contract (`openapi.yaml`), conceptual database entity model, and cloud setup guide (`SETUP_GUIDE.md`).
- **Dependencies:** Modules 15, 22, 25, 26 (local analysis and evidence contracts).
- **Acceptance Criteria:** Validated OpenAPI 3.1.0 specification with 100% resolved internal `$ref` pointers; zero required upfront payment cards; Groq zero-retention strategy documented; synthetic data policy for unpaid Gemini API; explicit documentation ownership policy established.
- **Necessary Human Actions:** None yet.

### Module 28: Backend Foundation, Configuration, Health/Readiness, and CI Validation
- **Primary Branch:** `backend`
- **Deliverables:** Python 3.13+ FastAPI application scaffold, typed Pydantic Settings, loopback execution default (`127.0.0.1:8000`), `/health` and `/ready` probe routes matching design contract, privacy-safe structured logging, sanitized error envelopes (masking raw user input and internal exceptions), GitHub Actions backend CI workflow, and automated test suite.
- **Dependencies:** Module 27.
- **Acceptance Criteria:** Server starts cleanly on loopback; `/health` and `/ready` return 200 with valid schemas; `/ready` reports degraded 503 during draining; validation errors strip raw submitted values; logs never capture query strings, bodies, or content hashes; 24 automated tests pass; zero cloud credentials required.
- **Necessary Human Actions:** None.

### Module 29: Database Schema, Migrations, and Ownership Policies
- **Primary Branch:** `database`
- **Deliverables:** Versioned PostgreSQL DDL migrations (`00001`–`00005`), Row Level Security (RLS) policies, synthetic seeds, test auth compatibility fixtures, 4 transactional SQL regression suites, standalone Python static schema validation suite, PostgreSQL 16 GitHub Actions CI workflow, entity relationship architecture (`docs/ARCHITECTURE.md`), and setup guide (`docs/SETUP_AND_MIGRATION_GUIDE.md`).
- **Dependencies:** Modules 27, 28.
- **Acceptance Criteria:** Migrations apply idempotently; RLS enabled and forced across all public tables; authenticated clients denied write access to `ai_usage_quotas`; synced report payload bounded to 500 KB; tombstone consistency enforced; `ON DELETE CASCADE` eliminates all child records on `auth.users` deletion leaving 0 orphan rows; 10 offline static tests passing; PostgreSQL 16 CI workflow configured with `postgres:16-alpine` service container.
- **Necessary Human Actions:** None for local development or CI. Optional manual step: create free cloud project at supabase.com and apply migration scripts via Supabase SQL Editor when deploying to hosted environment.

### Module 30: Authentication Integration and Session-Validation Contracts
- **Primary Branch:** `backend`
- **Deliverable:** JWT verification middleware (validating Supabase issuer, audience, signature, expiration), user context injection, token rejection tests, and account profile endpoints.
- **Dependencies:** Modules 28, 29.
- **Acceptance Criteria:** Valid JWTs allow access to protected endpoints; expired/tampered JWTs return HTTP 401; user ID correctly extracted and bounded.
- **Necessary Human Actions:** None.

### Module 31: Flutter Signup/Login/Verification/Recovery/Logout Flows
- **Primary Branch:** `frontend`
- **Deliverables:** Complete Flutter authentication and session management architecture (`/account`, `/auth/login`, `/auth/register`, `/auth/verify-email`, `/auth/forgot-password`, `/auth/reset-password`), typed domain models (`AuthUser`, `AuthState`, `AuthFailure`), dedicated monadic `AuthResult<T>` decoupling auth outcomes from analysis failures, secure hardware token storage (`flutter_secure_storage: 11.2.0` with Android KeyStore AES-GCM + RSA key wrapping and iOS Keychain), PKCE client integration (`supabase_flutter: 2.18.3`), deep-link callback configuration (`trustcue://auth-callback`), rate-limit cooldown timers, enumeration-resistant password reset, responsive accessible UI adapting cleanly to 320px width and 200% font scale, and Home dashboard AppBar account access button.
- **Dependencies:** Modules 13, 14, 30.
- **Acceptance Criteria:** Offline guest mode completely unimpeded; user can initiate registration, email verification cooldowns, sign in, request password resets with anti-enumeration protection, set new password, inspect session details on account screen, and confirm sign-out; 43 auth/home tests and 637 full project tests pass; `flutter analyze --no-pub` reports 0 issues; debug APK builds cleanly.
- **Necessary Human Actions:** Real-device email inbox verification and deep-link redirect verification (pending when physical device testing resumes).

### Module 32: Backend Validation, Authorization, and Abuse Controls
- **Primary Branch:** `backend`
- **Deliverable:** Strict payload validation (max 10,000 runes, 40,000 UTF-8 bytes, surrogate pair validation), per-user daily quota tracking (`ai_usage_quotas`), fail-closed rate limiters, sanitized error envelopes.
- **Dependencies:** Modules 28, 29, 30.
- **Acceptance Criteria:** Malformed Unicode and oversized payloads rejected with HTTP 400; quota exceedance returns HTTP 429 with `Retry-After`; internal exceptions never leak in error messages.
- **Necessary Human Actions:** None.

### Module 33: Protected AI-Provider Integration
- **Primary Branch:** `backend`
- **Deliverable:** Server-side AI client adapters for Groq Cloud API and Google Gemini API, XML untrusted data framing, system prompt isolation, structured JSON response parsing.
- **Dependencies:** Modules 27, 28, 32.
- **Acceptance Criteria:** Privileged AI keys stay exclusively on backend; prompt injection attempts treated strictly as data; valid AI findings generated for synthetic scenarios.
- **Necessary Human Actions:** Obtain free Groq API key (and/or Google AI Studio key) and enter into backend `.env`.

### Module 34: AI Output/Evidence Validation and Adversarial Tests
- **Primary Branch:** `backend`
- **Deliverable:** Server-side evidence grounding engine verifying exact UTF-16 code-unit offsets, substring excerpt validation, hallucination filter, adversarial prompt injection regression tests.
- **Dependencies:** Modules 22, 33.
- **Acceptance Criteria:** Ungrounded or hallucinated findings discarded; valid excerpts match text byte-for-byte; prompt injection cannot force false "safe" verdicts.
- **Necessary Human Actions:** None.

### Module 35: Mobile Upload Consent and Optional AI Workflow
- **Primary Branch:** `frontend`
- **Deliverable:** Pre-upload consent modal showing exact text, redaction status, and destination; API client service calling `/api/v1/analysis/ai`; results screen integration displaying AI findings with distinct provenance badges.
- **Dependencies:** Modules 26, 31, 33, 34.
- **Acceptance Criteria:** Upload requires explicit user confirmation; editing text invalidates prior consent; AI findings distinctly labeled from local rule findings; offline/error states preserve local analysis.
- **Necessary Human Actions:** None.

### Module 36: Local Report Persistence and Migrations
- **Primary Branch:** `frontend`
- **Deliverable:** Pure-local SQLite database adapter (using `sqflite` or `drift`), schema migrations, atomic report saving, local report indexing, data integrity tests.
- **Dependencies:** Modules 15, 25, 26.
- **Acceptance Criteria:** Reports saved locally on device; database operates fully offline; no network transmissions required for storage.
- **Necessary Human Actions:** None.

### Module 37: History, Search, Report Details, and Deletion
- **Primary Branch:** `frontend`
- **Deliverable:** History list screen (`/history`), date/category filtering, full-text search across saved reports, report detail view, single and bulk deletion with database cleanup.
- **Dependencies:** Module 36.
- **Acceptance Criteria:** User can view, search, inspect, and delete locally saved reports; deletion immediately removes data from device storage.
- **Necessary Human Actions:** None.

### Module 38: Account/Profile Settings and Account Deletion
- **Primary Branch:** `frontend` / `backend`
- **Deliverable:** Settings screen (`/settings`), user profile display, password change, account deletion workflow invoking `DELETE /api/v1/account`, complete database cascade purge.
- **Dependencies:** Modules 29, 30, 31.
- **Acceptance Criteria:** Account deletion purges server profile, quotas, and auth identity; local device session cleared; zero residual data on server.
- **Necessary Human Actions:** Confirm deletion on test account.

### Module 39: Optional Account-Owned Backup/Sync and Isolation
- **Primary Branch:** `frontend` / `backend` / `database`
- **Deliverable:** Cloud backup opt-in toggle in settings, encrypted payload upload/download (`/api/v1/sync/reports`), synchronization conflict resolution, tombstone handling.
- **Dependencies:** Modules 29, 36, 38.
- **Acceptance Criteria:** Sync is disabled by default; enabling sync uploads client-encrypted reports; disabling sync halts synchronization; deletion removes cloud copies.
- **Necessary Human Actions:** None.

### Module 40: Privacy, Retention, and Consent Controls
- **Primary Branch:** `frontend`
- **Deliverable:** Granular data retention controls (auto-delete reports after 30/60/90 days), audit log viewer of user-granted consents, local cache purger.
- **Dependencies:** Modules 36, 37, 39.
- **Acceptance Criteria:** Scheduled local pruning functions correctly; user can clear all local and temporary caches in 1 tap.
- **Necessary Human Actions:** None.

### Module 41: Education, Synthetic Examples, Feedback, and Localization
- **Primary Branch:** `frontend`
- **Deliverable:** Interactive educational library (`/education`), synthetic scam walkthroughs with interactive evidence exploration, anonymous usefulness feedback, localization strings foundation.
- **Dependencies:** Modules 22, 25, 26.
- **Acceptance Criteria:** Educational scenarios demonstrate indicators clearly; feedback is local/anonymous; UI responsive across screen sizes.
- **Necessary Human Actions:** None.

### Module 42: User-Controlled Privacy-Reviewed Export and Sharing
- **Primary Branch:** `frontend`
- **Deliverables:** Sanitized report export architecture (`/export`, `ExportReportData`, `ExportOptions`, `ExportFormat`), pure-local generation in UTF-8 Plain Text (`.txt`) and paginated PDF (`.pdf`) using `pdf: 3.13.1` with safe Unicode/Urdu escaping and prominent typography disclosures, dedicated `ExportDataExtractor` supporting in-memory assessments, saved reports, and cloud summaries, strict privacy-by-default bounds (reviewed text, evidence quotations, and AI reasoning strictly opt-in and off by default; zero raw OCR drafts, screenshots, account emails, tokens, or local DB paths), bounded temporary export storage in `<cacheDir>/exports/` with 2-hour automated pruning (`DefaultExportStorageService`), native Android ShareSheet integration via `share_plus: 13.3.1` (`DefaultShareLauncher`), reactive bottom sheet modal (`ExportReportSheet`) with live preview, copy-to-clipboard convenience, and integrations into `AnalysisResultsScreen` and `SavedReportDetailScreen`.
- **Dependencies:** Modules 19, 26, 36.
- **Acceptance Criteria:** Exported files never expose unredacted sensitive details or unselected sections; generation works 100% locally and offline without authentication or cloud AI; 837 automated tests passing with 0 regressions; `flutter analyze --no-pub` clean (0 issues); debug APK built successfully.
- **Necessary Human Actions:** Physical device smoke test walkthrough on phone (pending USB reconnect).

### Module 43: Complete Workflow Coordination, Progress, and Lifecycle
- **Primary Branch:** `frontend`
- **Deliverable:** Central workflow coordinator managing end-to-end flows (intake -> review -> local analysis -> optional AI -> history saving), app lifecycle backgrounding/resumption tests.
- **Dependencies:** Modules 14, 19, 26, 35, 36.
- **Acceptance Criteria:** App transitions seamlessly across background/foreground; network drops handled gracefully with retries; draft state preserved during incoming phone calls.
- **Necessary Human Actions:** None.

### Module 44: Security and Privacy Testing
- **Primary Branch:** `frontend` / `backend`
- **Deliverable:** Comprehensive security audit suite, penetration testing of backend endpoints, adversarial prompt injection regression tests, token forgery tests, memory dump inspection for key leakage.
- **Dependencies:** Modules 32, 33, 34, 38.
- **Acceptance Criteria:** 0 critical or high vulnerabilities; prompt injections neutralized; no sensitive tokens or passwords discovered in memory dumps.
- **Necessary Human Actions:** Review security report.

### Module 45: Accessibility and Usability Verification
- **Primary Branch:** `frontend`
- **Deliverables:** TalkBack / VoiceOver screen-reader audit and semantic hierarchy optimizations, WCAG 2.1 AA mathematical color contrast validation across light and dark themes, 48x48 dp minimum touch target enforcement on all interactive icon buttons (`HistoryFilterBar`, `HistoryReportCard`, `ExportReportSheet`, `AnalysisResultsScreen`), 200% font scaling resilience without overflow (`DeleteConfirmationDialog`, `ExportReportSheet`, `AnalysisResultsScreen`, `SavedReportDetailScreen`, `AccountScreen`), bidirectional token isolation wrapping exact evidence excerpts in `Directionality(textDirection: TextDirection.ltr)`, dedicated accessibility automated regression test suite (`accessibility_review_test.dart`), and comprehensive audit report (`docs/ACCESSIBILITY_REVIEW_MODULE_45.md`).
- **Dependencies:** Modules 09, 10, 11, 26, 31, 37.
- **Acceptance Criteria:** WCAG 2.1 AA contrast verified for light and dark themes; 0 semantic clipping or overflow at 200% text scale; 859 automated tests passing with 0 regressions; `flutter analyze --no-pub` clean (0 issues); debug APK built successfully.
- **Necessary Human Actions:** Manual TalkBack gesture and spoken output walkthrough on physical Android phone.

### Module 46: End-to-End, Real-Device, Performance, and Storage Verification
- **Primary Branch:** `frontend` / `backend`
- **Deliverable:** End-to-end integration tests on physical phone (Vivo V2207), low-memory stress tests, database growth benchmarks, cold start and network latency measurements.
- **Dependencies:** Modules 43, 44, 45.
- **Acceptance Criteria:** App launches under 2.0s on physical device; database remains fast with 1,000+ reports; 0 unhandled native crashes.
- **Necessary Human Actions:** Connect physical phone for full automated verification suite.

### Module 47: CI, Deployment, Migrations, and Recovery Procedures
- **Primary Branch:** `frontend` / `backend`
- **Deliverable:** GitHub Actions CI pipelines (linting, tests, build checks), Render production backend deployment configuration, zero-downtime database migration runbook, disaster recovery guide.
- **Dependencies:** Modules 28, 29, 44.
- **Acceptance Criteria:** CI passes on all branches; backend deploys to Render with automated health checks; disaster recovery runbook verified against staging.
- **Necessary Human Actions:** Configure GitHub repository secrets for CI/CD and Render deployment.

### Module 48: Android Release Configuration, Branding, Signing, and AAB
- **Primary Branch:** `frontend`
- **Deliverable:** Production Android app bundle (`app-release.aab`), release keystore generation and signing configuration, ProGuard/R8 obfuscation rules, release privacy policy URL, final app icons and adaptive splash screens.
- **Dependencies:** Modules 04, 08, 46.
- **Acceptance Criteria:** Signed AAB builds successfully; app size optimized; R8 rules verified without breaking ML Kit or Supabase reflection.
- **Necessary Human Actions:** Securely generate and back up release keystore file.

### Module 49: Play Console Listing, Disclosures, and Testing Tracks
- **Primary Branch:** `frontend`
- **Deliverable:** Google Play Console store listing copy, screenshots across phone and tablet sizes, Data Safety form disclosures, privacy policy documentation, internal testing track deployment.
- **Dependencies:** Modules 47, 48.
- **Acceptance Criteria:** Data safety declarations align strictly with zero-upload and explicit consent policies; internal testing release published.
- **Necessary Human Actions:** Upload AAB and submit store disclosures in personal Google Play Console account.

### Module 50: Final Audit, Approved Main Integration, Release, and Handover
- **Primary Branch:** `frontend` / `backend` / `database` / `main`
- **Deliverable:** Comprehensive final academic audit report, viva demonstration materials, full codebase merge into `main`, tagged release `v1.0.0`, maintenance handover runbook.
- **Dependencies:** Modules 1–49.
- **Acceptance Criteria:** All 50 modules verified; `main` branch tests pass cleanly; academic requirements for CS3643 fulfilled 100%.
- **Necessary Human Actions:** Final academic project submission and presentation.

---

## Architectural Principles & Constraints

1. **Zero Financial Expenditure for Development:** Development uses free tiers, local tools, and open-source packages. Third-party developer account fees (e.g., Google Play Console) are handled out-of-band at the release stage.
2. **Honest Limitations & Uncertainty:** The app never promises 100% scam detection or guarantees safety. No artificial probabilities or percentages are fabricated.
3. **Explicit Data Boundaries:** Onboarding acknowledgement only confirms understanding of guidance. Remote AI processing requires explicit, per-request informed consent showing what will be sent.
4. **Evidence Trail:** Every finding links to verifiable excerpt(s) in the original message.
5. **No Secret Leakage:** Secrets belong solely on the backend; never bundle API keys or sensitive credentials in Flutter client code or Git history.
