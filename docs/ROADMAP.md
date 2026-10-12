# TrustCue Revised Roadmap (50 Modules)

This roadmap outlines the complete 50-module development plan for TrustCue, replacing the earlier 95-module breakdown. It consolidates closely related tasks while preserving rigorous privacy, deterministic rule, evidence-trail, testing, and Google Play preparation requirements.

## Overview & Branching Architecture

- **`frontend` Branch:** Client Flutter application, UI, local analysis, and on-device adapters.
- **`backend` Branch:** Server APIs, protected AI provider integration, and rate limiting.
- **`database` Branch:** Schema definitions, migrations, fixtures, and documentation.
- **`main` Branch:** Integrated, fully verified release line (gated by end-to-end and physical device verification).

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
| **22** | Warning taxonomy, rule engine, evidence locations, rule contracts | Planned | `frontend` |
| **23** | Urgency, credentials, verification-code, payment, and account-threat rules | Planned | `frontend` |
| **24** | Impersonation, job/reward/investment, URL heuristics, false-positive safeguards | Planned | `frontend` |
| **25** | Local assessment aggregation, uncertainty, evidence validation, safe-action catalog | Planned | `frontend` |
| **26** | Working local-analysis results and Evidence Trail interface | Planned | `frontend` |
| **27** | Backend/AI/hosting feasibility, privacy decisions, deployment and API contracts | Planned | `backend` |
| **28** | Backend foundation, configuration, health checks, contract tests | Planned | `backend` |
| **29** | Backend validation, limits, abuse controls, sensitive-log protection | Planned | `backend` |
| **30** | AI adapter, untrusted-input isolation, structured-response parsing | Planned | `backend` |
| **31** | AI evidence verification, failure handling, quotas, cautious assessment merging | Planned | `backend` |
| **32** | Mobile remote-analysis consent, API client, protected AI integration | Planned | `frontend` |
| **33** | Local database design, versioned schema, migrations, synthetic fixtures | Planned | `database` |
| **34** | Flutter persistence adapter, report saving, integrity and migration tests | Planned | `frontend` |
| **35** | History list, search/filter, details, deletion, retention controls | Planned | `frontend` |
| **36** | Settings, preference persistence, privacy controls, local-data management | Planned | `frontend` |
| **37** | Educational library, synthetic demo scenarios, usefulness feedback | Planned | `frontend` |
| **38** | Localization and multilingual explanations with explicit capability limits | Planned | `frontend` |
| **39** | Sanitized report sharing and export | Planned | `frontend` |
| **40** | Complete workflow coordination, progress, cancellation, retries, offline behavior | Planned | `frontend` |
| **41** | Security/privacy audit and adversarial input/output regression tests | Planned | `frontend` |
| **42** | Accessibility, screen-reader, responsive-layout, and keyboard audit | Planned | `frontend` |
| **43** | End-to-end mobile/backend/database integration and failure-path verification | Planned | `frontend` / `backend` |
| **44** | Real-device performance, lifecycle, low-memory, and network resilience | Planned | `frontend` |
| **45** | CI quality checks, reproducible tests, dependency/configuration validation | Planned | `frontend` |
| **46** | Production backend deployment, secret configuration, operational runbooks | Planned | `backend` |
| **47** | Final branding, icon/splash, user/developer documentation, demo/viva material | Planned | `frontend` |
| **48** | Android release signing, versioning, AAB, permissions and release privacy review | Planned | `frontend` |
| **49** | Play Console listing, disclosures, internal/required testing and release candidates | Planned | `frontend` |
| **50** | Final acceptance, production submission/rollout when eligible, project handover | Planned | `frontend` |

---

## Architectural Principles & Constraints

1. **Zero Financial Expenditure for Development:** Development uses free tiers, local tools, and open-source packages. Third-party developer account fees (e.g., Google Play Console) are handled out-of-band at the release stage.
2. **Honest Limitations & Uncertainty:** The app never promises 100% scam detection or guarantees safety. No artificial probabilities or percentages are fabricated.
3. **Explicit Data Boundaries:** Onboarding acknowledgement only confirms understanding of guidance. Remote AI processing requires explicit, per-request informed consent showing what will be sent.
4. **Evidence Trail:** Every finding links to verifiable excerpt(s) in the original message.
5. **No Secret Leakage:** Secrets belong solely on the backend; never bundle API keys or sensitive credentials in Flutter client code or Git history.
