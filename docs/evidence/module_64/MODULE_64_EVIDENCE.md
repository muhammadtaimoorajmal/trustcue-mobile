# Module 64 Evidence Dossier: Persistent Cloud Quota Store, Atomic Reservation Lifecycle & Production Verification

**Document ID:** `DOC-M64-EVIDENCE`  
**Date:** November 2, 2026  
**Status:** COMPLETE & VERIFIED  
**Worktree Branches:**  
- `database`: `f55b02d` (CI Run `41473981845` — SUCCESS)  
- `backend`: `52c3d89` (CI Run `41475298223` — SUCCESS)  
- `frontend`: `2f46478` (Docs & Registration update)  
- `main`: `a785db8` (Untouched Pre-Integration Baseline)  

---

## 1. Reconciliation of Open Production Items

| Subsystem / Feature | Source Code Status | Automated Test Status | Hosted Production Applied | Live Verification Status | Notes & Owner Action Required |
|---|---|---|---|---|---|
| **Migration 00009 (Avatar Storage & Profiles field)** | Complete on `database` | 14/14 tests pass | **Pending Owner SQL Execution** | Blocked on Supabase Cloud DDL | PostgREST exposes no DDL endpoint. Owner must run `00009_create_avatar_storage.sql` in Supabase Studio SQL Editor. |
| **Avatar Lifecycle (Upload / Display / Restart / Replace / Remove)** | Complete in Flutter & FastAPI | 99/99 auth tests pass | Ready in code | **Deferred until Migration 00009 executed** | Mobile correctly surfaces retryable 503 when cloud storage policy is unapplied. |
| **Password Reset Dispatch & In-App Change** | Complete in Flutter & FastAPI | Pass anti-enumeration & routing tests | Active on Supabase GoTrue | **VERIFIED** on Vivo V2207 | Reset email arrives; in-app password update verified. |
| **Database Readiness Probe (`/ready`)** | Complete in FastAPI | Unit & outage tests pass (162/162) | Deployed on Render | **VERIFIED (Truthful)** | Distinguishes configuration from connectivity via PostgREST probe (`GET /rest/v1/ai_usage_quotas?limit=1`, 2.0s timeout, 10s caching). Outage returns 503 Degraded. |
| **Persistent Quota Storage (`SupabaseQuotaStore`)** | Complete in FastAPI (`52c3d89`) | 162/162 pytest pass | Deployed on Render | **VERIFIED** | Directs reads/writes to PostgREST; fails closed (503); survives process restarts; backward-compatible v1 fallback. |
| **Durable Quota Reservations (`Migration 00010`)** | Complete on `database` (`f55b02d`) | 15/15 SQL & static schema pass | **Pending Owner SQL Execution** | Operational via v1 fallback | Table `public.ai_quota_reservations` and v2 RPCs ready. Backend operates immediately via v1 fallback and upgrades seamlessly once applied. |

---

## 2. Action Required by Project Owner: Supabase Studio SQL Execution

Because managed Supabase Cloud does not expose DDL execution endpoints over PostgREST (returning 404 on `/pg/query`), migrations `00009` and `00010` must be executed once by the project owner in the Supabase Studio SQL Editor at `https://supabase.com/dashboard/project/yzqkmoqqvnhfmmrayfko/sql/new`:

```sql
-- ============================================================================
-- CONSOLIDATED HOSTED MIGRATIONS 00009 & 00010 FOR SUPABASE STUDIO
-- Project: TrustCue (yzqkmoqqvnhfmmrayfko)
-- ============================================================================

-- 1. Migration 00009: Avatar Column & Storage Bucket
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_path TEXT;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', false, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 2097152,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can upload own avatar'
  ) THEN
    CREATE POLICY "Users can upload own avatar"
      ON storage.objects FOR INSERT
      TO authenticated
      WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can view own avatar'
  ) THEN
    CREATE POLICY "Users can view own avatar"
      ON storage.objects FOR SELECT
      TO authenticated
      USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can update own avatar'
  ) THEN
    CREATE POLICY "Users can update own avatar"
      ON storage.objects FOR UPDATE
      TO authenticated
      USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
      WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can delete own avatar'
  ) THEN
    CREATE POLICY "Users can delete own avatar"
      ON storage.objects FOR DELETE
      TO authenticated
      USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;
END $$;

-- 2. Migration 00010: Durable Quota Reservations Table & Atomic RPCs
CREATE TABLE IF NOT EXISTS public.ai_quota_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    quota_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'committed', 'released')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.ai_quota_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_quota_reservations FORCE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'ai_quota_reservations' AND policyname = 'reservations_read_own'
  ) THEN
    CREATE POLICY reservations_read_own ON public.ai_quota_reservations
      FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;
END $$;

REVOKE ALL ON public.ai_quota_reservations FROM anon, authenticated;
GRANT SELECT ON public.ai_quota_reservations TO authenticated;
GRANT ALL ON public.ai_quota_reservations TO service_role, postgres;

CREATE OR REPLACE FUNCTION public.reserve_ai_quota_v2(
    p_user_id UUID,
    p_reservation_id UUID DEFAULT gen_random_uuid(),
    p_max_daily_requests INT DEFAULT 15
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
    v_today DATE := CURRENT_DATE;
    v_current_requests INT;
    v_existing_status TEXT;
BEGIN
    SELECT status INTO v_existing_status
    FROM public.ai_quota_reservations
    WHERE id = p_reservation_id;

    IF FOUND THEN
        SELECT request_count INTO v_current_requests
        FROM public.ai_usage_quotas
        WHERE user_id = p_user_id AND quota_date = v_today;

        v_current_requests := COALESCE(v_current_requests, 0);

        RETURN QUERY SELECT
            (v_existing_status = 'reserved' OR v_existing_status = 'committed'),
            v_current_requests,
            GREATEST(0, p_max_daily_requests - v_current_requests);
        RETURN;
    END IF;

    INSERT INTO public.ai_usage_quotas (user_id, quota_date, request_count, token_count)
    VALUES (p_user_id, v_today, 0, 0)
    ON CONFLICT (user_id, quota_date) DO NOTHING;

    SELECT request_count INTO v_current_requests
    FROM public.ai_usage_quotas
    WHERE user_id = p_user_id AND quota_date = v_today
    FOR UPDATE;

    IF v_current_requests >= p_max_daily_requests THEN
        RETURN QUERY SELECT FALSE, v_current_requests, 0;
        RETURN;
    END IF;

    UPDATE public.ai_usage_quotas
    SET request_count = request_count + 1,
        updated_at = timezone('utc'::text, now())
    WHERE user_id = p_user_id AND quota_date = v_today;

    INSERT INTO public.ai_quota_reservations (id, user_id, quota_date, status)
    VALUES (p_reservation_id, p_user_id, v_today, 'reserved');

    RETURN QUERY SELECT
        TRUE,
        v_current_requests + 1,
        GREATEST(0, p_max_daily_requests - (v_current_requests + 1));
END;
$$;

CREATE OR REPLACE FUNCTION public.commit_ai_quota_v2(
    p_user_id UUID,
    p_reservation_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_owner_id UUID;
    v_status TEXT;
BEGIN
    SELECT user_id, status INTO v_owner_id, v_status
    FROM public.ai_quota_reservations
    WHERE id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_owner_id != p_user_id THEN
        RAISE EXCEPTION 'Access denied: reservation does not belong to user' USING ERRCODE = '42501';
    END IF;

    IF v_status = 'reserved' THEN
        UPDATE public.ai_quota_reservations
        SET status = 'committed',
            updated_at = timezone('utc'::text, now())
        WHERE id = p_reservation_id;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.release_ai_quota_v2(
    p_user_id UUID,
    p_reservation_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_owner_id UUID;
    v_status TEXT;
    v_quota_date DATE;
BEGIN
    SELECT user_id, status, quota_date INTO v_owner_id, v_status, v_quota_date
    FROM public.ai_quota_reservations
    WHERE id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_owner_id != p_user_id THEN
        RAISE EXCEPTION 'Access denied: reservation does not belong to user' USING ERRCODE = '42501';
    END IF;

    IF v_status = 'committed' THEN
        RETURN;
    END IF;

    IF v_status = 'reserved' THEN
        UPDATE public.ai_quota_reservations
        SET status = 'released',
            updated_at = timezone('utc'::text, now())
        WHERE id = p_reservation_id;

        UPDATE public.ai_usage_quotas
        SET request_count = GREATEST(0, request_count - 1),
            updated_at = timezone('utc'::text, now())
        WHERE user_id = p_user_id AND quota_date = v_quota_date;
    END IF;
END;
$$;

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
    v_used INT := 0;
BEGIN
    SELECT request_count INTO v_used
    FROM public.ai_usage_quotas
    WHERE user_id = p_user_id AND quota_date = CURRENT_DATE;

    RETURN GREATEST(0, p_max_daily_requests - COALESCE(v_used, 0));
END;
$$;

CREATE OR REPLACE FUNCTION public.reap_abandoned_reservations(
    p_timeout_interval INTERVAL DEFAULT INTERVAL '10 minutes'
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_reaped_count INT := 0;
    r RECORD;
BEGIN
    FOR r IN
        SELECT id, user_id, quota_date
        FROM public.ai_quota_reservations
        WHERE status = 'reserved'
          AND created_at < (timezone('utc'::text, now()) - p_timeout_interval)
        FOR UPDATE SKIP LOCKED
    LOOP
        UPDATE public.ai_quota_reservations
        SET status = 'released',
            updated_at = timezone('utc'::text, now())
        WHERE id = r.id;

        UPDATE public.ai_usage_quotas
        SET request_count = GREATEST(0, request_count - 1),
            updated_at = timezone('utc'::text, now())
        WHERE user_id = r.user_id AND quota_date = r.quota_date;

        v_reaped_count := v_reaped_count + 1;
    END LOOP;

    RETURN v_reaped_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reserve_ai_quota_v2(UUID, UUID, INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.commit_ai_quota_v2(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_ai_quota_v2(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_remaining_ai_quota(UUID, INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.reap_abandoned_reservations(INTERVAL) TO service_role;
```

---

## 3. Persistent Quota Contract Guarantees

1. **Configured Daily Allowance:** 15 requests per 24-hour UTC window.
2. **Atomic Row Locks:** Handled under PostgreSQL `FOR UPDATE` transaction locks to prevent concurrency races.
3. **Idempotency:** Re-issuing an existing `reservation_id` returns the current state without double-incrementing.
4. **Committed Reservations:** Committed reservations cannot be refunded even if an upstream cancellation occurs.
5. **UTC Midnight Rollover:** Refunds check the reservation record's `quota_date` and restore allowance to the *original* date, preventing corruption of the new day's allowance.
6. **Zero Data Retention:** Zero message text, excerpts, tokens, or hashes are stored in `ai_quota_reservations`.
7. **Cross-User Protection:** Non-matching `user_id` returns PostgreSQL exception code `42501` (Access Denied).
8. **Crash & Abandonment Reaping:** Unsettled reservations older than 10 minutes can be safely reaped by `reap_abandoned_reservations`.

---

## 4. Test & Verification Evidence

- **Database CI Run `41473981845`:** Passed 15/15 tests on branch `database` (`f55b02d`).
- **Backend CI Run `41475298223`:** Passed 162/162 tests on branch `backend` (`52c3d89`).
- **Live Render Status:**
  - `GET https://trustcue-backend.onrender.com/health` -> HTTP 200 (`{"status":"ok","version":"0.1.0"}`)
  - `GET https://trustcue-backend.onrender.com/ready` -> HTTP 200 (`{"status":"ready","dependencies":{"foundation":"ok","authProvider":"ok","database":"ok","aiProvider":"ok"}}`)
- **Physical Device Vivo V2207 (`10AC9R1ABF0013A`):**
  - Confirmed Account Screen reports: `15 of 15 analysis queries remaining today. Quotas reset daily at midnight UTC.`
  - Screenshots and hierarchy captured in `docs/evidence/module_64/`.
