-- ==============================================================================
-- Migration: 00009_create_avatar_storage_and_profile_field.sql
-- Description: Adds avatar_path to profiles and configures secure private avatars storage bucket with RLS.
-- Authorship: TrustCue Project Team (Module 62)
-- Invariants:
--   - public.profiles.avatar_path is strictly validated (max 255 chars, user UUID prefix).
--   - avatars storage bucket is private (public = false) with 2MB max file limit.
--   - Allowed MIME types strictly limited to JPEG, PNG, WebP.
--   - Storage RLS enforces authenticated user isolation: users can only read/write/delete objects in their own <user_id>/ path.
--   - Anonymous access is completely denied.
-- ==============================================================================

BEGIN;

-- 1. Ensure storage schema and tables exist for compatibility
CREATE SCHEMA IF NOT EXISTS storage;

CREATE TABLE IF NOT EXISTS storage.buckets (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    owner UUID,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    public BOOLEAN DEFAULT FALSE,
    avif_autodetection BOOLEAN DEFAULT FALSE,
    file_size_limit BIGINT,
    allowed_mime_types TEXT[]
);

CREATE TABLE IF NOT EXISTS storage.objects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_id TEXT REFERENCES storage.buckets(id),
    name TEXT,
    owner UUID,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    last_accessed_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    metadata JSONB
);

CREATE OR REPLACE FUNCTION storage.foldername(name text)
RETURNS text[]
LANGUAGE plpgsql
AS $$
DECLARE
    _parts text[];
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    RETURN _parts[1:array_length(_parts, 1) - 1];
END;
$$;

-- 2. Add avatar_path column and format constraint to public.profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS avatar_path TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_profile_avatar_path_len'
    ) THEN
        ALTER TABLE public.profiles
        ADD CONSTRAINT chk_profile_avatar_path_len CHECK (
            avatar_path IS NULL OR (
                char_length(avatar_path) <= 255 AND
                avatar_path ~ '^[0-9a-fA-F-]+/[a-zA-Z0-9_\.-]+$'
            )
        );
    END IF;
END $$;

COMMENT ON COLUMN public.profiles.avatar_path IS 'Relative storage path in avatars bucket (<user_id>/filename). Strictly bounded and owner-scoped.';

-- 3. Register private avatars bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    FALSE,
    2097152, -- 2MB in bytes
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = FALSE,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- 4. Enable and Force Row Level Security on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects FORCE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
GRANT SELECT ON storage.buckets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;

-- 5. Define RLS Policies for avatars storage bucket
DROP POLICY IF EXISTS "avatars_select_own" ON storage.objects;
CREATE POLICY "avatars_select_own"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
CREATE POLICY "avatars_insert_own"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
CREATE POLICY "avatars_update_own"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;
CREATE POLICY "avatars_delete_own"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

COMMIT;
