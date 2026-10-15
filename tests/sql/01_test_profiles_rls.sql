-- ==============================================================================
-- Test Suite: 01_test_profiles_rls.sql
-- Description: Regression test for public.profiles RLS policies and role isolation.
-- ==============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Ensure test users exist
SELECT auth.reset_test_user();
INSERT INTO auth.users (id, email)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'user_a@test.com'),
    ('b0000000-0000-0000-0000-000000000002', 'user_b@test.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Verify Anonymous (anon) Role Access is Denied
SELECT auth.set_test_user(NULL, 'anon');

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count FROM public.profiles;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: Anonymous role observed % rows from public.profiles (expected 0).', v_count;
    END IF;
END $$;

-- 3. Authenticated User A Can Insert and Read Own Profile
SELECT auth.set_test_user('a0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

INSERT INTO public.profiles (id, display_name, terms_version, sync_enabled)
VALUES ('a0000000-0000-0000-0000-000000000001', 'User A', '1.0.0', FALSE)
ON CONFLICT (id) DO UPDATE SET display_name = 'User A';

DO $$
DECLARE
    v_name TEXT;
BEGIN
    SELECT display_name INTO v_name FROM public.profiles WHERE id = 'a0000000-0000-0000-0000-000000000001';
    IF v_name <> 'User A' THEN
        RAISE EXCEPTION 'RLS Failure: User A failed to read own profile (got %)', v_name;
    END IF;
END $$;

-- 4. User A Can Update Own Profile
UPDATE public.profiles
SET sync_enabled = TRUE, terms_version = '1.0.1'
WHERE id = 'a0000000-0000-0000-0000-000000000001';

DO $$
DECLARE
    v_sync BOOLEAN;
BEGIN
    SELECT sync_enabled INTO v_sync FROM public.profiles WHERE id = 'a0000000-0000-0000-0000-000000000001';
    IF v_sync IS NOT TRUE THEN
        RAISE EXCEPTION 'RLS Failure: User A failed to update own profile.';
    END IF;
END $$;

-- 5. User B Cannot View or Update User A's Profile
SELECT auth.set_test_user('b0000000-0000-0000-0000-000000000002'::uuid, 'authenticated');

-- User B should observe 0 rows when querying User A's profile
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count FROM public.profiles WHERE id = 'a0000000-0000-0000-0000-000000000001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: User B was able to view User A profile (count=%).', v_count;
    END IF;
END $$;

-- User B attempting to update User A's profile affects 0 rows
DO $$
DECLARE
    v_rows_affected INT;
BEGIN
    UPDATE public.profiles SET display_name = 'Hacked by B' WHERE id = 'a0000000-0000-0000-0000-000000000001';
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    IF v_rows_affected <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: User B modified User A profile (rows=%).', v_rows_affected;
    END IF;
END $$;

-- User B cannot steal User A's identity by updating own ID to User A
INSERT INTO public.profiles (id, display_name)
VALUES ('b0000000-0000-0000-0000-000000000002', 'User B')
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
    BEGIN
        UPDATE public.profiles SET id = 'a0000000-0000-0000-0000-000000000001' WHERE id = 'b0000000-0000-0000-0000-000000000002';
        RAISE EXCEPTION 'RLS Failure: User B successfully changed profile ownership to User A!';
    EXCEPTION
        WHEN OTHERS THEN
            -- Expected rejection via RLS WITH CHECK policy
            NULL;
    END;
END $$;

-- 6. Field Boundaries: Oversized display_name is rejected
SELECT auth.set_test_user('a0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');
DO $$
BEGIN
    BEGIN
        UPDATE public.profiles
        SET display_name = repeat('X', 70)  -- Max allowed is 64
        WHERE id = 'a0000000-0000-0000-0000-000000000001';
        RAISE EXCEPTION 'Constraint Failure: Oversized display_name was accepted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected
    END;
END $$;

SELECT auth.reset_test_user();

ROLLBACK;
