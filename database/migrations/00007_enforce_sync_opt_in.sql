-- ==============================================================================
-- Migration: 00007_enforce_sync_opt_in.sql
-- Description: Enforces profile sync_enabled opt-in requirement on report writes,
--              adds database-level payload privacy checks, and provides cloud purge RPC.
-- Authorship: TrustCue Project Team (Module 39)
-- Invariants:
--   - Writes (INSERT/UPDATE) to public.synced_reports are strictly rejected unless
--     the authenticated user has explicitly opted into cloud sync (profiles.sync_enabled = true).
--   - Payloads cannot contain raw message text, raw excerpts, screenshots, or content hashes.
--   - Authenticated users can purge all their cloud synced reports via purge_synced_reports().
--   - Fast delta query index on (user_id, client_updated_at).
-- ==============================================================================

BEGIN;

-- 1. Database-level privacy constraint on synced_reports payload
-- Ensures no raw text, excerpts, screenshots, or hash fields can ever be stored in the cloud
ALTER TABLE public.synced_reports
    DROP CONSTRAINT IF EXISTS chk_report_payload_privacy;

ALTER TABLE public.synced_reports
    ADD CONSTRAINT chk_report_payload_privacy CHECK (
        NOT (report_payload ? 'text') AND
        NOT (report_payload ? 'rawText') AND
        NOT (report_payload ? 'raw_text') AND
        NOT (report_payload ? 'excerpt') AND
        NOT (report_payload ? 'evidence') AND
        NOT (report_payload ? 'screenshot') AND
        NOT (report_payload ? 'hash')
    );

-- 2. Enforce sync_enabled opt-in check in Row Level Security policies
DROP POLICY IF EXISTS "reports_insert_own" ON public.synced_reports;
CREATE POLICY "reports_insert_own"
    ON public.synced_reports FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE public.profiles.id = auth.uid()
            AND public.profiles.sync_enabled = TRUE
        )
    );

DROP POLICY IF EXISTS "reports_update_own" ON public.synced_reports;
CREATE POLICY "reports_update_own"
    ON public.synced_reports FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE public.profiles.id = auth.uid()
            AND public.profiles.sync_enabled = TRUE
        )
    );

-- 3. Delta index for client sync queries
CREATE INDEX IF NOT EXISTS idx_synced_reports_delta
    ON public.synced_reports (user_id, client_updated_at ASC);

-- 4. Purge RPC for clearing cloud backups when disabling sync
CREATE OR REPLACE FUNCTION public.purge_synced_reports()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    deleted_count integer;
BEGIN
    DELETE FROM public.synced_reports
    WHERE user_id = auth.uid();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

COMMENT ON FUNCTION public.purge_synced_reports() IS 'Purges all cloud synced reports for the calling authenticated user.';

REVOKE ALL ON FUNCTION public.purge_synced_reports() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.purge_synced_reports() TO authenticated, service_role, postgres;

COMMIT;
