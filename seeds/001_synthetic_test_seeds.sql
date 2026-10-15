-- ==============================================================================
-- Seed: 001_synthetic_test_seeds.sql
-- Description: Isolated synthetic test accounts for local/CI regression testing.
-- Authorship: TrustCue Project Team (Module 29)
-- STRICT MANDATE:
--   - This file is strictly for testing and development fixtures.
--   - It MUST NEVER be executed against production databases.
-- ==============================================================================

BEGIN;

-- Insert two synthetic test users into mock auth.users (if auth.users exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_namespace n
        JOIN pg_class c ON c.relnamespace = n.oid
        WHERE n.nspname = 'auth' AND c.relname = 'users'
    ) THEN
        INSERT INTO auth.users (id, email)
        VALUES
            ('a0000000-0000-0000-0000-000000000001', 'synthetic_user_a@trustcue.test'),
            ('b0000000-0000-0000-0000-000000000002', 'synthetic_user_b@trustcue.test')
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;

COMMIT;
