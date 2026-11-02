-- ==============================================================================
-- Migration: 00010_create_durable_quota_reservations.sql
-- Description: Creates the public.ai_quota_reservations table and durable reservation lifecycle functions.
-- Authorship: TrustCue Project Team (Module 64)
-- Invariants:
--   - Tracks explicit reservation identity, status ('reserved', 'committed', 'released'), and UTC date.
--   - Zero prompts, message text, evidence excerpts, tokens, or message hashes stored.
--   - Atomic allowance enforcement under row-level lock.
--   - Idempotent commit and release operations.
--   - Refunds are applied against the original reservation quota_date (even across UTC midnight rollover).
--   - Committed reservations cannot be refunded.
--   - RLS strictly enforced: authenticated users can only view their own reservations; mutations restricted to server.
-- ==============================================================================

BEGIN;

-- 1. Create ai_quota_reservations table
CREATE TABLE IF NOT EXISTS public.ai_quota_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    quota_date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('reserved', 'committed', 'released')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_ai_quota_reservations_user_date
    ON public.ai_quota_reservations (user_id, quota_date);

CREATE INDEX IF NOT EXISTS idx_ai_quota_reservations_status
    ON public.ai_quota_reservations (status);

COMMENT ON TABLE public.ai_quota_reservations IS 'Durable reservation lifecycle state for AI rate limiting.';
COMMENT ON COLUMN public.ai_quota_reservations.id IS 'Explicit unique identifier for a quota reservation.';
COMMENT ON COLUMN public.ai_quota_reservations.user_id IS 'Owner referencing auth.users(id). Cascades on deletion.';
COMMENT ON COLUMN public.ai_quota_reservations.quota_date IS 'UTC calendar date of the reservation.';
COMMENT ON COLUMN public.ai_quota_reservations.status IS 'Lifecycle state: reserved, committed, or released.';

-- 2. Enable and Force Row Level Security
ALTER TABLE public.ai_quota_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_quota_reservations FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.ai_quota_reservations FROM PUBLIC, anon;

DROP POLICY IF EXISTS "reservations_read_own" ON public.ai_quota_reservations;
CREATE POLICY "reservations_read_own"
    ON public.ai_quota_reservations FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

GRANT ALL ON public.ai_quota_reservations TO service_role, postgres;

-- 3. Atomic v2 Reservation Function with Durable Identity
CREATE OR REPLACE FUNCTION public.reserve_ai_quota_v2(
    p_user_id UUID,
    p_reservation_id UUID,
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
    -- Check if reservation ID already exists (idempotency check)
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
        user_id,
        quota_date,
        request_count,
        token_count,
        created_at,
        updated_at
    )
    VALUES (
        p_user_id,
        v_today,
        0,
        0,
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    )
    ON CONFLICT (user_id, quota_date) DO NOTHING;

    -- Atomically check and conditionally increment request_count under row lock
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
            id,
            user_id,
            quota_date,
            status,
            created_at,
            updated_at
        )
        VALUES (
            p_reservation_id,
            p_user_id,
            v_today,
            'reserved',
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
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

COMMENT ON FUNCTION public.reserve_ai_quota_v2(UUID, UUID, INT) IS
    'Atomically reserves daily AI quota with durable reservation tracking and idempotency.';

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

COMMENT ON FUNCTION public.commit_ai_quota_v2(UUID, UUID) IS
    'Idempotently commits a durable quota reservation after successful AI inference.';

-- 5. Durable Release / Refund Function (across midnight rollover)
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

    -- Decrement usage on the ORIGINAL reservation quota_date
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

COMMENT ON FUNCTION public.release_ai_quota_v2(UUID, UUID) IS
    'Idempotently refunds an unused reservation back to its original quota_date.';

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

COMMENT ON FUNCTION public.get_remaining_ai_quota(UUID, INT) IS
    'Returns remaining daily AI quota for authenticated user on the current UTC date.';

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

COMMENT ON FUNCTION public.reap_abandoned_reservations(INT) IS
    'Reaps abandoned reservations stuck in reserved status older than timeout.';

-- 8. Strict Permissions Lockdown
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
