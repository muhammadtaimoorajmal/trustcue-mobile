-- ==============================================================================
-- Test Suite: 06_test_sync_opt_in_rls.sql
-- Description: Tests for Module 39 sync opt-in enforcement, payload privacy
--              constraints, and purge_synced_reports() RPC.
-- ==============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Setup test users and profiles
SELECT auth.reset_test_user();
INSERT INTO auth.users (id, email)
VALUES
    ('c0000000-0000-0000-0000-000000000001', 'user_sync_off@test.com'),
    ('c0000000-0000-0000-0000-000000000002', 'user_sync_on@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, sync_enabled)
VALUES
    ('c0000000-0000-0000-0000-000000000001', 'Sync Disabled User', FALSE),
    ('c0000000-0000-0000-0000-000000000002', 'Sync Enabled User', TRUE)
ON CONFLICT (id) DO UPDATE SET sync_enabled = EXCLUDED.sync_enabled;

-- 2. Verify User with sync_enabled = FALSE is REJECTED on report insert
SELECT auth.set_test_user('c0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, report_payload, client_updated_at
        ) VALUES (
            'c0000000-0000-0000-0000-000000000001',
            'rep-denied-001',
            'snap-001',
            '{"formatVersion": 1, "outcomeState": "suspicious", "hasAiAnalysis": false}'::jsonb,
            now()
        );
        RAISE EXCEPTION 'RLS Failure: User with sync_enabled=false was permitted to insert a report!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL; -- Expected RLS denial
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%violates row-level security policy%' THEN
                NULL; -- Expected
            ELSE
                RAISE;
            END IF;
    END;
END $$;

-- 3. Verify User with sync_enabled = TRUE CAN INSERT clean summary report
SELECT auth.set_test_user('c0000000-0000-0000-0000-000000000002'::uuid, 'authenticated');

INSERT INTO public.synced_reports (
    user_id, client_report_id, snapshot_id, report_payload, client_updated_at
) VALUES (
    'c0000000-0000-0000-0000-000000000002',
    'rep-allowed-001',
    'snap-002',
    '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": true, "indicatorCount": 2, "categories": ["urgency"], "source": "messageText"}'::jsonb,
    now()
);

-- 4. Verify Payload Privacy Constraint Rejects Raw Text / Excerpt
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, report_payload, client_updated_at
        ) VALUES (
            'c0000000-0000-0000-0000-000000000002',
            'rep-leak-001',
            'snap-003',
            '{"formatVersion": 1, "text": "Your account has been suspended", "outcomeState": "suspicious"}'::jsonb,
            now()
        );
        RAISE EXCEPTION 'Privacy Failure: Synced report with raw text was permitted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected check constraint failure
    END;
END $$;

-- 5. Verify purge_synced_reports() purges records for caller
DO $$
DECLARE
    v_purged INT;
    v_remaining INT;
BEGIN
    SELECT public.purge_synced_reports() INTO v_purged;
    IF v_purged <> 1 THEN
        RAISE EXCEPTION 'Expected 1 report purged, got %', v_purged;
    END IF;

    SELECT count(*) INTO v_remaining
    FROM public.synced_reports
    WHERE user_id = 'c0000000-0000-0000-0000-000000000002';

    IF v_remaining <> 0 THEN
        RAISE EXCEPTION 'Expected 0 reports remaining after purge, got %', v_remaining;
    END IF;
END $$;

ROLLBACK;
