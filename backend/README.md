# TrustCue Backend Service

This directory contains the backend architecture, API contracts, database design, and server implementation for the TrustCue scam-awareness application.

## 1. Overview & Stack

- **Runtime & Language:** Node.js 20+ LTS with TypeScript
- **Web Framework:** Fastify (lightweight, schema-driven, low memory)
- **Managed Authentication & Database:** Supabase (Auth + PostgreSQL with Row Level Security)
- **AI Inference Engine:**
  - **Primary:** Groq Cloud API (`llama-3.3-70b-versatile` / `llama-3.1-8b-instant`) — zero data retention, no customer training
  - **Secondary:** Google Gemini API (`gemini-1.5-flash`) — synthetic data policy on unpaid tier
- **Hosting Target:** Render Free Web Service (production/staging) + Local Node runtime (development)

---

## 2. Directory Structure

```text
backend/
├── contracts/
│   └── openapi.yaml                 # OpenAPI 3.1.0 versioned API specification
├── docs/
│   ├── ARCHITECTURE.md              # Technical architecture & feasibility research
│   ├── PRIVACY_AND_AI_SAFETY.md     # Untrusted input isolation, prompt defense & privacy
│   ├── DATABASE_AND_AUTH_DESIGN.md  # Entity model, RLS policies & deletion lifecycle
│   └── SETUP_GUIDE.md               # Beginner-friendly setup guide for free services
└── README.md                        # This document
```

---

## 3. Documentation Ownership Policy

To avoid conflicting or divergent roadmaps across branches:
- **Shared Project Documentation:** The authoritative 50-module roadmap (`docs/ROADMAP.md`), project-wide state (`docs/PROJECT_STATE.md`), and historical log (`docs/MODULE_LOG.md`) are maintained on the **`frontend`** branch.
- **Backend Documentation:** Backend-specific service architecture, API contracts, database entity design, and setup guides are maintained on the **`backend`** branch under `backend/docs/` and `backend/contracts/`.

---

## 4. API Endpoints Summary (Module 27 Baseline)

| Method | Path | Status | Auth Required? | Purpose |
|---|---|---|---|---|
| `GET` | `/health` | Defined | No | Liveness probe for hosting orchestrator |
| `GET` | `/ready` | Defined | No | Readiness probe checking dependencies |
| `POST` | `/api/v1/analysis/ai` | Defined | **Yes (Bearer JWT)** | Protected AI analysis with evidence verification |
| `GET` | `/api/v1/account/profile` | Defined | **Yes (Bearer JWT)** | Retrieve authenticated user profile metadata |
| `DELETE` | `/api/v1/account` | Defined | **Yes (Bearer JWT)** | Cascade delete user account and server data |
| `GET/POST`| `/api/v1/sync/reports` | **Planned (Mod 39)** | **Yes (Bearer JWT)** | Optional encrypted cloud report backup |

Implementation begins in **Module 28** (Backend Foundation and Configuration).
