-- ==============================================================================
-- Test Suite: 04_test_cascade_deletion.sql
-- Description: Verifies that deleting an auth.users record strictly cascades
--              and eliminates all child records in profiles, ai_usage_quotas,
--              and synced_reports without leaving orphan records.
-- ==============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Setup isolated test user in auth.users
SELECT auth.reset_test_user();
INSERT INTO auth.users (id, email)
VALUES ('c0000000-0000-0000-0000-000000000003', 'cascade_test@test.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Populate records in all dependent tables
-- Public profiles (handle_new_user trigger may have already created profile)
INSERT INTO public.profiles (id, display_name, terms_version, sync_enabled)
VALUES ('c0000000-0000-0000-0000-000000000003', 'Cascade Target', '1.0.0', TRUE)
ON CONFLICT (id) DO UPDATE SET display_name = 'Cascade Target', sync_enabled = EXCLUDED.sync_enabled;

-- AI Usage Quotas
INSERT INTO public.ai_usage_quotas (user_id, quota_date, request_count, token_count)
VALUES ('c0000000-0000-0000-0000-000000000003', CURRENT_DATE, 5, 1200);

-- Synced Reports
INSERT INTO public.synced_reports (
    user_id, client_report_id, snapshot_id, schema_version, revision,
    report_payload, client_updated_at
) VALUES (
    'c0000000-0000-0000-0000-000000000003',
    'rep-cascade-001',
    'snap-cascade-001',
    1,
    1,
    '{"formatVersion": 1, "outcomeState": "cautious", "hasAiAnalysis": false, "indicatorCount": 0, "categories": [], "source": "messageText"}'::jsonb,
    now()
);

-- 3. Assert all 3 child records exist prior to deletion
DO $$
DECLARE
    v_prof_count INT;
    v_quota_count INT;
    v_rep_count INT;
BEGIN
    SELECT count(*) INTO v_prof_count FROM public.profiles WHERE id = 'c0000000-0000-0000-0000-000000000003';
    SELECT count(*) INTO v_quota_count FROM public.ai_usage_quotas WHERE user_id = 'c0000000-0000-0000-0000-000000000003';
    SELECT count(*) INTO v_rep_count FROM public.synced_reports WHERE user_id = 'c0000000-0000-0000-0000-000000000003';

    IF v_prof_count <> 1 OR v_quota_count <> 1 OR v_rep_count <> 1 THEN
        RAISE EXCEPTION 'Setup Failure: Child records were not properly populated before cascade test.';
    END IF;
END $$;

-- 4. Delete the parent record from auth.users
DELETE FROM auth.users WHERE id = 'c0000000-0000-0000-0000-000000000003';

-- 5. Verify complete cascade to all tables (zero orphan rows)
DO $$
DECLARE
    v_prof_count INT;
    v_quota_count INT;
    v_rep_count INT;
BEGIN
    SELECT count(*) INTO v_prof_count FROM public.profiles WHERE id = 'c0000000-0000-0000-0000-000000000003';
    SELECT count(*) INTO v_quota_count FROM public.ai_usage_quotas WHERE user_id = 'c0000000-0000-0000-0000-000000000003';
    SELECT count(*) INTO v_rep_count FROM public.synced_reports WHERE user_id = 'c0000000-0000-0000-0000-000000000003';

    IF v_prof_count <> 0 THEN
        RAISE EXCEPTION 'Cascade Failure: public.profiles still has % orphan rows.', v_prof_count;
    END IF;

    IF v_quota_count <> 0 THEN
        RAISE EXCEPTION 'Cascade Failure: public.ai_usage_quotas still has % orphan rows.', v_quota_count;
    END IF;

    IF v_rep_count <> 0 THEN
        RAISE EXCEPTION 'Cascade Failure: public.synced_reports still has % orphan rows.', v_rep_count;
    END IF;
END $$;

SELECT auth.reset_test_user();

ROLLBACK;
