# TrustCue Database Schema & Migration Repository

This repository worktree contains the versioned PostgreSQL migrations, Row Level Security (RLS) policies, test fixtures, and regression test suites for the **TrustCue** platform (Module 29).

---

## Repository Structure

```text
trustcue-database/
├── .github/
│   └── workflows/
│       └── database-ci.yml          # PostgreSQL 16 CI workflow for automated migration & RLS testing
├── database/
│   ├── docs/
│   │   ├── ARCHITECTURE.md              # ER diagram, permission matrix, and privacy invariants
│   │   └── SETUP_AND_MIGRATION_GUIDE.md # Step-by-step migration application guide
│   ├── migrations/
│   │   ├── 00001_create_profiles.sql         # public.profiles table & boundaries
│   │   ├── 00002_create_ai_usage_quotas.sql  # public.ai_usage_quotas rate limiting datastore
│   │   ├── 00003_create_synced_reports.sql   # public.synced_reports opt-in cloud backups
│   │   ├── 00004_create_rls_and_policies.sql # RLS enablement, role grants & policies
│   │   ├── 00005_create_auth_trigger.sql    # Trigger provisioning profiles on auth.users signup
│   │   └── 00006_create_quota_reservation.sql# Server-side atomic quota reservation & profile recovery
│   ├── seeds/
│   │   └── 001_synthetic_test_seeds.sql      # Synthetic test seed data for test environments
│   ├── tests/
│   │   ├── fixtures/
│   │   │   └── test_auth_compat.sql     # PostgreSQL auth schema compatibility simulator
│   │   ├── sql/
│   │   │   ├── 01_test_profiles_rls.sql       # Profiles RLS and boundary regression tests
│   │   │   ├── 02_test_quotas_isolation.sql   # Quota read-only isolation regression tests
│   │   │   ├── 03_test_reports_sync_rls.sql   # Synced reports RLS & tombstone regression tests
│   │   │   ├── 04_test_cascade_deletion.sql   # ON DELETE CASCADE integrity regression tests
│   │   │   └── 05_test_quota_reservation.sql  # Atomic reservation & release regression tests
│   │   └── test_static_schema.py        # Offline Python static schema and policy test suite
│   └── pyproject.toml
├── .gitignore
└── README.md
```

---

## Security & Privacy Invariants

1. **Local-First Privacy**: No raw conversation text, user messages, evidence excerpts, or message hashes are stored in the database.
2. **Quota Tamper Protection**: Authenticated clients are strictly denied write privileges (`INSERT`, `UPDATE`, `DELETE`) on `ai_usage_quotas`. Only the trusted backend service role can execute atomic reservation (`reserve_ai_quota`) and release functions.
3. **Payload Boundaries**: Synced reports are strictly bounded to 500 KB per report and require explicit opt-in (`profiles.sync_enabled = true`).
4. **Row Level Security**: RLS is enabled and forced on all tables. Role isolation prevents cross-tenant data leaks.
5. **Clean Account Erasure**: Deleting a user in `auth.users` cleanly cascades to all child tables, leaving 0 orphan records.

---

## Verification

### Local Static Validation
Run the static verification suite using Python:
```bash
python -m unittest discover database/tests
```

### PostgreSQL 16 CI Execution
Continuous integration runs on GitHub Actions using a real `postgres:16-alpine` service container. It applies all migrations sequentially, injects synthetic seeds, and executes all SQL test suites to verify genuine PostgreSQL RLS enforcement.

For local execution with Docker or PostgreSQL, refer to [database/docs/SETUP_AND_MIGRATION_GUIDE.md](database/docs/SETUP_AND_MIGRATION_GUIDE.md).