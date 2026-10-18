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

-- 6. User A cannot observe User B's reports (RLS isolation), and User B's reports remain intact
DO $$
DECLARE
    v_b_count_seen_by_a INT;
BEGIN
    -- User A observes 0 rows for User B due to RLS
    SELECT count(*) INTO v_b_count_seen_by_a
    FROM public.synced_reports
    WHERE user_id = 'd0000000-0000-0000-0000-000000000002';

    IF v_b_count_seen_by_a <> 0 THEN
        RAISE EXCEPTION 'RLS Isolation Failure: User A was able to observe User B report (count=%)', v_b_count_seen_by_a;
    END IF;
END $$;

-- Switch to User B to confirm their report was not deleted by User A's purge
SELECT auth.set_test_user('d0000000-0000-0000-0000-000000000002'::uuid, 'authenticated');

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

-- 8. Verify that payload with extra/unapproved keys (e.g., 'body' or 'message') is REJECTED
SELECT auth.set_test_user('d0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

-- Temporarily re-enable sync for User A to test payload constraint
UPDATE public.profiles SET sync_enabled = TRUE WHERE id = 'd0000000-0000-0000-0000-000000000001';

DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, sync_generation, report_payload, client_updated_at
        ) VALUES (
            'd0000000-0000-0000-0000-000000000001',
            'rep-extra-keys-004',
            'snap-004',
            2,
            '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText", "body": "unauthorized message content"}'::jsonb,
            now() + interval '1 minute'
        );
        RAISE EXCEPTION 'Security Failure: Report with unauthorized extra key was accepted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected check violation
    END;
END $$;

-- 9. Verify that payload with invalid value types (e.g., categories as string instead of array) is REJECTED
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, sync_generation, report_payload, client_updated_at
        ) VALUES (
            'd0000000-0000-0000-0000-000000000001',
            'rep-invalid-type-005',
            'snap-005',
            2,
            '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": "not-an-array", "source": "messageText"}'::jsonb,
            now() + interval '1 minute'
        );
        RAISE EXCEPTION 'Security Failure: Report with invalid category type was accepted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected check violation
    END;
END $$;

-- 10. Verify that stale upload (client_updated_at <= sync_purged_at) is REJECTED by RLS
DO $$
DECLARE
    v_purged_at TIMESTAMPTZ;
BEGIN
    SELECT sync_purged_at INTO v_purged_at
    FROM public.profiles
    WHERE id = 'd0000000-0000-0000-0000-000000000001';

    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, sync_generation, report_payload, client_updated_at
        ) VALUES (
            'd0000000-0000-0000-0000-000000000001',
            'rep-stale-006',
            'snap-006',
            2,
            '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}'::jsonb,
            v_purged_at - interval '1 hour' -- Stale timestamp preceding purge
        );
        RAISE EXCEPTION 'Security Failure: Stale report preceding purge was accepted!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL; -- Expected RLS denial
    END;
END $$;

-- 10b. Verify that stale sync_generation (< profiles.sync_generation) is REJECTED by RLS even with fresh timestamp
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, sync_generation, report_payload, client_updated_at
        ) VALUES (
            'd0000000-0000-0000-0000-000000000001',
            'rep-stale-gen-006b',
            'snap-006b',
            1, -- Stale generation 1 while profile is generation 2
            '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}'::jsonb,
            now() + interval '5 minutes'
        );
        RAISE EXCEPTION 'Security Failure: Report with stale sync_generation was accepted!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL; -- Expected RLS denial
    END;
END $$;

-- 10c. Verify that invalid outcomeState enum value is REJECTED by check constraint
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, sync_generation, report_payload, client_updated_at
        ) VALUES (
            'd0000000-0000-0000-0000-000000000001',
            'rep-invalid-enum-outcome',
            'snap-enum-01',
            2,
            '{"formatVersion": 1, "outcomeState": "fraudulent", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}'::jsonb,
            now() + interval '1 minute'
        );
        RAISE EXCEPTION 'Security Failure: Invalid outcomeState enum was accepted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected check violation
    END;
END $$;

-- 10d. Verify that invalid source enum value is REJECTED by check constraint
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, sync_generation, report_payload, client_updated_at
        ) VALUES (
            'd0000000-0000-0000-0000-000000000001',
            'rep-invalid-enum-source',
            'snap-enum-02',
            2,
            '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "telepathy"}'::jsonb,
            now() + interval '1 minute'
        );
        RAISE EXCEPTION 'Security Failure: Invalid source enum was accepted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected check violation
    END;
END $$;

-- 10e. Verify that tombstone (is_deleted = TRUE) with forbidden sensitive key is REJECTED
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, sync_generation, report_payload, is_deleted, deleted_at, client_updated_at
        ) VALUES (
            'd0000000-0000-0000-0000-000000000001',
            'rep-tombstone-leak',
            'snap-leak-01',
            2,
            '{"formatVersion": 1, "outcomeState": "cautious", "rawText": "secret sensitive text"}'::jsonb,
            TRUE,
            now(),
            now() + interval '1 minute'
        );
        RAISE EXCEPTION 'Security Failure: Tombstone with sensitive key was accepted!';
    EXCEPTION
        WHEN check_violation THEN
            NULL; -- Expected check violation
    END;
END $$;

-- 11. Verify that a user who has opted out (sync_enabled = FALSE) CAN still tombstone an existing report
UPDATE public.profiles SET sync_enabled = FALSE WHERE id = 'd0000000-0000-0000-0000-000000000001';

-- Insert an initial record using service_role to set up the tombstone test
SELECT auth.set_test_user(NULL, 'service_role');
INSERT INTO public.synced_reports (
    user_id, client_report_id, snapshot_id, sync_generation, report_payload, is_deleted, client_updated_at
) VALUES (
    'd0000000-0000-0000-0000-000000000001',
    'rep-tombstone-007',
    'snap-007',
    2,
    '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}'::jsonb,
    FALSE,
    now() + interval '2 minutes'
);

-- Now switch back to authenticated User A and update it to tombstoned (is_deleted = TRUE)
SELECT auth.set_test_user('d0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

UPDATE public.synced_reports
SET is_deleted = TRUE,
    deleted_at = now(),
    updated_at = now()
WHERE user_id = 'd0000000-0000-0000-0000-000000000001'
  AND client_report_id = 'rep-tombstone-007';

DO $$
DECLARE
    v_is_del BOOLEAN;
BEGIN
    SELECT is_deleted INTO v_is_del
    FROM public.synced_reports
    WHERE user_id = 'd0000000-0000-0000-0000-000000000001'
      AND client_report_id = 'rep-tombstone-007';

    IF v_is_del <> TRUE THEN
        RAISE EXCEPTION 'Expected report to be marked tombstoned (is_deleted = TRUE) even when sync_enabled is FALSE';
    END IF;
END $$;

-- 12. Verify that a user who has opted out (sync_enabled = FALSE) CAN insert a fresh tombstone
DO $$
BEGIN
    INSERT INTO public.synced_reports (
        user_id, client_report_id, snapshot_id, sync_generation, report_payload, is_deleted, deleted_at, client_updated_at
    ) VALUES (
        'd0000000-0000-0000-0000-000000000001',
        'rep-optout-insert-tombstone',
        'snap-optout-01',
        2,
        '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}'::jsonb,
        TRUE,
        now(),
        now() + interval '3 minutes'
    );
END $$;

-- 13. Verify that a user who has opted out (sync_enabled = FALSE) CANNOT insert an active report
DO $$
BEGIN
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, sync_generation, report_payload, is_deleted, client_updated_at
        ) VALUES (
            'd0000000-0000-0000-0000-000000000001',
            'rep-optout-insert-active',
            'snap-optout-02',
            2,
            '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}'::jsonb,
            FALSE,
            now() + interval '4 minutes'
        );
        RAISE EXCEPTION 'Security Failure: Active report insert allowed while opted out!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            NULL; -- Expected RLS denial
    END;
END $$;

SELECT auth.reset_test_user();

ROLLBACK;

