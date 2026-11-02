-- ==============================================================================
-- TRUSTCUE CONSOLIDATED HOSTED MIGRATIONS 00009 & 00010
-- Project ID: yzqkmoqqvnhfmmrayfko
-- Target: Supabase Studio SQL Editor (https://supabase.com/dashboard/project/yzqkmoqqvnhfmmrayfko/sql/new)
-- Authorship: TrustCue Engineering Team (Module 64 & 65 Production Closure)
-- Classification: Authoritative Owner Execution Script
-- ==============================================================================
--
-- WHY OWNER EXECUTION IS REQUIRED:
-- Managed Supabase Cloud exposes an HTTP PostgREST gateway (port 443) for DML
-- operations (SELECT, INSERT, UPDATE, DELETE) and pre-existing RPC calls.
-- PostgREST explicitly forbids DDL statements (ALTER TABLE, CREATE TABLE,
-- CREATE OR REPLACE FUNCTION, CREATE POLICY). Direct database connection strings
-- (postgresql://postgres:***@db.yzqkmoqqvnhfmmrayfko.supabase.co:5432/postgres)
-- are not checked into Git repositories for credential safety.
-- Therefore, the project owner executes this idempotent script once in the
-- Supabase Studio SQL Editor.
-- ==============================================================================

-- ==============================================================================
-- SECTION A: PREFLIGHT CHECKS (Execute to observe current state)
-- ==============================================================================
-- Verify existing tables and columns:
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('profiles', 'ai_usage_quotas', 'ai_quota_reservations')
ORDER BY table_name, ordinal_position;

-- Verify existing storage buckets:
SELECT id, name, public, file_size_limit 
FROM storage.buckets 
WHERE id = 'avatars';

-- ==============================================================================
-- SECTION B: MIGRATION 00009 — AVATAR PROFILE FIELD & PRIVATE STORAGE BUCKET
-- ==============================================================================
BEGIN;

-- 1. Add avatar_path column to public.profiles if not present
ALTER TABLE public.profiles 
    ADD COLUMN IF NOT EXISTS avatar_path TEXT;

COMMENT ON COLUMN public.profiles.avatar_path IS 
    'Storage object path (avatars/{user_id}/avatar.jpg) in private avatars bucket.';

-- 2. Ensure private storage bucket 'avatars' exists with 2MB ceiling & image restrictions
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    false, -- Private bucket: access requires authenticated session or signed URL
    2097152, -- 2 MB ceiling
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- 3. Row-Level Security Policies for storage.objects
-- Rule: Users may only INSERT, SELECT, UPDATE, or DELETE objects in their own folder (avatars/<user_id>/...)
DO $$
BEGIN
    -- INSERT policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can upload own avatar'
    ) THEN
        CREATE POLICY "Users can upload own avatar"
            ON storage.objects FOR INSERT
            TO authenticated
            WITH CHECK (
                bucket_id = 'avatars' 
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;

    -- SELECT policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can view own avatar'
    ) THEN
        CREATE POLICY "Users can view own avatar"
            ON storage.objects FOR SELECT
            TO authenticated
            USING (
                bucket_id = 'avatars' 
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;

    -- UPDATE policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can update own avatar'
    ) THEN
        CREATE POLICY "Users can update own avatar"
            ON storage.objects FOR UPDATE
            TO authenticated
            USING (
                bucket_id = 'avatars' 
                AND (storage.foldername(name))[1] = auth.uid()::text
            )
            WITH CHECK (
                bucket_id = 'avatars' 
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;

    -- DELETE policy
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can delete own avatar'
    ) THEN
        CREATE POLICY "Users can delete own avatar"
            ON storage.objects FOR DELETE
            TO authenticated
            USING (
                bucket_id = 'avatars' 
                AND (storage.foldername(name))[1] = auth.uid()::text
            );
    END IF;
END $$;

COMMIT;

-- ==============================================================================
-- SECTION C: MIGRATION 00010 — DURABLE QUOTA RESERVATIONS & ATOMIC RPCS
-- ==============================================================================
BEGIN;

-- 1. Create ai_quota_reservations table
CREATE TABLE IF NOT EXISTS public.ai_quota_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    quota_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'committed', 'released')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_ai_quota_reservations_user_date
    ON public.ai_quota_reservations (user_id, quota_date);

CREATE INDEX IF NOT EXISTS idx_ai_quota_reservations_status
    ON public.ai_quota_reservations (status);

CREATE INDEX IF NOT EXISTS idx_ai_quota_reservations_timeout
    ON public.ai_quota_reservations (status, created_at);

COMMENT ON TABLE public.ai_quota_reservations IS 
    'Durable reservation lifecycle tracking for AI rate limiting without prompt persistence.';

-- 2. RLS: Authenticated users can view their own reservations; mutations restricted to server
ALTER TABLE public.ai_quota_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_quota_reservations FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.ai_quota_reservations FROM PUBLIC, anon;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'ai_quota_reservations' AND policyname = 'reservations_read_own'
    ) THEN
        CREATE POLICY "reservations_read_own"
            ON public.ai_quota_reservations FOR SELECT
            TO authenticated
            USING (auth.uid() = user_id);
    END IF;
END $$;

GRANT ALL ON public.ai_quota_reservations TO service_role, postgres;

-- 3. Atomic v2 Reservation Function
CREATE OR REPLACE FUNCTION public.reserve_ai_quota_v2(
    p_user_id UUID,
    p_reservation_id UUID DEFAULT gen_random_uuid(),
    p_max_daily_requests INT DEFAULT 15
)
RETURNS TABLE (
    allowed BOOLEAN,
    requests_used INT,
    requests_remaining INT,
    reservation_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_today DATE := (timezone('utc'::text, now()))::date;
    v_current_requests INT;
    v_existing_user UUID;
    v_existing_date DATE;
    v_existing_status TEXT;
BEGIN
    -- Idempotency check: if reservation already exists, return current state
    SELECT user_id, quota_date, status
    INTO v_existing_user, v_existing_date, v_existing_status
    FROM public.ai_quota_reservations
    WHERE id = p_reservation_id;

    IF FOUND THEN
        IF v_existing_user <> p_user_id THEN
            RAISE EXCEPTION 'Reservation belongs to another user' USING ERRCODE = '42501';
        END IF;

        SELECT request_count INTO v_current_requests
        FROM public.ai_usage_quotas
        WHERE user_id = p_user_id AND quota_date = v_existing_date;

        RETURN QUERY SELECT
            (v_existing_status IN ('reserved', 'committed')) AS allowed,
            COALESCE(v_current_requests, 0) AS requests_used,
            GREATEST(0, p_max_daily_requests - COALESCE(v_current_requests, 0)) AS requests_remaining,
            p_reservation_id AS reservation_id;
        RETURN;
    END IF;

    -- Ensure row exists for today
    INSERT INTO public.ai_usage_quotas (
        user_id, quota_date, request_count, token_count, created_at, updated_at
    )
    VALUES (
        p_user_id, v_today, 0, 0, timezone('utc'::text, now()), timezone('utc'::text, now())
    )
    ON CONFLICT (user_id, quota_date) DO NOTHING;

    -- Atomically increment under row lock
    UPDATE public.ai_usage_quotas
    SET request_count = request_count + 1,
        last_request_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE user_id = p_user_id
      AND quota_date = v_today
      AND request_count < p_max_daily_requests
    RETURNING request_count INTO v_current_requests;

    IF FOUND THEN
        INSERT INTO public.ai_quota_reservations (
            id, user_id, quota_date, status, created_at, updated_at
        )
        VALUES (
            p_reservation_id, p_user_id, v_today, 'reserved',
            timezone('utc'::text, now()), timezone('utc'::text, now())
        );

        RETURN QUERY SELECT
            TRUE AS allowed,
            v_current_requests AS requests_used,
            GREATEST(0, p_max_daily_requests - v_current_requests) AS requests_remaining,
            p_reservation_id AS reservation_id;
    ELSE
        SELECT q.request_count INTO v_current_requests
        FROM public.ai_usage_quotas q
        WHERE q.user_id = p_user_id AND q.quota_date = v_today;

        v_current_requests := COALESCE(v_current_requests, p_max_daily_requests);

        RETURN QUERY SELECT
            FALSE AS allowed,
            v_current_requests AS requests_used,
            0 AS requests_remaining,
            NULL::UUID AS reservation_id;
    END IF;
END;
$$;

-- 4. Durable Commit Function
CREATE OR REPLACE FUNCTION public.commit_ai_quota_v2(
    p_user_id UUID,
    p_reservation_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_res_user UUID;
    v_res_status TEXT;
BEGIN
    SELECT user_id, status
    INTO v_res_user, v_res_status
    FROM public.ai_quota_reservations
    WHERE id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF v_res_user <> p_user_id THEN
        RAISE EXCEPTION 'Reservation belongs to another user' USING ERRCODE = '42501';
    END IF;

    IF v_res_status = 'committed' THEN
        RETURN TRUE; -- Idempotent success
    END IF;

    IF v_res_status = 'released' THEN
        RETURN FALSE; -- Cannot commit an already released reservation
    END IF;

    UPDATE public.ai_quota_reservations
    SET status = 'committed',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_reservation_id;

    RETURN TRUE;
END;
$$;

-- 5. Durable Release / Refund Function (Original Date Preserved)
CREATE OR REPLACE FUNCTION public.release_ai_quota_v2(
    p_user_id UUID,
    p_reservation_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_res_user UUID;
    v_res_date DATE;
    v_res_status TEXT;
BEGIN
    SELECT user_id, quota_date, status
    INTO v_res_user, v_res_date, v_res_status
    FROM public.ai_quota_reservations
    WHERE id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF v_res_user <> p_user_id THEN
        RAISE EXCEPTION 'Reservation belongs to another user' USING ERRCODE = '42501';
    END IF;

    IF v_res_status = 'released' THEN
        RETURN TRUE; -- Idempotent refund
    END IF;

    IF v_res_status = 'committed' THEN
        RETURN FALSE; -- Cannot refund an already committed reservation
    END IF;

    -- Decrement usage on the ORIGINAL reservation quota_date (safe across midnight rollover)
    UPDATE public.ai_usage_quotas
    SET request_count = GREATEST(0, request_count - 1),
        updated_at = timezone('utc'::text, now())
    WHERE user_id = p_user_id
      AND quota_date = v_res_date;

    UPDATE public.ai_quota_reservations
    SET status = 'released',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_reservation_id;

    RETURN TRUE;
END;
$$;

-- 6. Read Remaining Quota Function
CREATE OR REPLACE FUNCTION public.get_remaining_ai_quota(
    p_user_id UUID,
    p_max_daily_requests INT DEFAULT 15
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_today DATE := (timezone('utc'::text, now()))::date;
    v_current_requests INT;
BEGIN
    SELECT request_count INTO v_current_requests
    FROM public.ai_usage_quotas
    WHERE user_id = p_user_id AND quota_date = v_today;

    RETURN GREATEST(0, p_max_daily_requests - COALESCE(v_current_requests, 0));
END;
$$;

-- 7. Reap Abandoned Reservations Function
CREATE OR REPLACE FUNCTION public.reap_abandoned_reservations(
    p_timeout_seconds INT DEFAULT 600
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    r RECORD;
    v_reaped INT := 0;
BEGIN
    FOR r IN
        SELECT id, user_id, quota_date
        FROM public.ai_quota_reservations
        WHERE status = 'reserved'
          AND created_at < timezone('utc'::text, now()) - (p_timeout_seconds || ' seconds')::INTERVAL
        FOR UPDATE SKIP LOCKED
    LOOP
        UPDATE public.ai_usage_quotas
        SET request_count = GREATEST(0, request_count - 1),
            updated_at = timezone('utc'::text, now())
        WHERE user_id = r.user_id AND quota_date = r.quota_date;

        UPDATE public.ai_quota_reservations
        SET status = 'released',
            updated_at = timezone('utc'::text, now())
        WHERE id = r.id;

        v_reaped := v_reaped + 1;
    END LOOP;

    RETURN v_reaped;
END;
$$;

-- 8. Security Lockdown
REVOKE ALL ON FUNCTION public.reserve_ai_quota_v2(UUID, UUID, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.commit_ai_quota_v2(UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_ai_quota_v2(UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_remaining_ai_quota(UUID, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reap_abandoned_reservations(INT) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.reserve_ai_quota_v2(UUID, UUID, INT) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.commit_ai_quota_v2(UUID, UUID) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.release_ai_quota_v2(UUID, UUID) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.get_remaining_ai_quota(UUID, INT) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.reap_abandoned_reservations(INT) TO service_role, postgres;

COMMIT;

-- ==============================================================================
-- SECTION D: AUTOMATED CLEANUP SCHEDULE (pg_cron)
-- ==============================================================================
-- If pg_cron extension is available on the Supabase project:
-- Uncomment and run the following line to automatically reap abandoned reservations every 10 minutes:
--
-- SELECT cron.schedule(
--     'reap-abandoned-ai-reservations',
--     '*/10 * * * *',
--     'SELECT public.reap_abandoned_reservations(600);'
-- );

-- ==============================================================================
-- SECTION E: POST-APPLICATION VERIFICATION QUERIES
-- ==============================================================================
-- 1. Confirm avatar_path column exists:
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name = 'avatar_path';

-- 2. Confirm ai_quota_reservations table exists:
SELECT table_name, column_name 
FROM information_schema.columns 
WHERE table_name = 'ai_quota_reservations';

-- 3. Confirm all 5 functions exist:
SELECT proname, prorettype::regtype 
FROM pg_proc 
WHERE proname IN (
    'reserve_ai_quota_v2', 
    'commit_ai_quota_v2', 
    'release_ai_quota_v2', 
    'get_remaining_ai_quota', 
    'reap_abandoned_reservations'
);
