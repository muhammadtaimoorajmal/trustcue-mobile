# TrustCue Database Setup & Migration Guide

This guide describes how to apply versioned migrations, run regression tests, and configure PostgreSQL / Supabase for TrustCue.

---

## 1. Prerequisites and Verification Philosophy

TrustCue enforces strict schema verification while avoiding unnecessary local daemon overhead:
- **Local Static Verification**: A fast Python suite (`tests/test_static_schema.py`) validates DDL structure, constraints, RLS policy completeness, and privacy invariants locally without requiring a running database engine.
- **Continuous Integration (PostgreSQL 16)**: GitHub Actions executes a live `postgres:16-alpine` service to run all transactional SQL test suites, proving RLS enforcement and cascade deletion in a genuine PostgreSQL environment.
- **Production Engine**: Supabase (PostgreSQL 16) with built-in GoTrue auth.

> [!IMPORTANT]
> Never use SQLite to validate PostgreSQL Row Level Security (RLS). SQLite does not support PostgreSQL role-based grants, `FORCE ROW LEVEL SECURITY`, or `auth.uid()` session context.

---

## 2. Migration Sequence

Migrations are located in `migrations/` and must be applied in strict numerical order:

| File | Purpose | Key Objects Created |
| :--- | :--- | :--- |
| `00001_create_profiles.sql` | User profiles & preferences | `public.profiles`, length constraints |
| `00002_create_ai_usage_quotas.sql` | Rate limiting counters | `public.ai_usage_quotas`, non-negative checks |
| `00003_create_synced_reports.sql` | Cloud report synchronization | `public.synced_reports`, 500 KB limit, tombstone check |
| `00004_create_rls_and_policies.sql` | RLS and permission grants | RLS enabled/forced, role grants, policies |
| `00005_create_auth_trigger.sql` | Automatic profile provisioning | `public.handle_new_user()` trigger on `auth.users` |

---

## 3. Running Migrations Locally

### Option A: Standard PostgreSQL or Docker Container

1. **Start PostgreSQL 16**:
   ```bash
   docker run -d --name trustcue-db \
     -e POSTGRES_DB=trustcue_db \
     -e POSTGRES_USER=postgres \
     -e POSTGRES_PASSWORD=postgres \
     -p 5432:5432 postgres:16-alpine
   ```

2. **Apply Auth Compatibility Fixture (Test Only)**:
   > [!WARNING]
   > Do NOT apply `test_auth_compat.sql` to a production Supabase project! Supabase provides its own native `auth` schema.
   ```bash
   psql -h localhost -U postgres -d trustcue_db -f tests/fixtures/test_auth_compat.sql
   ```

3. **Apply Migrations**:
   ```bash
   for f in migrations/*.sql; do
     echo "Applying $f..."
     psql -h localhost -U postgres -d trustcue_db -v ON_ERROR_STOP=1 -f "$f"
   done
   ```

4. **Seed Synthetic Test Data (Optional)**:
   ```bash
   psql -h localhost -U postgres -d trustcue_db -v ON_ERROR_STOP=1 -f seeds/001_synthetic_test_seeds.sql
   ```

5. **Run SQL Regression Test Suites**:
   ```bash
   psql -h localhost -U postgres -d trustcue_db -v ON_ERROR_STOP=1 -f tests/sql/01_test_profiles_rls.sql
   psql -h localhost -U postgres -d trustcue_db -v ON_ERROR_STOP=1 -f tests/sql/02_test_quotas_isolation.sql
   psql -h localhost -U postgres -d trustcue_db -v ON_ERROR_STOP=1 -f tests/sql/03_test_reports_sync_rls.sql
   psql -h localhost -U postgres -d trustcue_db -v ON_ERROR_STOP=1 -f tests/sql/04_test_cascade_deletion.sql
   ```

### Option B: Local Supabase CLI

1. Initialize and start Supabase:
   ```bash
   supabase init
   supabase start
   ```
2. Copy migrations to `supabase/migrations` or apply directly using `psql` to the local connection string (`postgresql://postgres:postgres@localhost:54322/postgres`).

---

## 4. Applying Migrations to Supabase (Hosted)

When deploying to a Supabase cloud project:
1. Ensure you are connected to your Supabase project using the CLI or Dashboard SQL Editor.
2. Apply `migrations/00001_create_profiles.sql` through `00005_create_auth_trigger.sql` in order.
3. Verify that Row Level Security is active and forced on all tables:
   ```sql
   SELECT tablename, rowsecurity
   FROM pg_tables
   WHERE schemaname = 'public';
   ```
   All tables (`profiles`, `ai_usage_quotas`, `synced_reports`) must return `rowsecurity = true`.
4. Verify table policies:
   ```sql
   SELECT schemaname, tablename, policyname, permissive, roles, cmd
   FROM pg_policies
   WHERE schemaname = 'public';
   ```

---

## 5. Local Static Validation

To run the local static schema validation suite without a database:
```bash
python -m unittest discover tests
```
This tests:
- Transactional encapsulation of all migration files.
- Exact table schema invariants and constraints.
- Complete absence of unredacted prompt or conversation text storage.
- RLS policy coverage, role grants, and `WITH CHECK` clauses.
- `SECURITY DEFINER` and `search_path` security hygiene on trigger functions.
- Regression test coverage and cleanup patterns.
