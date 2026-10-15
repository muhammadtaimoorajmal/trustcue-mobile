-- ==============================================================================
-- Migration: 00003_create_synced_reports.sql
-- Description: Creates the public.synced_reports table for optional cloud backup.
-- Authorship: TrustCue Project Team (Module 29)
-- Invariants:
--   - Opt-in storage: only populated when client explicitly requests synchronization.
--   - Authoritative ownership bound to user_id referencing auth.users(id).
--   - Scoped uniqueness: (user_id, client_report_id) prevents cross-client collision.
--   - Payload size boundary: octet_length(report_payload::text) <= 500,000 bytes (~500 KB).
--   - Strict tombstone consistency constraint prevents desynchronization.
--   - Excludes screenshots, raw binary assets, and unredacted sensitive values.
-- ==============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.synced_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    client_report_id TEXT NOT NULL CHECK (char_length(client_report_id) BETWEEN 1 AND 128),
    snapshot_id TEXT NOT NULL CHECK (char_length(snapshot_id) BETWEEN 1 AND 128),
    schema_version INT NOT NULL DEFAULT 1 CHECK (schema_version >= 1),
    revision INT NOT NULL DEFAULT 1 CHECK (revision >= 1),
    report_payload JSONB NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    client_updated_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_synced_reports_user_report UNIQUE (user_id, client_report_id),
    CONSTRAINT chk_report_payload_size CHECK (octet_length(report_payload::text) <= 500000),
    CONSTRAINT chk_tombstone_consistency CHECK (
        (is_deleted = FALSE AND deleted_at IS NULL) OR
        (is_deleted = TRUE AND deleted_at IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_synced_reports_user_sync
    ON public.synced_reports (user_id, is_deleted, client_updated_at);

COMMENT ON TABLE public.synced_reports IS 'Opt-in cloud synchronization datastore for user analysis reports.';
COMMENT ON COLUMN public.synced_reports.id IS 'Internal server sync record primary key UUID.';
COMMENT ON COLUMN public.synced_reports.user_id IS 'Authoritative owner referencing auth.users(id). Cascades on user deletion.';
COMMENT ON COLUMN public.synced_reports.client_report_id IS 'Unique client-generated report identifier from local device.';
COMMENT ON COLUMN public.synced_reports.snapshot_id IS 'Client-generated identifier of the analyzed text snapshot.';
COMMENT ON COLUMN public.synced_reports.schema_version IS 'Contract schema version of the stored report JSON.';
COMMENT ON COLUMN public.synced_reports.revision IS 'Monotonically increasing synchronization revision counter.';
COMMENT ON COLUMN public.synced_reports.report_payload IS 'Bounded structured report JSON payload (max 500 KB).';
COMMENT ON COLUMN public.synced_reports.is_deleted IS 'Synchronization tombstone flag indicating report deletion.';
COMMENT ON COLUMN public.synced_reports.deleted_at IS 'UTC timestamp when the report was tombstoned.';
COMMENT ON COLUMN public.synced_reports.client_updated_at IS 'Device UTC timestamp when the report was modified or created.';

COMMIT;
