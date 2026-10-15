-- ==============================================================================
-- Migration: 00002_create_ai_usage_quotas.sql
-- Description: Creates the public.ai_usage_quotas table for server-managed rate limiting.
-- Authorship: TrustCue Project Team (Module 29)
-- Invariants:
--   - Tracks aggregate daily usage counters per user.
--   - Zero prompts, message text, evidence excerpts, or message hashes stored.
--   - Nonnegative constraints on request_count and token_count.
--   - Unique constraint on (user_id, quota_date) enables atomic ON CONFLICT upsert increments.
--   - Cascade deletion on auth.users deletion.
-- ==============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.ai_usage_quotas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    quota_date DATE NOT NULL DEFAULT CURRENT_DATE,
    request_count INT NOT NULL DEFAULT 0,
    token_count INT NOT NULL DEFAULT 0,
    last_request_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_ai_usage_quotas_user_date UNIQUE (user_id, quota_date),
    CONSTRAINT chk_quotas_requests_non_negative CHECK (request_count >= 0),
    CONSTRAINT chk_quotas_tokens_non_negative CHECK (token_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_quotas_user_date
    ON public.ai_usage_quotas (user_id, quota_date);

COMMENT ON TABLE public.ai_usage_quotas IS 'Daily operational AI usage counters for fail-closed rate limit enforcement.';
COMMENT ON COLUMN public.ai_usage_quotas.id IS 'Unique identifier of the quota tracking window record.';
COMMENT ON COLUMN public.ai_usage_quotas.user_id IS 'Owner referencing auth.users(id). Cascades on user deletion.';
COMMENT ON COLUMN public.ai_usage_quotas.quota_date IS 'UTC calendar date representing the 24-hour rate limit window.';
COMMENT ON COLUMN public.ai_usage_quotas.request_count IS 'Non-negative integer count of AI requests processed during the window.';
COMMENT ON COLUMN public.ai_usage_quotas.token_count IS 'Non-negative integer count of total tokens consumed during the window.';
COMMENT ON COLUMN public.ai_usage_quotas.last_request_at IS 'UTC timestamp of the most recent AI inference invocation.';

COMMIT;
