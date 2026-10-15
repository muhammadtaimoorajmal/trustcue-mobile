-- ==============================================================================
-- Migration: 00006_create_quota_reservation.sql
-- Description: Creates server-side atomic quota reservation and profile recovery functions.
-- Authorship: TrustCue Project Team (Module 32)
-- Invariants:
--   - Atomic concurrency enforcement under row-level lock.
--   - Execution strictly restricted to trusted server (service_role and postgres).
--   - Clients cannot execute reservation functions or set their own allowance.
--   - Non-negative decrements on quota release/refund.
--   - Provides missing-profile recovery for transient signup trigger failures.
-- ==============================================================================

BEGIN;

-- 1. Atomic Quota Reservation Function
CREATE OR REPLACE FUNCTION public.reserve_ai_quota(
    p_user_id UUID,
    p_max_daily_requests INT DEFAULT 15,
    p_tokens_requested INT DEFAULT 0
)
RETURNS TABLE (
    allowed BOOLEAN,
    requests_used INT,
    requests_remaining INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_today DATE := (timezone('utc'::text, now()))::date;
    v_current_requests INT;
BEGIN
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
        token_count = token_count + GREATEST(0, p_tokens_requested),
        last_request_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE user_id = p_user_id
      AND quota_date = v_today
      AND request_count < p_max_daily_requests
    RETURNING request_count INTO v_current_requests;

    IF FOUND THEN
        RETURN QUERY SELECT
            TRUE AS allowed,
            v_current_requests AS requests_used,
            GREATEST(0, p_max_daily_requests - v_current_requests) AS requests_remaining;
    ELSE
        -- Quota limit reached or lock missed: query current count without incrementing
        SELECT q.request_count INTO v_current_requests
        FROM public.ai_usage_quotas q
        WHERE q.user_id = p_user_id AND q.quota_date = v_today;

        v_current_requests := COALESCE(v_current_requests, p_max_daily_requests);

        RETURN QUERY SELECT
            FALSE AS allowed,
            v_current_requests AS requests_used,
            0 AS requests_remaining;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.reserve_ai_quota(UUID, INT, INT) IS
    'Atomically checks and reserves daily AI quota for authenticated users under concurrency.';

-- 2. Quota Release / Refund Function (e.g., on provider timeout or failure)
CREATE OR REPLACE FUNCTION public.release_ai_quota(
    p_user_id UUID,
    p_tokens_to_refund INT DEFAULT 0
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_today DATE := (timezone('utc'::text, now()))::date;
BEGIN
    UPDATE public.ai_usage_quotas
    SET request_count = GREATEST(0, request_count - 1),
        token_count = GREATEST(0, token_count - GREATEST(0, p_tokens_to_refund)),
        updated_at = timezone('utc'::text, now())
    WHERE user_id = p_user_id
      AND quota_date = v_today;
END;
$$;

COMMENT ON FUNCTION public.release_ai_quota(UUID, INT) IS
    'Releases or refunds a previously reserved daily quota slot if an upstream provider call fails.';

-- 3. Missing-Profile Recovery Function
CREATE OR REPLACE FUNCTION public.ensure_profile_exists(
    p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        created_at,
        updated_at,
        terms_version,
        sync_enabled
    )
    VALUES (
        p_user_id,
        timezone('utc'::text, now()),
        timezone('utc'::text, now()),
        '1.0.0',
        FALSE
    )
    ON CONFLICT (id) DO NOTHING;
END;
$$;

COMMENT ON FUNCTION public.ensure_profile_exists(UUID) IS
    'Guarantees profile row existence for a user, recovering from transient signup trigger failures.';

-- 4. Strict Permissions Lockdown
-- Revoke all execution grants from untrusted and public roles
REVOKE ALL ON FUNCTION public.reserve_ai_quota(UUID, INT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_ai_quota(UUID, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ensure_profile_exists(UUID) FROM PUBLIC, anon, authenticated;

-- Grant execution strictly to trusted server role and superuser
GRANT EXECUTE ON FUNCTION public.reserve_ai_quota(UUID, INT, INT) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.release_ai_quota(UUID, INT) TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.ensure_profile_exists(UUID) TO service_role, postgres;

COMMIT;
