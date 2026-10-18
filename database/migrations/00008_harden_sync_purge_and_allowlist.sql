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

-- 1b. Add sync_generation to public.synced_reports
ALTER TABLE public.synced_reports
    ADD COLUMN IF NOT EXISTS sync_generation INT NOT NULL DEFAULT 1 CHECK (sync_generation >= 1);

COMMENT ON COLUMN public.synced_reports.sync_generation IS 'Client synchronization generation counter to ensure consistency with user profile generation.';

-- 2. Enhanced purge_synced_reports supporting service-role and user token execution paths
DROP FUNCTION IF EXISTS public.purge_synced_reports();
DROP FUNCTION IF EXISTS public.purge_synced_reports(UUID);

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

    -- Acquire exclusive row-level write lock on user's profile to serialize concurrent uploads/purges
    PERFORM 1 FROM public.profiles WHERE id = effective_user_id FOR UPDATE;

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

-- 3. Strict allowlist and type validation check on public.synced_reports payload
-- Ensures ONLY approved summary keys exist with valid types and strictly forbids arbitrary/sensitive fields, even on tombstones
ALTER TABLE public.synced_reports
    DROP CONSTRAINT IF EXISTS chk_report_payload_privacy;

ALTER TABLE public.synced_reports
    ADD CONSTRAINT chk_report_payload_privacy CHECK (
        (
            jsonb_typeof(report_payload) = 'object' AND
            ((report_payload - ARRAY['formatVersion', 'outcomeState', 'hasAiAnalysis', 'indicatorCount', 'categories', 'source']) = '{}'::jsonb) AND
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
            NOT (report_payload ? 'snapshot') AND
            ((NOT (report_payload ? 'formatVersion')) OR (jsonb_typeof(report_payload->'formatVersion') = 'number' AND ((report_payload->>'formatVersion')::int BETWEEN 1 AND 10))) AND
            ((NOT (report_payload ? 'outcomeState')) OR (jsonb_typeof(report_payload->'outcomeState') = 'string' AND ((report_payload->>'outcomeState') IN ('indicatorsDetected', 'noIndicatorsMatched', 'limitedCoverage', 'cautious')))) AND
            ((NOT (report_payload ? 'hasAiAnalysis')) OR (jsonb_typeof(report_payload->'hasAiAnalysis') = 'boolean')) AND
            ((NOT (report_payload ? 'indicatorCount')) OR (jsonb_typeof(report_payload->'indicatorCount') = 'number' AND ((report_payload->>'indicatorCount')::int BETWEEN 0 AND 1000))) AND
            ((NOT (report_payload ? 'categories')) OR (jsonb_typeof(report_payload->'categories') = 'array' AND jsonb_array_length(report_payload->'categories') <= 50 AND (report_payload->'categories') <@ '["urgency_or_pressure", "requests_for_credentials", "requests_for_verification_codes", "requests_for_payment", "account_suspension_or_threats", "claimed_identity_or_impersonation", "rewards_or_prizes", "job_or_recruitment_offers", "investment_or_return_promises", "link_structural_indicators"]'::jsonb)) AND
            ((NOT (report_payload ? 'source')) OR (jsonb_typeof(report_payload->'source') = 'string' AND ((report_payload->>'source') IN ('messageText', 'screenshot', 'link', 'qrCode')))) AND
            (
                (is_deleted = TRUE) OR (
                    (report_payload ? 'formatVersion') AND
                    (report_payload ? 'outcomeState') AND
                    (report_payload ? 'hasAiAnalysis') AND
                    (report_payload ? 'indicatorCount') AND
                    (report_payload ? 'categories') AND
                    (report_payload ? 'source')
                )
            )
        ) IS TRUE
    );

-- 4. Harden RLS policies against stale generation resurrection and allow deletion when opted out
DROP POLICY IF EXISTS "reports_select_own" ON public.synced_reports;
CREATE POLICY "reports_select_own"
    ON public.synced_reports FOR SELECT
    TO authenticated
    USING (auth.uid() = public.synced_reports.user_id);

DROP POLICY IF EXISTS "reports_insert_own" ON public.synced_reports;
CREATE POLICY "reports_insert_own"
    ON public.synced_reports FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = public.synced_reports.user_id AND
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE public.profiles.id = auth.uid()
            AND (
                -- Opt-out tombstoning: allow inserting a tombstone even if sync_enabled is false
                public.synced_reports.is_deleted = TRUE
                OR
                -- Active report insert requires sync_enabled = true
                public.profiles.sync_enabled = TRUE
            )
            AND public.synced_reports.sync_generation = public.profiles.sync_generation
            AND (public.profiles.sync_purged_at IS NULL OR public.synced_reports.client_updated_at > public.profiles.sync_purged_at)
        )
    );

DROP POLICY IF EXISTS "reports_update_own" ON public.synced_reports;
CREATE POLICY "reports_update_own"
    ON public.synced_reports FOR UPDATE
    TO authenticated
    USING (auth.uid() = public.synced_reports.user_id)
    WITH CHECK (
        auth.uid() = public.synced_reports.user_id AND
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE public.profiles.id = auth.uid()
            AND (
                -- Deleting/tombstoning is permitted even when opted out of cloud sync
                public.synced_reports.is_deleted = TRUE
                OR
                -- Active report updates require sync_enabled = TRUE
                public.profiles.sync_enabled = TRUE
            )
            AND public.synced_reports.sync_generation = public.profiles.sync_generation
            AND (public.profiles.sync_purged_at IS NULL OR public.synced_reports.client_updated_at > public.profiles.sync_purged_at)
        )
    );

DROP POLICY IF EXISTS "reports_delete_own" ON public.synced_reports;
CREATE POLICY "reports_delete_own"
    ON public.synced_reports FOR DELETE
    TO authenticated
    USING (auth.uid() = public.synced_reports.user_id);

-- 5. Atomic write validation trigger with profile FOR SHARE row lock
-- Enforces concurrency protection against purge races for ALL write paths (direct client RLS and service-role)
CREATE OR REPLACE FUNCTION public.fn_validate_synced_report_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_profile_gen INT;
    v_sync_enabled BOOLEAN;
    v_purged_at TIMESTAMPTZ;
BEGIN
    -- 1. Synchronize with concurrent purge: acquire FOR SHARE lock on user profile.
    -- This blocks if a purge is currently in progress (FOR UPDATE), and forces any concurrent purge
    -- to wait until this write transaction commits.
    SELECT sync_generation, sync_enabled, sync_purged_at
    INTO v_profile_gen, v_sync_enabled, v_purged_at
    FROM public.profiles
    WHERE id = NEW.user_id
    FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found for ID %', NEW.user_id;
    END IF;

    -- 2. Invariant A: Active reports require sync_enabled = true on the profile (tombstones permitted when opted out)
    IF NOT NEW.is_deleted AND NOT v_sync_enabled THEN
        RAISE EXCEPTION 'Sync opt-in required: profile sync_enabled must be true to write active reports';
    END IF;

    -- 3. Invariant B: sync_generation must match the profile current generation
    IF NEW.sync_generation <> v_profile_gen THEN
        RAISE EXCEPTION 'Stale generation: report sync_generation (%) does not match profile sync_generation (%)',
            NEW.sync_generation, v_profile_gen;
    END IF;

    -- 4. Invariant C: client_updated_at must strictly postdate sync_purged_at
    IF v_purged_at IS NOT NULL AND NEW.client_updated_at <= v_purged_at THEN
        RAISE EXCEPTION 'Stale timestamp: report client_updated_at (%) precedes or equals last cloud purge (%)',
            NEW.client_updated_at, v_purged_at;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_validate_synced_report_write() IS 'Validates report writes under a profile FOR SHARE lock, preventing check-then-write races with cloud purge.';

DROP TRIGGER IF EXISTS tr_validate_synced_report_write ON public.synced_reports;
CREATE TRIGGER tr_validate_synced_report_write
    BEFORE INSERT OR UPDATE ON public.synced_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_validate_synced_report_write();

-- 6. Atomic batch upload RPC function
CREATE OR REPLACE FUNCTION public.sync_push_reports(
    target_user_id UUID DEFAULT NULL,
    reports JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    caller_role text;
    effective_user_id UUID;
    v_profile_gen INT;
    v_sync_enabled BOOLEAN;
    v_purged_at TIMESTAMPTZ;
    v_item JSONB;
    v_accepted_count INT := 0;
    v_synced_ids TEXT[] := ARRAY[]::TEXT[];
    v_client_report_id TEXT;
    v_snapshot_id TEXT;
    v_schema_version INT;
    v_revision INT;
    v_item_gen INT;
    v_report_payload JSONB;
    v_is_deleted BOOLEAN;
    v_deleted_at TIMESTAMPTZ;
    v_client_updated_at TIMESTAMPTZ;
BEGIN
    caller_role := auth.role();

    IF caller_role = 'service_role' OR (session_user = 'postgres' AND (caller_role IS NULL OR caller_role = 'service_role')) THEN
        effective_user_id := COALESCE(target_user_id, auth.uid());
    ELSIF caller_role = 'authenticated' THEN
        effective_user_id := auth.uid();
        IF target_user_id IS NOT NULL AND target_user_id <> auth.uid() THEN
            RAISE EXCEPTION 'Access denied: cannot push reports for another user';
        END IF;
    ELSE
        RAISE EXCEPTION 'Access denied: insufficient privileges to push synced reports';
    END IF;

    IF effective_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID must not be null for cloud report push';
    END IF;

    -- Synchronize with concurrent purge: acquire FOR SHARE lock on user profile
    SELECT sync_generation, sync_enabled, sync_purged_at
    INTO v_profile_gen, v_sync_enabled, v_purged_at
    FROM public.profiles
    WHERE id = effective_user_id
    FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found for ID %', effective_user_id;
    END IF;

    IF jsonb_typeof(reports) <> 'array' THEN
        RAISE EXCEPTION 'Reports payload must be a JSON array';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(reports)
    LOOP
        v_client_report_id := v_item->>'client_report_id';
        v_snapshot_id := v_item->>'snapshot_id';
        v_schema_version := COALESCE((v_item->>'schema_version')::int, 1);
        v_revision := COALESCE((v_item->>'revision')::int, 1);
        v_item_gen := COALESCE((v_item->>'sync_generation')::int, 1);
        v_report_payload := v_item->'report_payload';
        v_is_deleted := COALESCE((v_item->>'is_deleted')::boolean, FALSE);
        v_deleted_at := (v_item->>'deleted_at')::timestamptz;
        v_client_updated_at := (v_item->>'client_updated_at')::timestamptz;

        -- Invariant A: Active reports require sync_enabled = true
        IF NOT v_is_deleted AND NOT v_sync_enabled THEN
            CONTINUE;
        END IF;

        -- Invariant B: sync_generation must match current profile generation
        IF v_item_gen <> v_profile_gen THEN
            CONTINUE;
        END IF;

        -- Invariant C: client_updated_at must strictly postdate last purge
        IF v_purged_at IS NOT NULL AND v_client_updated_at <= v_purged_at THEN
            CONTINUE;
        END IF;

        INSERT INTO public.synced_reports (
            user_id,
            client_report_id,
            snapshot_id,
            schema_version,
            revision,
            sync_generation,
            report_payload,
            is_deleted,
            deleted_at,
            client_updated_at,
            updated_at
        ) VALUES (
            effective_user_id,
            v_client_report_id,
            v_snapshot_id,
            v_schema_version,
            v_revision,
            v_item_gen,
            v_report_payload,
            v_is_deleted,
            v_deleted_at,
            v_client_updated_at,
            timezone('utc'::text, now())
        )
        ON CONFLICT (user_id, client_report_id) DO UPDATE SET
            snapshot_id = EXCLUDED.snapshot_id,
            schema_version = EXCLUDED.schema_version,
            revision = EXCLUDED.revision,
            sync_generation = EXCLUDED.sync_generation,
            report_payload = EXCLUDED.report_payload,
            is_deleted = EXCLUDED.is_deleted,
            deleted_at = EXCLUDED.deleted_at,
            client_updated_at = EXCLUDED.client_updated_at,
            updated_at = timezone('utc'::text, now())
        WHERE public.synced_reports.client_updated_at <= EXCLUDED.client_updated_at;

        v_accepted_count := v_accepted_count + 1;
        v_synced_ids := array_append(v_synced_ids, v_client_report_id);
    END LOOP;

    RETURN jsonb_build_object(
        'accepted_count', v_accepted_count,
        'synced_ids', to_jsonb(v_synced_ids),
        'server_timestamp', timezone('utc'::text, now())
    );
END;
$$;

COMMENT ON FUNCTION public.sync_push_reports(UUID, JSONB) IS 'Atomically validates profile generation and inserts/upserts report summaries under a profile FOR SHARE lock to serialize with purge.';

REVOKE ALL ON FUNCTION public.sync_push_reports(UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_push_reports(UUID, JSONB) TO authenticated, service_role, postgres;

COMMIT;
