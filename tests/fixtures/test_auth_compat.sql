-- ==============================================================================
-- Test Fixture: test_auth_compat.sql
-- Description: Compatibility harness for executing RLS regression tests on vanilla PostgreSQL.
-- Authorship: TrustCue Project Team (Module 29)
-- IMPORTANT NOTICE:
--   - This harness is STRICTLY for local and CI regression testing against pure PostgreSQL.
--   - It is NEVER deployed to production or Supabase (where auth schema and functions are managed).
--   - Simulates Supabase auth.users, auth.uid(), and roles (anon, authenticated, service_role).
-- ==============================================================================

BEGIN;

-- 1. Create auth schema if not present
CREATE SCHEMA IF NOT EXISTS auth;

-- 2. Create mock auth.users table matching Supabase core columns
CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- 3. Create simulated Supabase roles if not present
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN;
    END IF;
END $$;

-- 4. Implement Supabase-compatible auth.uid() function
-- Extracts the UUID from the standard request.jwt.claim.sub configuration setting
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID;
$$;

COMMENT ON FUNCTION auth.uid() IS 'Test compatibility simulator for Supabase auth.uid() JWT extraction.';

-- 5. Test Helper Function to switch simulated authentication context
CREATE OR REPLACE FUNCTION auth.set_test_user(p_user_id UUID, p_role TEXT DEFAULT 'authenticated')
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_user_id IS NULL THEN
        PERFORM set_config('request.jwt.claim.sub', '', false);
    ELSE
        PERFORM set_config('request.jwt.claim.sub', p_user_id::text, false);
    END IF;
    EXECUTE format('SET ROLE %I', p_role);
END;
$$;

-- 6. Test Helper Function to reset to superuser/admin context
CREATE OR REPLACE FUNCTION auth.reset_test_user()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM set_config('request.jwt.claim.sub', '', false);
    RESET ROLE;
END;
$$;

COMMIT;
