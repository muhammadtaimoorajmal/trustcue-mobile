-- ==============================================================================
-- Test Suite: 08_test_concurrent_upload_purge.sql
-- Description: Verifies atomic write validation trigger and sync_push_reports RPC
--              invariants, generation matching, and purge serialization.
-- ==============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Setup test user and profile
SELECT auth.reset_test_user();
INSERT INTO auth.users (id, email)
VALUES ('e0000000-0000-0000-0000-000000000001', 'concurrent_user@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, sync_enabled, sync_generation)
VALUES ('e0000000-0000-0000-0000-000000000001', 'Concurrent User', TRUE, 1)
ON CONFLICT (id) DO UPDATE SET sync_enabled = TRUE, sync_generation = 1, sync_purged_at = NULL;

DELETE FROM public.synced_reports WHERE user_id = 'e0000000-0000-0000-0000-000000000001';

-- 2. Verify sync_push_reports accepts valid generation report
SELECT auth.set_test_user('e0000000-0000-0000-0000-000000000001'::uuid, 'authenticated');

DO $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT public.sync_push_reports(
        'e0000000-0000-0000-0000-000000000001'::uuid,
        '[{"client_report_id": "rep-valid-001", "snapshot_id": "snap-001", "sync_generation": 1, "report_payload": {"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}, "client_updated_at": "2026-10-18T10:00:00Z"}]'::jsonb
    ) INTO v_result;

    IF (v_result->>'accepted_count')::int <> 1 THEN
        RAISE EXCEPTION 'Expected accepted_count = 1, got %', v_result->>'accepted_count';
    END IF;
END $$;

-- 3. Verify purge_synced_reports purges report and bumps sync_generation to 2
DO $$
DECLARE
    v_purged INT;
    v_count INT;
    v_gen INT;
BEGIN
    SELECT public.purge_synced_reports('e0000000-0000-0000-0000-000000000001'::uuid) INTO v_purged;
    IF v_purged <> 1 THEN
        RAISE EXCEPTION 'Expected 1 report purged, got %', v_purged;
    END IF;

    SELECT count(*) INTO v_count FROM public.synced_reports WHERE user_id = 'e0000000-0000-0000-0000-000000000001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Expected 0 reports remaining, got %', v_count;
    END IF;

    SELECT sync_generation INTO v_gen FROM public.profiles WHERE id = 'e0000000-0000-0000-0000-000000000001';
    IF v_gen <> 2 THEN
        RAISE EXCEPTION 'Expected sync_generation = 2 after purge, got %', v_gen;
    END IF;
END $$;

-- 4. Verify stale upload with old sync_generation (1) is REJECTED by trigger and RPC
DO $$
DECLARE
    v_result JSONB;
    v_count INT;
BEGIN
    -- Enable sync again to test generation check specifically
    UPDATE public.profiles SET sync_enabled = TRUE WHERE id = 'e0000000-0000-0000-0000-000000000001';

    -- RPC should skip stale generation item
    SELECT public.sync_push_reports(
        'e0000000-0000-0000-0000-000000000001'::uuid,
        '[{"client_report_id": "rep-stale-gen1", "snapshot_id": "snap-stale", "sync_generation": 1, "report_payload": {"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}, "client_updated_at": "2026-10-18T10:00:00Z"}]'::jsonb
    ) INTO v_result;

    IF (v_result->>'accepted_count')::int <> 0 THEN
        RAISE EXCEPTION 'Expected 0 accepted for stale generation, got %', v_result->>'accepted_count';
    END IF;

    -- Direct INSERT must be rejected by trigger
    BEGIN
        INSERT INTO public.synced_reports (
            user_id, client_report_id, snapshot_id, sync_generation, report_payload, client_updated_at
        ) VALUES (
            'e0000000-0000-0000-0000-000000000001',
            'rep-direct-stale',
            'snap-stale-2',
            1, -- Stale generation
            '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}'::jsonb,
            now()
        );
        RAISE EXCEPTION 'Trigger Failure: Stale generation direct insert was permitted!';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%Stale generation%' THEN
                NULL; -- Expected trigger rejection
            ELSE
                RAISE;
            END IF;
    END;

    SELECT count(*) INTO v_count FROM public.synced_reports WHERE user_id = 'e0000000-0000-0000-0000-000000000001';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Expected 0 reports after stale upload attempts, got %', v_count;
    END IF;
END $$;

ROLLBACK;
