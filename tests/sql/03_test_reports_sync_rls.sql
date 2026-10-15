-- ==============================================================================
-- Test Suite: 03_test_reports_sync_rls.sql
-- Description: Regression tests for public.synced_reports RLS policies,
--              user isolation, size boundaries, and tombstone consistency.
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

-- 2. Verify Anonymous (anon) Role Cannot Read or Insert Reports
SELECT auth.set_test_user(NULL, 'anon');

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count FROM public.synced_reports;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: Anonymous role observed % rows from public.synced_reports (expected 0).', v_count;
    END IF;
END $$;

DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, report_payload, client_updated_at
        ) VALUES (
            'a0000000-0000-0000-0000-000000000001',
            'rep-anon-001',
            'snap-anon-001',
            '{"verdict": "suspicious"}'::jsonb,
            now()
        );
        RAISE EXCEPTION 'RLS Failure: Anonymous user was allowed to insert a synced report!';
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Expected permission denied
    END;
END $$;

-- 3. Authenticated User A Can Insert and Read Own Report
SELECT auth.set_test_user('a0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

INSERT INTO public.synced_reports (
    user_id, client_report_id, snapshot_id, schema_version, revision,
    report_payload, client_updated_at
) VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'rep-a-001',
    'snap-a-001',
    1,
    1,
    '{"verdict": "suspicious", "indicators": ["urgent_language"]}'::jsonb,
    now()
);

DO $$
DECLARE
    v_rep_id TEXT;
BEGIN
    SELECT client_report_id INTO v_rep_id
    FROM public.synced_reports
    WHERE user_id = 'a0000000-0000-0000-0000-000000000001';

    IF v_rep_id <> 'rep-a-001' THEN
        RAISE EXCEPTION 'RLS Failure: User A could not read own synced report (got %)', v_rep_id;
    END IF;
END $$;

-- 4. User B Cannot View, Update, or Delete User A's Report
SELECT auth.set_test_user('b0000000-0000-0000-0000-000000000002'::uuid, 'authenticated');

-- User B should observe 0 rows
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*) INTO v_count
    FROM public.synced_reports
    WHERE client_report_id = 'rep-a-001';

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: User B observed User A report (count=%).', v_count;
    END IF;
END $$;

-- User B update should affect 0 rows
DO $$
DECLARE
    v_affected INT;
BEGIN
    UPDATE public.synced_reports
    SET report_payload = '{"tampered": true}'::jsonb
    WHERE client_report_id = 'rep-a-001';

    GET DIAGNOSTICS v_affected = ROW_COUNT;
    IF v_affected <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: User B updated User A report (affected=%).', v_affected;
    END IF;
END $$;

-- User B delete should affect 0 rows
DO $$
DECLARE
    v_affected INT;
BEGIN
    DELETE FROM public.synced_reports
    WHERE client_report_id = 'rep-a-001';

    GET DIAGNOSTICS v_affected = ROW_COUNT;
    IF v_affected <> 0 THEN
        RAISE EXCEPTION 'RLS Failure: User B deleted User A report (affected=%).', v_affected;
    END IF;
END $$;

-- 5. User B Cannot Insert Report Bound to User A (Cross-Account Spoofing)
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, report_payload, client_updated_at
        ) VALUES (
            'a0000000-0000-0000-0000-000000000001', -- Trying to inject as User A
            'rep-b-spoof',
            'snap-b-spoof',
            '{"spoofed": true}'::jsonb,
            now()
        );
        RAISE EXCEPTION 'RLS Failure: User B inserted report assigned to User A!';
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Expected rejection via WITH CHECK
    END;
END $$;

-- 6. User A Size Boundary Enforcement (500 KB Limit)
SELECT auth.set_test_user('a0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

DO $$
DECLARE
    v_oversized JSONB;
BEGIN
    -- Construct payload exceeding 500,000 bytes
    v_oversized := jsonb_build_object('data', repeat('A', 500050));
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, report_payload, client_updated_at
        ) VALUES (
            'a0000000-0000-0000-0000-000000000001',
            'rep-a-oversized',
            'snap-a-002',
            v_oversized,
            now()
        );
        RAISE EXCEPTION 'Constraint Failure: Oversized payload (>500KB) was permitted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected constraint violation chk_report_payload_size
    END;
END $$;

-- 7. Tombstone Consistency Constraints
-- Case A: is_deleted = TRUE but deleted_at IS NULL -> Must FAIL
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, report_payload,
            is_deleted, deleted_at, client_updated_at
        ) VALUES (
            'a0000000-0000-0000-0000-000000000001',
            'rep-a-bad-tombstone-1',
            'snap-a-003',
            '{"status": "deleted"}'::jsonb,
            TRUE,
            NULL,
            now()
        );
        RAISE EXCEPTION 'Constraint Failure: is_deleted=TRUE with NULL deleted_at was allowed!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected
    END;
END $$;

-- Case B: is_deleted = FALSE but deleted_at IS NOT NULL -> Must FAIL
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, report_payload,
            is_deleted, deleted_at, client_updated_at
        ) VALUES (
            'a0000000-0000-0000-0000-000000000001',
            'rep-a-bad-tombstone-2',
            'snap-a-004',
            '{"status": "active"}'::jsonb,
            FALSE,
            now(),
            now()
        );
        RAISE EXCEPTION 'Constraint Failure: is_deleted=FALSE with non-null deleted_at was allowed!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected
    END;
END $$;

-- Case C: Valid Tombstoning -> Must SUCCEED
UPDATE public.synced_reports
SET is_deleted = TRUE, deleted_at = now(), client_updated_at = now()
WHERE client_report_id = 'rep-a-001';

DO $$
DECLARE
    v_del BOOLEAN;
BEGIN
    SELECT is_deleted INTO v_del
    FROM public.synced_reports
    WHERE client_report_id = 'rep-a-001';

    IF v_del IS NOT TRUE THEN
        RAISE EXCEPTION 'State Failure: Tombstone update did not persist correctly.';
    END IF;
END $$;

-- 8. Scoped Uniqueness: (user_id, client_report_id) Duplicate Rejection
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, report_payload, client_updated_at
        ) VALUES (
            'a0000000-0000-0000-0000-000000000001',
            'rep-a-001', -- Already exists
            'snap-a-005',
            '{"status": "duplicate"}'::jsonb,
            now()
        );
        RAISE EXCEPTION 'Constraint Failure: Duplicate (user_id, client_report_id) was allowed!';
    EXCEPTION
        WHEN unique_violation THEN
            NULL; -- Expected
    END;
END $$;

SELECT auth.reset_test_user();

ROLLBACK;
