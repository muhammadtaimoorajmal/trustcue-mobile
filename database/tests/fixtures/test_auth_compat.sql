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

-- Allow postgres to switch roles during test execution
GRANT anon TO postgres;
GRANT authenticated TO postgres;
GRANT service_role TO postgres;

-- In Supabase, the service_role key has the BYPASSRLS attribute
ALTER ROLE service_role BYPASSRLS;

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

-- 4b. Implement Supabase-compatible auth.role() function
-- Extracts the JWT role string from standard request.jwt.claim.role setting
CREATE OR REPLACE FUNCTION auth.role()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.role', true), '')::TEXT;
$$;

COMMENT ON FUNCTION auth.role() IS 'Test compatibility simulator for Supabase auth.role() JWT extraction.';

-- 5. Test Helper Function to switch simulated authentication context
CREATE OR REPLACE FUNCTION auth.set_test_user(p_user_id UUID, p_role TEXT DEFAULT 'authenticated')
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    RESET ROLE;
    IF p_user_id IS NULL THEN
        PERFORM set_config('request.jwt.claim.sub', '', false);
    ELSE
        PERFORM set_config('request.jwt.claim.sub', p_user_id::text, false);
    END IF;
    IF p_role IS NULL THEN
        PERFORM set_config('request.jwt.claim.role', '', false);
    ELSE
        PERFORM set_config('request.jwt.claim.role', p_role, false);
    END IF;
    IF p_role IS NOT NULL AND p_role <> 'postgres' THEN
        EXECUTE format('SET ROLE %I', p_role);
    END IF;
END;
$$;

-- 6. Test Helper Function to reset to superuser/admin context
CREATE OR REPLACE FUNCTION auth.reset_test_user()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    RESET ROLE;
    PERFORM set_config('request.jwt.claim.sub', '', false);
    PERFORM set_config('request.jwt.claim.role', '', false);
END;
$$;

-- 7. Grant execution privileges on auth helper functions and schema to all roles
GRANT USAGE ON SCHEMA auth TO PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO PUBLIC, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO postgres, service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO authenticated, anon;

COMMIT;
