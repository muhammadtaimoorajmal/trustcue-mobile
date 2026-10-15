-- ==============================================================================
-- Test Suite: 05_test_quota_reservation.sql
-- Description: Regression test for atomic quota reservation, release, and profile recovery.
-- ==============================================================================

\set ON_ERROR_STOP on

BEGIN;

SELECT auth.reset_test_user();

-- Setup test users
INSERT INTO auth.users (id, email)
VALUES
    ('c0000000-0000-0000-0000-000000000001', 'quota_user_1@test.com'),
    ('c0000000-0000-0000-0000-000000000002', 'quota_user_2@test.com')
ON CONFLICT (id) DO NOTHING;

-- 1. Unprivileged Role CANNOT Execute reserve_ai_quota or release_ai_quota
SELECT auth.set_test_user('c0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

DO $$
BEGIN
    BEGIN
        PERFORM * FROM public.reserve_ai_quota('c0000000-0000-0000-0000-000000000001'::uuid, 15, 100);
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to execute reserve_ai_quota!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL; -- Expected: revoked from authenticated
    END;
END $$;

DO $$
BEGIN
    BEGIN
        PERFORM public.release_ai_quota('c0000000-0000-0000-0000-000000000001'::uuid, 100);
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to execute release_ai_quota!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL; -- Expected: revoked from authenticated
    END;
END $$;

-- 2. Service Role Successfully Reserves Quota
SELECT auth.set_test_user(NULL, 'service_role');

-- Test first reservation with limit 3
DO $$
DECLARE
    r RECORD;
BEGIN
    SELECT * INTO r FROM public.reserve_ai_quota('c0000000-0000-0000-0000-000000000001'::uuid, 3, 100);

    IF NOT r.allowed OR r.requests_used <> 1 OR r.requests_remaining <> 2 THEN
        RAISE EXCEPTION 'Reservation Failure (1): Expected (true, 1, 2), got (%, %, %)',
            r.allowed, r.requests_used, r.requests_remaining;
    END IF;

    -- Second reservation
    SELECT * INTO r FROM public.reserve_ai_quota('c0000000-0000-0000-0000-000000000001'::uuid, 3, 150);
    IF NOT r.allowed OR r.requests_used <> 2 OR r.requests_remaining <> 1 THEN
        RAISE EXCEPTION 'Reservation Failure (2): Expected (true, 2, 1), got (%, %, %)',
            r.allowed, r.requests_used, r.requests_remaining;
    END IF;

    -- Third reservation (exhausts limit 3)
    SELECT * INTO r FROM public.reserve_ai_quota('c0000000-0000-0000-0000-000000000001'::uuid, 3, 200);
    IF NOT r.allowed OR r.requests_used <> 3 OR r.requests_remaining <> 0 THEN
        RAISE EXCEPTION 'Reservation Failure (3): Expected (true, 3, 0), got (%, %, %)',
            r.allowed, r.requests_used, r.requests_remaining;
    END IF;

    -- Fourth reservation should be DENIED
    SELECT * INTO r FROM public.reserve_ai_quota('c0000000-0000-0000-0000-000000000001'::uuid, 3, 50);
    IF r.allowed OR r.requests_remaining <> 0 THEN
        RAISE EXCEPTION 'Reservation Failure (4): Limit exceeded but allowed=% remaining=%',
            r.allowed, r.requests_remaining;
    END IF;
END $$;

-- 3. Quota Release / Refund
DO $$
DECLARE
    r RECORD;
    v_req_count INT;
    v_token_count INT;
BEGIN
    -- Release 1 request and 200 tokens
    PERFORM public.release_ai_quota('c0000000-0000-0000-0000-000000000001'::uuid, 200);

    SELECT request_count, token_count INTO v_req_count, v_token_count
    FROM public.ai_usage_quotas
    WHERE user_id = 'c0000000-0000-0000-0000-000000000001'::uuid
      AND quota_date = (timezone('utc'::text, now()))::date;

    IF v_req_count <> 2 OR v_token_count <> 250 THEN
        RAISE EXCEPTION 'Refund Failure: Expected (2 requests, 250 tokens), got (% requests, % tokens)',
            v_req_count, v_token_count;
    END IF;

    -- Should now be able to reserve one more slot
    SELECT * INTO r FROM public.reserve_ai_quota('c0000000-0000-0000-0000-000000000001'::uuid, 3, 50);
    IF NOT r.allowed OR r.requests_used <> 3 THEN
        RAISE EXCEPTION 'Post-refund Reservation Failure: Expected allowed=true, used=3, got allowed=%, used=%',
            r.allowed, r.requests_used;
    END IF;
END $$;

-- 4. Missing Profile Recovery
DO $$
DECLARE
    v_profile_exists BOOLEAN;
BEGIN
    -- user_2 has no profile initially
    DELETE FROM public.profiles WHERE id = 'c0000000-0000-0000-0000-000000000002'::uuid;

    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = 'c0000000-0000-0000-0000-000000000002'::uuid)
    INTO v_profile_exists;

    IF v_profile_exists THEN
        RAISE EXCEPTION 'Setup Failure: Profile should be deleted for test.';
    END IF;

    -- Call ensure_profile_exists
    PERFORM public.ensure_profile_exists('c0000000-0000-0000-0000-000000000002'::uuid);

    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = 'c0000000-0000-0000-0000-000000000002'::uuid)
    INTO v_profile_exists;

    IF NOT v_profile_exists THEN
        RAISE EXCEPTION 'Profile Recovery Failure: ensure_profile_exists did not create profile.';
    END IF;
END $$;

SELECT auth.reset_test_user();

ROLLBACK;
