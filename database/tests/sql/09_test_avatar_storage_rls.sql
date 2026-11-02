-- ==============================================================================
-- Test Suite: 09_test_avatar_storage_rls.sql
-- Description: Regression test for avatar_path field constraints and avatars storage bucket RLS.
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

INSERT INTO public.profiles (id, display_name, terms_version, sync_enabled)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'User A', '1.0.0', FALSE),
    ('b0000000-0000-0000-0000-000000000002', 'User B', '1.0.0', FALSE)
ON CONFLICT (id) DO NOTHING;

-- 2. Verify avatar_path format constraint on public.profiles
-- User A can update avatar_path to valid format
SELECT auth.set_test_user('a0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

UPDATE public.profiles
SET avatar_path = 'a0000000-0000-0000-0000-000000000001/avatar_12345.png'
WHERE id = 'a0000000-0000-0000-0000-000000000001';

DO $$
DECLARE
    v_path TEXT;
BEGIN
    SELECT avatar_path INTO v_path FROM public.profiles WHERE id = 'a0000000-0000-0000-0000-000000000001';
    IF v_path <> 'a0000000-0000-0000-0000-000000000001/avatar_12345.png' THEN
        RAISE EXCEPTION 'Constraint Failure: avatar_path update did not persist correctly';
    END IF;
END $$;

-- Verify invalid format triggers check constraint
DO $$
BEGIN
    BEGIN
        UPDATE public.profiles
        SET avatar_path = 'invalid path with spaces.exe'
        WHERE id = 'a0000000-0000-0000-0000-000000000001';
        RAISE EXCEPTION 'Constraint Failure: invalid avatar_path did not throw check constraint violation';
    EXCEPTION
        WHEN check_violation THEN
            -- Expected
            NULL;
    END;
END $$;

-- 3. Anonymous (anon) access to storage.objects is denied
SELECT auth.set_test_user(NULL, 'anon');

DO $$
DECLARE
    v_count INT;
BEGIN
    BEGIN
        SELECT count(*) INTO v_count FROM storage.objects WHERE bucket_id = 'avatars';
        IF v_count <> 0 THEN
            RAISE EXCEPTION 'RLS Failure: Anonymous role observed % rows from storage.objects (expected 0)', v_count;
        END IF;
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL;
    END;
END $$;

-- 4. User A can insert an object into their own folder
SELECT auth.set_test_user('a0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

INSERT INTO storage.objects (id, bucket_id, name)
VALUES (
    'c0000000-0000-0000-0000-000000000001',
    'avatars',
    'a0000000-0000-0000-0000-000000000001/avatar.png'
);

-- User A can see their own avatar
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count FROM storage.objects
    WHERE bucket_id = 'avatars' AND name = 'a0000000-0000-0000-0000-000000000001/avatar.png';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'RLS Failure: User A cannot see their own avatar (got %)', v_count;
    END IF;
END $$;

-- 5. User B CANNOT see User A's avatar
SELECT auth.set_test_user('b0000000-0000-0000-0000-000000000002'::uuid, 'authenticated');

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count FROM storage.objects
    WHERE bucket_id = 'avatars' AND name = 'a0000000-0000-0000-0000-000000000001/avatar.png';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: User B was able to see User A avatar! (got %)', v_count;
    END IF;
END $$;

-- 6. User B CANNOT insert an object into User A's folder
DO $$
BEGIN
    BEGIN
        INSERT INTO storage.objects (id, bucket_id, name)
        VALUES (
            'c0000000-0000-0000-0000-000000000002',
            'avatars',
            'a0000000-0000-0000-0000-000000000001/hacked.png'
        );
        RAISE EXCEPTION 'RLS Failure: User B successfully inserted into User A avatar folder!';
    EXCEPTION
        WHEN insufficient_privilege OR check_violation OR row_security_active_violation THEN
            NULL;
    END;
END $$;

-- 7. User B CANNOT update or delete User A's avatar
UPDATE storage.objects
SET name = 'a0000000-0000-0000-0000-000000000001/overwritten.png'
WHERE name = 'a0000000-0000-0000-0000-000000000001/avatar.png';

DELETE FROM storage.objects
WHERE name = 'a0000000-0000-0000-0000-000000000001/avatar.png';

-- Verify User A's avatar is still intact
SELECT auth.set_test_user('a0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count FROM storage.objects
    WHERE bucket_id = 'avatars' AND name = 'a0000000-0000-0000-0000-000000000001/avatar.png';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'RLS Failure: User A avatar was mutated or deleted by User B';
    END IF;
END $$;

-- 8. User A can delete their own avatar
DELETE FROM storage.objects
WHERE bucket_id = 'avatars' AND name = 'a0000000-0000-0000-0000-000000000001/avatar.png';

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count FROM storage.objects
    WHERE bucket_id = 'avatars' AND name = 'a0000000-0000-0000-0000-000000000001/avatar.png';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: User A avatar was not deleted';
    END IF;
END $$;

ROLLBACK;
