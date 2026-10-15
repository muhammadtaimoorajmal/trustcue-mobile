-- ==============================================================================
-- Test Suite: 02_test_quotas_isolation.sql
-- Description: Regression test for public.ai_usage_quotas server-only accounting & constraints.
-- ==============================================================================

\set ON_ERROR_STOP on

BEGIN;

SELECT auth.reset_test_user();
INSERT INTO auth.users (id, email)
VALUES
    ('a0000000-0000-0000-0000-000000000001', 'user_a@test.com'),
    ('b0000000-0000-0000-0000-000000000002', 'user_b@test.com')
ON CONFLICT (id) DO NOTHING;

-- 1. Service Role Seeds a Quota Record
SELECT auth.set_test_user(NULL, 'service_role');

INSERT INTO public.ai_usage_quotas (user_id, quota_date, request_count, token_count)
VALUES ('a0000000-0000-0000-0000-000000000001', CURRENT_DATE, 5, 2500)
ON CONFLICT (user_id, quota_date) DO UPDATE SET request_count = 5;

-- 2. Authenticated User A Can Read Own Quota
SELECT auth.set_test_user('a0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

DO $$
DECLARE
    v_req_count INT;
BEGIN
    SELECT request_count INTO v_req_count
    FROM public.ai_usage_quotas
    WHERE user_id = 'a0000000-0000-0000-0000-000000000001';

    IF v_req_count <> 5 THEN
        RAISE EXCEPTION 'RLS Failure: User A expected 5 quota requests, got %', v_req_count;
    END IF;
END $$;

-- 3. Authenticated User A CANNOT Insert, Update, or Delete Quota Records
DO $$
BEGIN
    BEGIN
        INSERT INTO public.ai_usage_quotas (user_id, quota_date, request_count)
        VALUES ('a0000000-0000-0000-0000-000000000001', CURRENT_DATE + 1, 0);
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to INSERT into ai_usage_quotas!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL; -- Expected: write privileges revoked from authenticated
    END;
END $$;

DO $$
BEGIN
    BEGIN
        UPDATE public.ai_usage_quotas SET request_count = 0 WHERE user_id = 'a0000000-0000-0000-0000-000000000001';
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to UPDATE ai_usage_quotas!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL; -- Expected: write privileges revoked from authenticated
    END;
END $$;

DO $$
BEGIN
    BEGIN
        DELETE FROM public.ai_usage_quotas WHERE user_id = 'a0000000-0000-0000-0000-000000000001';
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to DELETE from ai_usage_quotas!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL; -- Expected: write privileges revoked from authenticated
    END;
END $$;

-- 4. User B Cannot View User A's Quotas
SELECT auth.set_test_user('b0000000-0000-0000-0000-000000000002'::uuid, 'authenticated');

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count
    FROM public.ai_usage_quotas
    WHERE user_id = 'a0000000-0000-0000-0000-000000000001';

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: User B observed User A quota records (count=%).', v_count;
    END IF;
END $$;

-- 5. Atomic Upsert Increments via Service Role Functionality
SELECT auth.set_test_user(NULL, 'service_role');

-- Test atomic reservation increment
INSERT INTO public.ai_usage_quotas (user_id, quota_date, request_count, last_request_at)
VALUES ('a0000000-0000-0000-0000-000000000001', CURRENT_DATE, 1, NOW())
ON CONFLICT (user_id, quota_date)
DO UPDATE SET
    request_count = public.ai_usage_quotas.request_count + 1,
    last_request_at = NOW();

DO $$
DECLARE
    v_new_count INT;
BEGIN
    SELECT request_count INTO v_new_count
    FROM public.ai_usage_quotas
    WHERE user_id = 'a0000000-0000-0000-0000-000000000001';

    IF v_new_count <> 6 THEN
        RAISE EXCEPTION 'Atomic increment failure: Expected count 6, got %', v_new_count;
    END IF;
END $$;

-- 6. Constraints: Negative counters are rejected
DO $$
BEGIN
    BEGIN
        INSERT INTO public.ai_usage_quotas (user_id, quota_date, request_count)
        VALUES ('b0000000-0000-0000-0000-000000000002', CURRENT_DATE, -1);
        RAISE EXCEPTION 'Constraint Failure: Negative request_count accepted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected
    END;
END $$;

SELECT auth.reset_test_user();

ROLLBACK;
