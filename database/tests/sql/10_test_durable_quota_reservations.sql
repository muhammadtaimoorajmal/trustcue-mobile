-- ==============================================================================
-- Test Suite: 10_test_durable_quota_reservations.sql
-- Description: Regression test suite for durable quota reservations, lifecycle states,
--              idempotent commit/refund, cross-user isolation, midnight refund, and
--              reaper safety (undispatched refund vs dispatched unsettled transition).
-- ==============================================================================

\set ON_ERROR_STOP on

BEGIN;

SELECT auth.reset_test_user();

-- Setup test users
INSERT INTO auth.users (id, email)
VALUES
    ('d0000000-0000-0000-0000-000000000001', 'durable_quota_user_1@test.com'),
    ('d0000000-0000-0000-0000-000000000002', 'durable_quota_user_2@test.com')
ON CONFLICT (id) DO NOTHING;

-- 1. Unprivileged Role CANNOT Execute v2 functions
SELECT auth.set_test_user('d0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

DO $$
BEGIN
    BEGIN
        PERFORM * FROM public.reserve_ai_quota_v2('d0000000-0000-0000-0000-000000000001'::uuid, gen_random_uuid(), 15);
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to execute reserve_ai_quota_v2!';
    EXCEPTION
        WHEN insufficient_privilege THEN NULL;
    END;
END $$;

DO $$
BEGIN
    BEGIN
        PERFORM public.dispatch_ai_quota_v2('d0000000-0000-0000-0000-000000000001'::uuid, gen_random_uuid());
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to execute dispatch_ai_quota_v2!';
    EXCEPTION
        WHEN insufficient_privilege THEN NULL;
    END;
END $$;

DO $$
BEGIN
    BEGIN
        PERFORM public.commit_ai_quota_v2('d0000000-0000-0000-0000-000000000001'::uuid, gen_random_uuid());
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to execute commit_ai_quota_v2!';
    EXCEPTION
        WHEN insufficient_privilege THEN NULL;
    END;
END $$;

DO $$
BEGIN
    BEGIN
        PERFORM public.release_ai_quota_v2('d0000000-0000-0000-0000-000000000001'::uuid, gen_random_uuid());
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to execute release_ai_quota_v2!';
    EXCEPTION
        WHEN insufficient_privilege THEN NULL;
    END;
END $$;

-- 2. Authenticated User CAN View Own Reservations via RLS, but CANNOT Mutate
DO $$
BEGIN
    BEGIN
        INSERT INTO public.ai_quota_reservations (id, user_id, quota_date, status)
        VALUES (gen_random_uuid(), 'd0000000-0000-0000-0000-000000000001'::uuid, CURRENT_DATE, 'reserved');
        RAISE EXCEPTION 'Security Failure: Authenticated user was able to insert into ai_quota_reservations!';
    EXCEPTION
        WHEN insufficient_privilege THEN NULL;
    END;
END $$;

-- 3. Service Role Executes Durable Reservation Lifecycle
SELECT auth.set_test_user(NULL, 'service_role');

DO $$
DECLARE
    v_res_1 UUID := '11111111-aaaa-bbbb-cccc-111111111111'::uuid;
    v_res_2 UUID := '22222222-aaaa-bbbb-cccc-222222222222'::uuid;
    v_res_3 UUID := '33333333-aaaa-bbbb-cccc-333333333333'::uuid;
    v_res_4 UUID := '44444444-aaaa-bbbb-cccc-444444444444'::uuid;
    v_user UUID := 'd0000000-0000-0000-0000-000000000001'::uuid;
    v_other_user UUID := 'd0000000-0000-0000-0000-000000000002'::uuid;
    r RECORD;
    v_success BOOLEAN;
    v_remaining INT;
BEGIN
    -- Initial remaining quota should be 3
    v_remaining := public.get_remaining_ai_quota(v_user, 3);
    IF v_remaining <> 3 THEN
        RAISE EXCEPTION 'Initial remaining expected 3, got %', v_remaining;
    END IF;

    -- Reservation 1
    SELECT * INTO r FROM public.reserve_ai_quota_v2(v_user, v_res_1, 3);
    IF NOT r.allowed OR r.requests_used <> 1 OR r.requests_remaining <> 2 THEN
        RAISE EXCEPTION 'Reservation 1 failed: %', r;
    END IF;

    -- Idempotent retry with same reservation ID does NOT double-increment
    SELECT * INTO r FROM public.reserve_ai_quota_v2(v_user, v_res_1, 3);
    IF NOT r.allowed OR r.requests_used <> 1 OR r.requests_remaining <> 2 THEN
        RAISE EXCEPTION 'Reservation 1 idempotent retry failed: %', r;
    END IF;

    -- Dispatch Reservation 1 (reserved -> dispatched)
    v_success := public.dispatch_ai_quota_v2(v_user, v_res_1);
    IF NOT v_success THEN
        RAISE EXCEPTION 'Dispatch Reservation 1 failed';
    END IF;

    -- Idempotent Dispatch Reservation 1 returns TRUE
    v_success := public.dispatch_ai_quota_v2(v_user, v_res_1);
    IF NOT v_success THEN
        RAISE EXCEPTION 'Idempotent dispatch Reservation 1 failed';
    END IF;

    -- Commit Reservation 1 (dispatched -> committed)
    v_success := public.commit_ai_quota_v2(v_user, v_res_1);
    IF NOT v_success THEN
        RAISE EXCEPTION 'Commit Reservation 1 failed';
    END IF;

    -- Idempotent Commit Reservation 1 returns TRUE
    v_success := public.commit_ai_quota_v2(v_user, v_res_1);
    IF NOT v_success THEN
        RAISE EXCEPTION 'Idempotent commit Reservation 1 failed';
    END IF;

    -- Committed reservation cannot be refunded
    v_success := public.release_ai_quota_v2(v_user, v_res_1);
    IF v_success THEN
        RAISE EXCEPTION 'Committed reservation was refunded unexpectedly!';
    END IF;

    -- Reservation 2
    SELECT * INTO r FROM public.reserve_ai_quota_v2(v_user, v_res_2, 3);
    IF NOT r.allowed OR r.requests_used <> 2 OR r.requests_remaining <> 1 THEN
        RAISE EXCEPTION 'Reservation 2 failed: %', r;
    END IF;

    -- Dispatch Reservation 2
    v_success := public.dispatch_ai_quota_v2(v_user, v_res_2);
    IF NOT v_success THEN
        RAISE EXCEPTION 'Dispatch Reservation 2 failed';
    END IF;

    -- Release / Refund Reservation 2 from dispatched state
    v_success := public.release_ai_quota_v2(v_user, v_res_2);
    IF NOT v_success THEN
        RAISE EXCEPTION 'Release Reservation 2 from dispatched failed';
    END IF;

    -- Remaining quota should be 2 after refunding Reservation 2
    v_remaining := public.get_remaining_ai_quota(v_user, 3);
    IF v_remaining <> 2 THEN
        RAISE EXCEPTION 'Remaining after refund expected 2, got %', v_remaining;
    END IF;

    -- Idempotent Release Reservation 2 returns TRUE
    v_success := public.release_ai_quota_v2(v_user, v_res_2);
    IF NOT v_success THEN
        RAISE EXCEPTION 'Idempotent release Reservation 2 failed';
    END IF;

    -- Released reservation cannot be committed
    v_success := public.commit_ai_quota_v2(v_user, v_res_2);
    IF v_success THEN
        RAISE EXCEPTION 'Released reservation was committed unexpectedly!';
    END IF;

    -- Reservation 3 (now used=2, remaining=1)
    SELECT * INTO r FROM public.reserve_ai_quota_v2(v_user, v_res_3, 3);
    IF NOT r.allowed OR r.requests_used <> 2 OR r.requests_remaining <> 1 THEN
        RAISE EXCEPTION 'Reservation 3 failed: %', r;
    END IF;

    -- Reservation 4 (now used=3, remaining=0)
    SELECT * INTO r FROM public.reserve_ai_quota_v2(v_user, v_res_4, 3);
    IF NOT r.allowed OR r.requests_used <> 3 OR r.requests_remaining <> 0 THEN
        RAISE EXCEPTION 'Reservation 4 failed: %', r;
    END IF;

    -- Reservation 5 must be DENIED (quota exhausted)
    SELECT * INTO r FROM public.reserve_ai_quota_v2(v_user, gen_random_uuid(), 3);
    IF r.allowed OR r.requests_remaining <> 0 THEN
        RAISE EXCEPTION 'Exhausted reservation unexpectedly allowed: %', r;
    END IF;

    -- Cross-user rejection check: Other user cannot dispatch, commit, or release user 1's reservation
    BEGIN
        PERFORM public.dispatch_ai_quota_v2(v_other_user, v_res_3);
        RAISE EXCEPTION 'Cross-user dispatch succeeded unexpectedly!';
    EXCEPTION
        WHEN SQLSTATE '42501' THEN NULL; -- Expected error
    END;

    BEGIN
        PERFORM public.commit_ai_quota_v2(v_other_user, v_res_3);
        RAISE EXCEPTION 'Cross-user commit succeeded unexpectedly!';
    EXCEPTION
        WHEN SQLSTATE '42501' THEN NULL; -- Expected error
    END;

    BEGIN
        PERFORM public.release_ai_quota_v2(v_other_user, v_res_3);
        RAISE EXCEPTION 'Cross-user release succeeded unexpectedly!';
    EXCEPTION
        WHEN SQLSTATE '42501' THEN NULL; -- Expected error
    END;
END $$;

-- 4. Cross-Midnight Rollover Refund Verification
DO $$
DECLARE
    v_user UUID := 'd0000000-0000-0000-0000-000000000001'::uuid;
    v_yesterday DATE := (timezone('utc'::text, now()))::date - INTERVAL '1 day';
    v_old_res UUID := '99999999-aaaa-bbbb-cccc-999999999999'::uuid;
    v_success BOOLEAN;
    v_count INT;
BEGIN
    -- Seed yesterday's usage and reservation
    INSERT INTO public.ai_usage_quotas (user_id, quota_date, request_count, token_count)
    VALUES (v_user, v_yesterday, 5, 0);

    INSERT INTO public.ai_quota_reservations (id, user_id, quota_date, status)
    VALUES (v_old_res, v_user, v_yesterday, 'reserved');

    -- Release old reservation across midnight rollover
    v_success := public.release_ai_quota_v2(v_user, v_old_res);
    IF NOT v_success THEN
        RAISE EXCEPTION 'Midnight release failed';
    END IF;

    -- Verify yesterday's usage was decremented to 4
    SELECT request_count INTO v_count
    FROM public.ai_usage_quotas
    WHERE user_id = v_user AND quota_date = v_yesterday;

    IF v_count <> 4 THEN
        RAISE EXCEPTION 'Yesterday usage count expected 4, got %', v_count;
    END IF;
END $$;

-- 5. Reaper Safety Verification (Reserved refunded vs Dispatched unsettled)
DO $$
DECLARE
    v_user UUID := 'd0000000-0000-0000-0000-000000000002'::uuid;
    v_today DATE := (timezone('utc'::text, now()))::date;
    v_res_abandoned_reserved UUID := 'aaaaaaaa-bbbb-cccc-dddd-111111111111'::uuid;
    v_res_abandoned_dispatched UUID := 'aaaaaaaa-bbbb-cccc-dddd-222222222222'::uuid;
    v_res_fresh UUID := 'aaaaaaaa-bbbb-cccc-dddd-333333333333'::uuid;
    v_reaped_count INT;
    v_status TEXT;
    v_usage_count INT;
    v_success BOOLEAN;
BEGIN
    -- Seed usage count = 3
    INSERT INTO public.ai_usage_quotas (user_id, quota_date, request_count, token_count)
    VALUES (v_user, v_today, 3, 0)
    ON CONFLICT (user_id, quota_date) DO UPDATE SET request_count = 3;

    -- 1) Abandoned reservation that was NEVER dispatched (created 20 mins ago)
    INSERT INTO public.ai_quota_reservations (id, user_id, quota_date, status, created_at)
    VALUES (v_res_abandoned_reserved, v_user, v_today, 'reserved', timezone('utc'::text, now()) - INTERVAL '20 minutes');

    -- 2) Abandoned reservation that WAS dispatched (created 20 mins ago)
    INSERT INTO public.ai_quota_reservations (id, user_id, quota_date, status, created_at)
    VALUES (v_res_abandoned_dispatched, v_user, v_today, 'dispatched', timezone('utc'::text, now()) - INTERVAL '20 minutes');

    -- 3) Fresh reservation (created 1 min ago)
    INSERT INTO public.ai_quota_reservations (id, user_id, quota_date, status, created_at)
    VALUES (v_res_fresh, v_user, v_today, 'reserved', timezone('utc'::text, now()) - INTERVAL '1 minute');

    -- Run reaper with 10-minute timeout (600s)
    v_reaped_count := public.reap_abandoned_reservations(600);

    -- Only the undispatched 'reserved' row should be refunded by the loop
    IF v_reaped_count <> 1 THEN
        RAISE EXCEPTION 'Expected reaper to return 1 reaped reservation, got %', v_reaped_count;
    END IF;

    -- Check status of abandoned reserved: should be 'released'
    SELECT status INTO v_status FROM public.ai_quota_reservations WHERE id = v_res_abandoned_reserved;
    IF v_status <> 'released' THEN
        RAISE EXCEPTION 'Expected abandoned reserved to be released, got %', v_status;
    END IF;

    -- Check status of abandoned dispatched: should be 'unsettled'
    SELECT status INTO v_status FROM public.ai_quota_reservations WHERE id = v_res_abandoned_dispatched;
    IF v_status <> 'unsettled' THEN
        RAISE EXCEPTION 'Expected abandoned dispatched to be unsettled, got %', v_status;
    END IF;

    -- Check status of fresh reservation: should remain 'reserved'
    SELECT status INTO v_status FROM public.ai_quota_reservations WHERE id = v_res_fresh;
    IF v_status <> 'reserved' THEN
        RAISE EXCEPTION 'Expected fresh reservation to remain reserved, got %', v_status;
    END IF;

    -- Usage count should be 2 (decremented by 1 for the reserved row, NOT decremented for dispatched)
    SELECT request_count INTO v_usage_count FROM public.ai_usage_quotas WHERE user_id = v_user AND quota_date = v_today;
    IF v_usage_count <> 2 THEN
        RAISE EXCEPTION 'Expected usage count 2 after reaper, got %', v_usage_count;
    END IF;

    -- Attempting to release 'unsettled' reservation must be REJECTED (returns FALSE)
    v_success := public.release_ai_quota_v2(v_user, v_res_abandoned_dispatched);
    IF v_success THEN
        RAISE EXCEPTION 'Release of unsettled reservation should fail!';
    END IF;

    -- Attempting to commit 'unsettled' reservation (e.g. late recovery) should SUCCEED
    v_success := public.commit_ai_quota_v2(v_user, v_res_abandoned_dispatched);
    IF NOT v_success THEN
        RAISE EXCEPTION 'Commit of unsettled reservation should succeed!';
    END IF;

    SELECT status INTO v_status FROM public.ai_quota_reservations WHERE id = v_res_abandoned_dispatched;
    IF v_status <> 'committed' THEN
        RAISE EXCEPTION 'Expected committed status after unsettled commit, got %', v_status;
    END IF;
END $$;

ROLLBACK;
