-- ==============================================================================
-- Migration: 00001_create_profiles.sql
-- Description: Creates the public.profiles table referencing auth.users.
-- Authorship: TrustCue Project Team (Module 29)
-- Invariants:
--   - 1:1 relationship with auth.users via primary key FK.
--   - No sensitive passwords, tokens, or duplicated auth credentials.
--   - Bounded display_name (max 64 runes, trimmed) and terms_version (1-32 runes).
--   - Cascade deletion on auth.users deletion.
-- ==============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    terms_version TEXT NOT NULL DEFAULT '1.0.0',
    sync_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT chk_profile_display_name_len CHECK (
        display_name IS NULL OR (
            char_length(display_name) <= 64 AND
            display_name ~ '^\S(.*\S)?$'
        )
    ),
    CONSTRAINT chk_profile_terms_version_len CHECK (
        char_length(terms_version) BETWEEN 1 AND 32
    )
);

COMMENT ON TABLE public.profiles IS 'User application profile and privacy preferences linked 1:1 with auth.users.';
COMMENT ON COLUMN public.profiles.id IS 'Primary key referencing auth.users(id). Cascades on user deletion.';
COMMENT ON COLUMN public.profiles.display_name IS 'Optional sanitized user display name (max 64 characters, trimmed).';
COMMENT ON COLUMN public.profiles.terms_version IS 'Version string of privacy notice and terms accepted by the user.';
COMMENT ON COLUMN public.profiles.sync_enabled IS 'Explicit opt-in flag for account-owned encrypted cloud report backup.';
COMMENT ON COLUMN public.profiles.created_at IS 'UTC timestamp when the profile record was created.';
COMMENT ON COLUMN public.profiles.updated_at IS 'UTC timestamp when the profile record was last modified.';

COMMIT;
