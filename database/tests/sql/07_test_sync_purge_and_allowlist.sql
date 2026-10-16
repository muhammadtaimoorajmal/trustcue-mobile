-- ==============================================================================
-- Test Suite: 07_test_sync_purge_and_allowlist.sql
-- Description: Tests for Module 40 sync generation increment on purge, dual auth
--              path execution, and strict JSON allowlist validation.
-- ==============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Setup test users and profiles
SELECT auth.reset_test_user();
INSERT INTO auth.users (id, email)
VALUES
    ('d0000000-0000-0000-0000-000000000001', 'user_a@test.com'),
    ('d0000000-0000-0000-0000-000000000002', 'user_b@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, sync_enabled, sync_generation)
VALUES
    ('d0000000-0000-0000-0000-000000000001', 'User A', TRUE, 1),
    ('d0000000-0000-0000-0000-000000000002', 'User B', TRUE, 1)
ON CONFLICT (id) DO UPDATE SET sync_enabled = EXCLUDED.sync_enabled, sync_generation = EXCLUDED.sync_generation;

-- 2. Insert valid allowlisted reports for User A and User B
SELECT auth.set_test_user('d0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

INSERT INTO public.synced_reports (
    user_id, client_report_id, snapshot_id, report_payload, client_updated_at
) VALUES (
    'd0000000-0000-0000-0000-000000000001',
    'rep-allow-001',
    'snap-001',
    '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 1, "categories": ["urgency"], "source": "messageText"}'::jsonb,
    now()
);

SELECT auth.set_test_user('d0000000-0000-0000-0000-000000000002'::uuid, 'authenticated');

INSERT INTO public.synced_reports (
    user_id, client_report_id, snapshot_id, report_payload, client_updated_at
) VALUES (
    'd0000000-0000-0000-0000-000000000002',
    'rep-allow-002',
    'snap-002',
    '{"formatVersion": 1, "outcomeState": "indicatorsDetected", "hasAiAnalysis": true, "indicatorCount": 2, "categories": ["urgency", "credentialRequest"], "source": "screenshot"}'::jsonb,
    now()
);

-- 3. Verify that non-allowlisted / missing-key active report is REJECTED
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, report_payload, client_updated_at
        ) VALUES (
            'd0000000-0000-0000-0000-000000000002',
            'rep-invalid-003',
            'snap-003',
            '{"formatVersion": 1, "outcomeState": "cautious"}'::jsonb, -- missing hasAiAnalysis, indicatorCount, categories, source
            now()
        );
        RAISE EXCEPTION 'Constraint Failure: Report missing required allowlist keys was accepted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected check violation
    END;
END $$;

-- 4. Verify User A CANNOT purge User B's cloud reports
SELECT auth.set_test_user('d0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

DO $$
BEGIN
    BEGIN
        PERFORM public.purge_synced_reports('d0000000-0000-0000-0000-000000000002'::uuid);
        RAISE EXCEPTION 'Security Failure: User A was able to call purge on User B!';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%Access denied: cannot purge cloud backups for another user%' THEN
                NULL; -- Expected cross-user purge denial
            ELSE
                RAISE;
            END IF;
    END;
END $$;

-- 5. User A purges their own reports -> verify count, generation increment, and sync_enabled = FALSE
DO $$
DECLARE
    v_purged INT;
    v_gen INT;
    v_sync_enabled BOOLEAN;
    v_purged_at TIMESTAMPTZ;
BEGIN
    SELECT public.purge_synced_reports() INTO v_purged;
    IF v_purged <> 1 THEN
        RAISE EXCEPTION 'Expected 1 report purged for User A, got %', v_purged;
    END IF;

    SELECT sync_generation, sync_enabled, sync_purged_at
    INTO v_gen, v_sync_enabled, v_purged_at
    FROM public.profiles
    WHERE id = 'd0000000-0000-0000-0000-000000000001';

    IF v_gen <> 2 THEN
        RAISE EXCEPTION 'Expected sync_generation to be 2, got %', v_gen;
    END IF;

    IF v_sync_enabled <> FALSE THEN
        RAISE EXCEPTION 'Expected sync_enabled to be FALSE after purge, got %', v_sync_enabled;
    END IF;

    IF v_purged_at IS NULL THEN
        RAISE EXCEPTION 'Expected sync_purged_at to be populated';
    END IF;
END $$;

-- 6. User B's reports remain intact
DO $$
DECLARE
    v_b_count INT;
BEGIN
    SELECT count(*) INTO v_b_count
    FROM public.synced_reports
    WHERE user_id = 'd0000000-0000-0000-0000-000000000002';

    IF v_b_count <> 1 THEN
        RAISE EXCEPTION 'Expected User B to still have 1 report, got %', v_b_count;
    END IF;
END $$;

-- 7. Service Role Purge for User B
SELECT auth.set_test_user(NULL, 'service_role');

DO $$
DECLARE
    v_purged INT;
    v_gen INT;
    v_b_remaining INT;
BEGIN
    SELECT public.purge_synced_reports('d0000000-0000-0000-0000-000000000002'::uuid) INTO v_purged;
    IF v_purged <> 1 THEN
        RAISE EXCEPTION 'Expected 1 report purged for User B via service_role, got %', v_purged;
    END IF;

    SELECT sync_generation INTO v_gen
    FROM public.profiles
    WHERE id = 'd0000000-0000-0000-0000-000000000002';

    IF v_gen <> 2 THEN
        RAISE EXCEPTION 'Expected User B sync_generation to be 2 after service_role purge, got %', v_gen;
    END IF;

    SELECT count(*) INTO v_b_remaining
    FROM public.synced_reports
    WHERE user_id = 'd0000000-0000-0000-0000-000000000002';

    IF v_b_remaining <> 0 THEN
        RAISE EXCEPTION 'Expected 0 reports remaining for User B, got %', v_b_remaining;
    END IF;
END $$;

SELECT auth.reset_test_user();

ROLLBACK;
