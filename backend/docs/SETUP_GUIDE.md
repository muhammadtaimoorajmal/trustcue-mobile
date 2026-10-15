# TrustCue Cloud Services Setup Guide

This guide provides step-by-step instructions for provisioning the free-tier cloud services required by the TrustCue backend.

> [!IMPORTANT]
> **Zero Financial Expenditure & Security Notice:**
> - None of the services below require an upfront payment or credit card to create free-tier developer accounts.
> - **NEVER paste secret keys, service role credentials, passwords, or recovery codes into chat.**
> - Store secrets exclusively in local environment files (`.env`) that are strictly ignored by Git.

---

## 1. Staged Service Overview

| Service | Role | Required In Module | Credit Card Required? | Free Tier Limits |
|---|---|---|---|---|
| **Supabase** | Managed Auth & Postgres Database | **Module 28 / 29** | **NO** | 50,000 MAUs, 500 MB DB, auto-pauses after 7 days inactivity |
| **Groq Cloud** | Primary Privacy-Preserving AI | **Module 33** | **NO** | 30 RPM, 14,400 RPD (Llama 3.3 70B / 3.1 8B), zero retention |
| **Google AI Studio** | Secondary Synthetic-Only AI | **Module 33** | **NO** | 15 RPM, 1,500 RPD (Gemini 1.5 Flash), synthetic data policy |
| **Render** | Cloud Hosting for Backend | **Module 47** | **NO** | 512 MB RAM, 750 free hours/month, sleeps after 15 min idle |

---

## 2. Service-by-Service Setup Instructions

### Stage 1: Supabase Setup (Required for Module 28/29)

1. **What is Needed & Why:** A managed PostgreSQL database and GoTrue authentication engine to validate user sessions, enforce Row Level Security, and manage account deletion.
2. **Official Portal:** [https://supabase.com](https://supabase.com)
3. **Account Creation & Configuration Steps:**
   - Click **"Start your project"** and sign in using your GitHub account or email.
   - Click **"New Project"**.
   - **Organization:** Select your default personal organization.
   - **Name:** Enter `trustcue-backend-dev`.
   - **Database Password:** Generate a strong random password (store in your personal password manager; do not share).
   - **Region:** Select the closest region to Pakistan:
     - Recommended: **Singapore (`ap-southeast-1`)** or **Frankfurt (`eu-central-1`)** for optimal latency and reliable service availability.
   - **Pricing Plan:** Select **Free ($0 / month)**.
   - Click **"Create new project"** (takes ~1–2 minutes to provision).
4. **Obtaining Configuration & Secrets:**
   - In the Supabase project dashboard, navigate to **Project Settings** (gear icon) -> **API**.
   - Note the following values:
     - **Project URL:** `https://<project-ref>.supabase.co` (*Public configuration*).
     - **Project API Keys -> `anon` (public):** `eyJhbGciOi...` (*Public client key*).
     - **Project API Keys -> `service_role` (secret):** `eyJhbGciOi...` (*PRIVILEGED SECRET KEY — keep confidential!*).
5. **Where to Store:**
   - In Module 28, you will place these values into `backend/.env` (which is git-ignored):
     ```bash
     SUPABASE_URL=https://your-project-ref.supabase.co
     SUPABASE_ANON_KEY=your-anon-public-key
     SUPABASE_SERVICE_ROLE_KEY=your-service-role-secret-key
     ```
6. **Verification:**
   - In Module 28, running the backend health check `npm run test:conn` will ping Supabase and confirm successful connection.

---

### Stage 2: Groq Cloud API Setup (Required for Module 33)

1. **What is Needed & Why:** Ultra-fast, zero-retention AI inference for scam-indicator analysis without customer prompt training.
2. **Official Portal:** [https://console.groq.com](https://console.groq.com)
3. **Account & Key Generation:**
   - Sign up using your Google or GitHub account.
   - Navigate to **API Keys** in the left sidebar.
   - Click **"Create API Key"**.
   - Enter a friendly name: `trustcue-backend-dev`.
   - Copy the generated API key (format: `gsk_...`).
4. **Billing & Credit Card:** **None required.** Groq provides free rate limits out-of-the-box.
5. **Where to Store:**
   ```bash
   AI_PROVIDER=groq
   GROQ_API_KEY=gsk_your_groq_api_key_here
   ```
6. **Verification:** Tested in Module 33 via automated test script.

---

### Stage 3: Google AI Studio Setup (Optional Fallback / Module 33)

1. **What is Needed & Why:** Access to Gemini 1.5 Flash for synthetic scenario evaluation.
2. **Official Portal:** [https://aistudio.google.com](https://aistudio.google.com)
3. **Account & Key Generation:**
   - Sign in with your Google account.
   - Ensure your account has completed age verification (`myaccount.google.com/age-verification`) if prompted.
   - Click **"Get API key"** -> **"Create API key in new project"**.
   - Copy the generated API key (`AIzaSy...`).
4. **Billing Notice:** The free tier does not require a credit card. **Remember:** Unpaid usage falls under Google's data training terms; use strictly with synthetic/anonymized test data.
5. **Where to Store:**
   ```bash
   GEMINI_API_KEY=AIzaSy_your_gemini_api_key_here
   ```

---

### Stage 4: Render Web Service Setup (Deferred to Module 47)

1. **What is Needed & Why:** Free container hosting for staging/production deployment.
2. **Official Portal:** [https://render.com](https://render.com)
3. **No action needed today.** Local development on `localhost:3000` is the primary and fastest environment for Modules 28–46.

---

## 3. Template `.env.example` (Git-Safe Template)

This template shows the variable names needed in later modules without exposing actual values:

```bash
# Server Configuration
PORT=3000
NODE_ENV=development
API_VERSION=v1

# Supabase Auth & Database (Public vs Secret)
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-public-key
SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-secret-key

# Primary AI Provider (Groq Cloud)
AI_PROVIDER=groq
GROQ_API_KEY=gsk_your_groq_api_key_placeholder
GROQ_MODEL=llama-3.3-70b-versatile

# Secondary AI Provider (Google Gemini - Synthetic Data Only on Free Tier)
GEMINI_API_KEY=AIzaSy_your_gemini_api_key_placeholder
GEMINI_MODEL=gemini-1.5-flash

# Logging & Operational Controls
LOG_LEVEL=info
MAX_DAILY_QUOTA_PER_USER=20
```

---

## 4. Immediate Action Checklist for Module 28

> [!TIP]
> **Action Required Before/During Module 28:**
> - **Action:** Create a free **Supabase** project following Section 2, Stage 1 above. Save your `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` locally in your password manager.
> - **AI Provider Accounts (Groq/Gemini):** **Not needed yet.** Module 28 focuses on backend foundation, health checks, and configuration validation. AI provider accounts will be required in Module 33.
