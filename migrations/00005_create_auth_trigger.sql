-- ==============================================================================
-- Migration: 00005_create_auth_trigger.sql
-- Description: Creates a safe, robust profile-creation trigger on auth.users.
-- Authorship: TrustCue Project Team (Module 29)
-- Invariants:
--   - Executes as SECURITY DEFINER with fixed search_path = public, auth, pg_temp.
--   - Explicit execution grants: revoked from PUBLIC, anon, and authenticated.
--   - Does NOT inspect or cast user-controlled raw metadata (prevents privilege escalation & signup failure).
--   - Safe exception handling: guarantees user registration is never aborted by profile creation edge cases.
--   - Idempotent ON CONFLICT (id) DO NOTHING.
-- ==============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        created_at,
        updated_at,
        terms_version,
        sync_enabled
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.created_at, timezone('utc'::text, now())),
        COALESCE(NEW.created_at, timezone('utc'::text, now())),
        '1.0.0',
        FALSE
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Safeguard: Never block user registration if background profile creation fails
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS 'Trigger function automatically provisioning a public.profiles row on auth.users creation.';

-- Lock down function execution permissions
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role;

-- Conditionally attach trigger if auth.users table is present in the database
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_namespace n
        JOIN pg_class c ON c.relnamespace = n.oid
        WHERE n.nspname = 'auth' AND c.relname = 'users'
    ) THEN
        DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
        CREATE TRIGGER on_auth_user_created
            AFTER INSERT ON auth.users
            FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
    END IF;
END $$;

COMMIT;
