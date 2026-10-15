-- ==============================================================================
-- Migration: 00004_create_rls_and_policies.sql
-- Description: Enables Row Level Security, revokes default privileges, and enforces user isolation.
-- Authorship: TrustCue Project Team (Module 29)
-- Invariants:
--   - Default privileges revoked from PUBLIC and anon.
--   - Row Level Security enabled and forced on all public application tables.
--   - Authenticated users can only read and mutate their own profile and reports.
--   - Authenticated users CANNOT insert, update, or delete AI quota records.
--   - UPDATE policies enforce both USING and WITH CHECK to prevent ownership theft.
--   - Anonymous clients receive zero read/write access across all tables.
-- ==============================================================================

BEGIN;

-- 1. Enable and Force Row Level Security on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;

ALTER TABLE public.ai_usage_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_quotas FORCE ROW LEVEL SECURITY;

ALTER TABLE public.synced_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.synced_reports FORCE ROW LEVEL SECURITY;

-- 2. Revoke all default permissions from PUBLIC and anon
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- 3. Explicit Table Grants by Role
-- Profiles: Authenticated users can read, insert, and update their own record
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;

-- AI Quotas: Authenticated users have read-only access; write privileges strictly DENIED
GRANT SELECT ON public.ai_usage_quotas TO authenticated;

-- Synced Reports: Authenticated users have full CRUD over their own records
GRANT SELECT, INSERT, UPDATE, DELETE ON public.synced_reports TO authenticated;

-- Service Role (trusted backend): Full administrative access (bypasses RLS)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- 4. RLS Policies: public.profiles
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 5. RLS Policies: public.ai_usage_quotas
-- Read-only policy for authenticated users; no write policies exist for authenticated role
DROP POLICY IF EXISTS "quotas_select_own" ON public.ai_usage_quotas;
CREATE POLICY "quotas_select_own"
    ON public.ai_usage_quotas FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 6. RLS Policies: public.synced_reports
DROP POLICY IF EXISTS "reports_select_own" ON public.synced_reports;
CREATE POLICY "reports_select_own"
    ON public.synced_reports FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "reports_insert_own" ON public.synced_reports;
CREATE POLICY "reports_insert_own"
    ON public.synced_reports FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "reports_update_own" ON public.synced_reports;
CREATE POLICY "reports_update_own"
    ON public.synced_reports FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "reports_delete_own" ON public.synced_reports;
CREATE POLICY "reports_delete_own"
    ON public.synced_reports FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

COMMIT;
