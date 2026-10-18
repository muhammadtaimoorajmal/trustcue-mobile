# TrustCue Backend Service

This directory contains the backend architecture, API contracts, database design, and server implementation for the TrustCue scam-awareness application.

## 1. Overview & Stack

- **Runtime & Language:** Python 3.13+ (tested on CPython 3.13.5)
- **Web Framework:** FastAPI + Pydantic v2 + Pydantic-Settings
- **ASGI Server:** Uvicorn (running on loopback `127.0.0.1:8000` by default)
- **Managed Authentication & Database:** Supabase (Auth + PostgreSQL with Row Level Security, planned in Modules 29–30)
- **AI Inference Engine:**
  - **Primary:** Groq Cloud API (`llama-3.3-70b-versatile`) — zero customer data training, bounded diagnostic retention (planned Module 33, disabled in Module 28 foundation)
  - **Secondary:** Google Gemini API (`gemini-1.5-flash`) — synthetic data policy on unpaid tier
- **Hosting Target:** Render Free Web Service (production/staging) + Local Python runtime (development)

---

## 2. Directory Structure

```text
backend/
├── contracts/
│   └── openapi.yaml                 # Authoritative OpenAPI 3.1.0 design specification
├── docs/
│   ├── ARCHITECTURE.md              # Technical architecture & feasibility research
│   ├── PRIVACY_AND_AI_SAFETY.md     # Untrusted input isolation, prompt defense & privacy
│   ├── DATABASE_AND_AUTH_DESIGN.md  # Entity model, RLS policies & deletion lifecycle
│   └── SETUP_GUIDE.md               # Setup guide for cloud services and configuration
├── src/
│   └── trustcue_backend/            # Core FastAPI application package
│       ├── api/                     # HTTP route handlers and dependencies
│       ├── core/                    # Config, error envelopes, logging & state management
│       └── main.py                  # Application factory (create_app) & lifespan
├── tests/                           # Unit, integration, error, and contract consistency tests
├── .env.example                     # Safe placeholder environment configuration
├── pyproject.toml                   # Project tool configuration (ruff, pytest)
├── requirements.txt                 # Runtime dependencies
├── requirements-dev.txt             # Development & testing dependencies
└── README.md                        # This document
```

---

## 3. Local Environment Setup & Execution

### Prerequisites
- Python 3.13+ installed on host.
- Git.

### 1. Create and Activate Virtual Environment
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### 2. Install Dependencies
```powershell
pip install -r backend/requirements-dev.txt
```

### 3. Run Development Server (Loopback)
```powershell
uvicorn backend.src.trustcue_backend.main:app --host 127.0.0.1 --port 8000
```
Interactive OpenAPI documentation is available at `http://127.0.0.1:8000/docs`.

### 4. Run Automated Tests
```powershell
pytest backend/tests
```

### 5. Validate OpenAPI Specification
```powershell
python -m openapi_spec_validator backend/contracts/openapi.yaml
```

### 6. Lint Codebase
```powershell
ruff check backend/src backend/tests
```

---

## 4. Documentation Ownership Policy

To avoid conflicting or divergent roadmaps across branches:
- **Shared Project Documentation:** The authoritative 50-module roadmap (`docs/ROADMAP.md`), project-wide state (`docs/PROJECT_STATE.md`), and historical log (`docs/MODULE_LOG.md`) are maintained on the **`frontend`** branch.
- **Backend Documentation:** Backend-specific service architecture, API contracts, database entity design, and setup guides are maintained on the **`backend`** branch under `backend/docs/` and `backend/contracts/`.

---

## 5. API Endpoints Implementation Status

| Method | Path | Status | Auth Required? | Purpose |
|---|---|---|---|---|
| `GET` | `/health` | **Implemented (Mod 28)** | No | Liveness probe for hosting orchestrator |
| `GET` | `/ready` | **Implemented (Mod 28)** | No | Readiness probe for active subsystems |
| `POST` | `/api/v1/analysis/ai` | **Implemented (Mod 33–35)** | **Yes (Bearer JWT)** | Protected AI analysis with evidence verification |
| `GET` | `/api/v1/account/profile` | **Implemented (Mod 30, 38, 44)** | **Yes (Bearer JWT)** | Retrieve authenticated user profile and quota metadata |
| `PATCH` | `/api/v1/account/profile` | **Implemented (Mod 38)** | **Yes (Bearer JWT)** | Update user profile display name |
| `DELETE` | `/api/v1/account` | **Implemented (Mod 30, 38)** | **Yes (Bearer JWT)** | Cascade delete user account and server data |
| `GET` | `/api/v1/sync/reports` | **Implemented (Mod 39–40, 44)** | **Yes (Bearer JWT)** | Delta pull optional cloud report metadata summaries |
| `POST` | `/api/v1/sync/reports` | **Implemented (Mod 39–40, 44)** | **Yes (Bearer JWT)** | Batch push optional cloud report metadata summaries |
| `DELETE` | `/api/v1/sync/reports` | **Implemented (Mod 39–40, 44)** | **Yes (Bearer JWT)** | Atomic purge of all cloud synced reports for user |

> **Note on Contract Scope:** The authoritative OpenAPI 3.1 design contract at `backend/contracts/openapi.yaml` defines the full target specification. The runtime schema generated by FastAPI (`/openapi.json`) dynamically exposes all active routes. Automated tests verify that all active routes strictly match the design contract.
