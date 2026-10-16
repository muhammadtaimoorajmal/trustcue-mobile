-- ==============================================================================
-- Migration: 00008_harden_sync_purge_and_allowlist.sql
-- Description: Hardens cloud sync purge with generation tracking, dual auth path
--              ownership enforcement, and strict JSON schema allowlist validation.
-- Authorship: TrustCue Project Team (Module 40)
-- Invariants:
--   - Cloud report purge supports both authenticated user token and backend service-role paths.
--   - Cross-account purge is strictly prevented (authenticated users cannot purge other users).
--   - Incrementing sync_generation and recording sync_purged_at prevents resurrection of purged reports.
--   - Strict allowlist on report_payload: only formatVersion, outcomeState, hasAiAnalysis,
--     indicatorCount, categories, and source are permitted for active reports.
-- ==============================================================================

BEGIN;

-- 1. Add sync_generation and sync_purged_at to public.profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS sync_generation INT NOT NULL DEFAULT 1 CHECK (sync_generation >= 1),
    ADD COLUMN IF NOT EXISTS sync_purged_at TIMESTAMPTZ;

COMMENT ON COLUMN public.profiles.sync_generation IS 'Monotonically increasing generation counter incremented on cloud backup purge to prevent stale resurrecting uploads.';
COMMENT ON COLUMN public.profiles.sync_purged_at IS 'UTC timestamp when cloud backup was last purged.';

-- 2. Enhanced purge_synced_reports supporting service-role and user token execution paths
DROP FUNCTION IF EXISTS public.purge_synced_reports();

CREATE OR REPLACE FUNCTION public.purge_synced_reports(target_user_id UUID DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    deleted_count integer;
    effective_user_id UUID;
    caller_role text;
BEGIN
    caller_role := auth.role();

    IF caller_role = 'service_role' OR (session_user = 'postgres' AND (caller_role IS NULL OR caller_role = 'service_role')) THEN
        effective_user_id := COALESCE(target_user_id, auth.uid());
    ELSIF caller_role = 'authenticated' THEN
        effective_user_id := auth.uid();
        -- If an authenticated user explicitly supplied target_user_id, it MUST match auth.uid()
        IF target_user_id IS NOT NULL AND target_user_id <> auth.uid() THEN
            RAISE EXCEPTION 'Access denied: cannot purge cloud backups for another user';
        END IF;
    ELSE
        RAISE EXCEPTION 'Access denied: insufficient privileges to purge cloud backups';
    END IF;

    IF effective_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID must not be null for cloud backup purge';
    END IF;

    -- Delete all synced reports for this user
    DELETE FROM public.synced_reports
    WHERE user_id = effective_user_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- Update generation, record purge timestamp, and turn off sync
    UPDATE public.profiles
    SET sync_generation = sync_generation + 1,
        sync_purged_at = timezone('utc'::text, now()),
        sync_enabled = FALSE
    WHERE id = effective_user_id;

    RETURN deleted_count;
END;
$$;

COMMENT ON FUNCTION public.purge_synced_reports(UUID) IS 'Purges all cloud synced reports for the specified/calling user, increments sync_generation, and records purge timestamp.';

REVOKE ALL ON FUNCTION public.purge_synced_reports(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.purge_synced_reports(UUID) TO authenticated, service_role, postgres;

-- 3. Strict allowlist validation check on public.synced_reports payload
-- Ensures only approved summary keys exist and strictly forbids arbitrary/sensitive fields
ALTER TABLE public.synced_reports
    DROP CONSTRAINT IF EXISTS chk_report_payload_privacy;

ALTER TABLE public.synced_reports
    ADD CONSTRAINT chk_report_payload_privacy CHECK (
        (is_deleted = TRUE) OR (
            jsonb_typeof(report_payload) = 'object' AND
            (report_payload ? 'formatVersion') AND
            (report_payload ? 'outcomeState') AND
            (report_payload ? 'hasAiAnalysis') AND
            (report_payload ? 'indicatorCount') AND
            (report_payload ? 'categories') AND
            (report_payload ? 'source') AND
            NOT (report_payload ? 'text') AND
            NOT (report_payload ? 'rawText') AND
            NOT (report_payload ? 'raw_text') AND
            NOT (report_payload ? 'excerpt') AND
            NOT (report_payload ? 'evidence') AND
            NOT (report_payload ? 'screenshot') AND
            NOT (report_payload ? 'hash') AND
            NOT (report_payload ? 'ocrText') AND
            NOT (report_payload ? 'ocr_text') AND
            NOT (report_payload ? 'inputText') AND
            NOT (report_payload ? 'input_text') AND
            NOT (report_payload ? 'findings') AND
            NOT (report_payload ? 'snapshot')
        )
    );

COMMIT;
