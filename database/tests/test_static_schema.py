"""
Static Schema and Security Policy Regression Test Suite.
Validates database migration files, RLS policy definitions, constraints,
privacy guarantees, and SQL regression test files without requiring a running database.
"""

from pathlib import Path
import re
import unittest

ROOT_DIR = Path(__file__).resolve().parent.parent
MIGRATIONS_DIR = ROOT_DIR / "migrations"
TESTS_SQL_DIR = ROOT_DIR / "tests" / "sql"
FIXTURES_DIR = ROOT_DIR / "tests" / "fixtures"


class TestDatabaseMigrations(unittest.TestCase):
    """Validates PostgreSQL migration files for correct DDL, constraints, and privacy."""

    def test_migration_files_present_and_ordered(self):
        """Ensures all migrations exist with valid sequential prefixes."""
        expected_migrations = [
            "00001_create_profiles.sql",
            "00002_create_ai_usage_quotas.sql",
            "00003_create_synced_reports.sql",
            "00004_create_rls_and_policies.sql",
            "00005_create_auth_trigger.sql",
            "00006_create_quota_reservation.sql",
            "00007_enforce_sync_opt_in.sql",
            "00008_harden_sync_purge_and_allowlist.sql",
        ]
        actual_files = sorted([f.name for f in MIGRATIONS_DIR.glob("*.sql")])
        self.assertEqual(actual_files, expected_migrations)

    def test_all_migrations_are_transactional(self):
        """Verifies each migration begins with BEGIN; and ends with COMMIT;."""
        for sql_file in MIGRATIONS_DIR.glob("*.sql"):
            content = sql_file.read_text(encoding="utf-8")
            self.assertTrue(
                re.search(r"^\s*BEGIN\s*;", content, re.MULTILINE),
                f"{sql_file.name} missing BEGIN; transaction wrapper",
            )
            self.assertTrue(
                re.search(r"^\s*COMMIT\s*;", content, re.MULTILINE),
                f"{sql_file.name} missing COMMIT; transaction wrapper",
            )

    def test_profiles_schema_invariants(self):
        """Validates public.profiles schema, foreign key cascade, and boundaries."""
        content = (MIGRATIONS_DIR / "00001_create_profiles.sql").read_text(encoding="utf-8")
        self.assertIn("CREATE TABLE IF NOT EXISTS public.profiles", content)
        self.assertIn("REFERENCES auth.users(id) ON DELETE CASCADE", content)
        self.assertIn("chk_profile_display_name_len", content)
        self.assertIn("char_length(display_name) <= 64", content)
        self.assertIn("chk_profile_terms_version_len", content)
        self.assertIn("char_length(terms_version) BETWEEN 1 AND 32", content)
        self.assertIn("sync_enabled BOOLEAN NOT NULL DEFAULT FALSE", content)

    def test_quotas_schema_invariants_and_privacy(self):
        """Validates public.ai_usage_quotas schema, unique constraints, and strict privacy."""
        content = (MIGRATIONS_DIR / "00002_create_ai_usage_quotas.sql").read_text(encoding="utf-8")
        self.assertIn("CREATE TABLE IF NOT EXISTS public.ai_usage_quotas", content)
        self.assertIn("REFERENCES auth.users(id) ON DELETE CASCADE", content)
        self.assertIn("CONSTRAINT uq_ai_usage_quotas_user_date UNIQUE (user_id, quota_date)", content)
        self.assertIn("chk_quotas_requests_non_negative", content)
        self.assertIn("chk_quotas_tokens_non_negative", content)

        # Privacy Audit: Ensure zero prompt, excerpt, content, or hash columns exist
        # Strip comments first
        uncommented = re.sub(r"--.*$", "", content, flags=re.MULTILINE)
        forbidden_columns = [
            "prompt", "input_text", "query", "body", "content",
            "excerpt", "message", "hash", "raw_text", "transcription"
        ]
        for col in forbidden_columns:
            pattern = rf"\b{col}\b\s+(TEXT|VARCHAR|BYTEA|JSON|JSONB)"
            self.assertIsNone(
                re.search(pattern, uncommented, re.IGNORECASE),
                f"Privacy violation in 00002: forbidden column '{col}' detected!",
            )

    def test_synced_reports_schema_and_boundaries(self):
        """Validates public.synced_reports schema, payload boundaries, and tombstone consistency."""
        content = (MIGRATIONS_DIR / "00003_create_synced_reports.sql").read_text(encoding="utf-8")
        self.assertIn("CREATE TABLE IF NOT EXISTS public.synced_reports", content)
        self.assertIn("REFERENCES auth.users(id) ON DELETE CASCADE", content)
        self.assertIn("CONSTRAINT uq_synced_reports_user_report UNIQUE (user_id, client_report_id)", content)
        self.assertIn("chk_report_payload_size", content)
        self.assertIn("octet_length(report_payload::text) <= 500000", content)
        self.assertIn("chk_tombstone_consistency", content)

        # Privacy Audit: ensure no binary/screenshot attachments
        uncommented = re.sub(r"--.*$", "", content, flags=re.MULTILINE)
        forbidden_types = ["BYTEA", "BLOB", "image", "screenshot"]
        for term in forbidden_types:
            pattern = rf"\b{term}\b"
            self.assertIsNone(
                re.search(pattern, uncommented, re.IGNORECASE),
                f"Privacy violation in 00003: forbidden term '{term}' detected!",
            )

    def test_rls_and_policies_enforcement(self):
        """Validates that RLS is enabled/forced, privileges revoked, and policies contain WITH CHECK."""
        content = (MIGRATIONS_DIR / "00004_create_rls_and_policies.sql").read_text(encoding="utf-8")

        for table in ["profiles", "ai_usage_quotas", "synced_reports"]:
            self.assertIn(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY;", content)
            self.assertIn(f"ALTER TABLE public.{table} FORCE ROW LEVEL SECURITY;", content)

        # Default privilege revocation
        self.assertIn("REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon;", content)
        self.assertIn("REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon;", content)
        self.assertIn("REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;", content)

        # Quotas must be read-only for authenticated role
        self.assertIn("GRANT SELECT ON public.ai_usage_quotas TO authenticated;", content)
        self.assertNotIn("INSERT ON public.ai_usage_quotas TO authenticated", content)
        self.assertNotIn("UPDATE ON public.ai_usage_quotas TO authenticated", content)
        self.assertNotIn("DELETE ON public.ai_usage_quotas TO authenticated", content)

        # Update policies must have both USING and WITH CHECK to prevent ownership theft
        self.assertIn("CREATE POLICY \"profiles_update_own\"", content)
        self.assertIn("USING (auth.uid() = id)", content)
        self.assertIn("WITH CHECK (auth.uid() = id)", content)

        self.assertIn("CREATE POLICY \"reports_update_own\"", content)
        self.assertIn("USING (auth.uid() = user_id)", content)
        self.assertIn("WITH CHECK (auth.uid() = user_id)", content)

    def test_auth_trigger_security_definer_and_search_path(self):
        """Validates SECURITY DEFINER hygiene and search_path pinning for public.handle_new_user()."""
        content = (MIGRATIONS_DIR / "00005_create_auth_trigger.sql").read_text(encoding="utf-8")
        self.assertIn("CREATE OR REPLACE FUNCTION public.handle_new_user()", content)
        self.assertIn("SECURITY DEFINER", content)
        self.assertIn("SET search_path = public, auth, pg_temp", content)
        self.assertIn("DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;", content)
        self.assertIn("CREATE TRIGGER on_auth_user_created", content)
        self.assertIn("AFTER INSERT ON auth.users", content)

    def test_sync_opt_in_and_privacy_invariants(self):
        """Validates migration 00007 sync_enabled opt-in RLS and payload privacy constraints."""
        content = (MIGRATIONS_DIR / "00007_enforce_sync_opt_in.sql").read_text(encoding="utf-8")
        self.assertIn("chk_report_payload_privacy", content)
        self.assertIn("NOT (report_payload ? 'text')", content)
        self.assertIn("NOT (report_payload ? 'rawText')", content)
        self.assertIn("NOT (report_payload ? 'excerpt')", content)
        self.assertIn("NOT (report_payload ? 'screenshot')", content)
        self.assertIn("CREATE POLICY \"reports_insert_own\"", content)
        self.assertIn("profiles.sync_enabled = TRUE", content)
        self.assertIn("CREATE POLICY \"reports_update_own\"", content)
        self.assertIn("FUNCTION public.purge_synced_reports()", content)
        self.assertIn("SECURITY DEFINER", content)
        self.assertIn("SET search_path = public, auth, pg_temp", content)

    def test_sync_purge_and_allowlist_invariants(self):
        """Validates migration 8 sync generation, dual auth path purge, and payload allowlist."""
        content = (MIGRATIONS_DIR / "00008_harden_sync_purge_and_allowlist.sql").read_text(encoding="utf-8")
        self.assertIn("sync_generation INT NOT NULL DEFAULT 1", content)
        self.assertIn("sync_purged_at TIMESTAMPTZ", content)
        self.assertIn("FUNCTION public.purge_synced_reports(target_user_id UUID DEFAULT NULL)", content)
        self.assertIn("chk_report_payload_privacy", content)
        self.assertIn("(report_payload ? 'formatVersion')", content)
        self.assertIn("(report_payload ? 'outcomeState')", content)
        self.assertIn("(report_payload ? 'hasAiAnalysis')", content)
        self.assertIn("(report_payload ? 'indicatorCount')", content)
        self.assertIn("(report_payload ? 'categories')", content)
        self.assertIn("(report_payload ? 'source')", content)
        self.assertIn("jsonb_typeof(report_payload->'formatVersion') = 'number'", content)
        self.assertIn("jsonb_typeof(report_payload->'categories') = 'array'", content)
        self.assertIn("public.synced_reports.client_updated_at > public.profiles.sync_purged_at", content)

        self.assertIn("public.synced_reports.is_deleted = TRUE", content)
        self.assertIn("public.synced_reports.sync_generation = public.profiles.sync_generation", content)
        self.assertIn("FOR UPDATE", content)
        self.assertNotIn("NEW.", content)



class TestSQLRegressionSuites(unittest.TestCase):
    """Validates SQL regression test files for complete coverage and transaction safety."""

    def test_quota_reservation_invariants(self):
        """Validates migration 6 quota reservation, release, and profile recovery functions."""
        content = (MIGRATIONS_DIR / "00006_create_quota_reservation.sql").read_text(encoding="utf-8")
        self.assertIn("FUNCTION public.reserve_ai_quota", content)
        self.assertIn("FUNCTION public.release_ai_quota", content)
        self.assertIn("FUNCTION public.ensure_profile_exists", content)
        self.assertIn("SECURITY DEFINER", content)
        self.assertIn("SET search_path = public, auth, pg_temp", content)
        self.assertIn("REVOKE ALL ON FUNCTION public.reserve_ai_quota(UUID, INT, INT) FROM PUBLIC, anon, authenticated;", content)
        self.assertIn("GRANT EXECUTE ON FUNCTION public.reserve_ai_quota(UUID, INT, INT) TO service_role, postgres;", content)

    def test_regression_test_files_present(self):
        """Verifies all required SQL regression test suites exist."""
        expected_tests = [
            "01_test_profiles_rls.sql",
            "02_test_quotas_isolation.sql",
            "03_test_reports_sync_rls.sql",
            "04_test_cascade_deletion.sql",
            "05_test_quota_reservation.sql",
            "06_test_sync_opt_in_rls.sql",
            "07_test_sync_purge_and_allowlist.sql",
        ]
        actual_files = sorted([f.name for f in TESTS_SQL_DIR.glob("*.sql")])
        self.assertEqual(actual_files, expected_tests)

    def test_regression_tests_error_handling_and_rollback(self):
        """Verifies each SQL test suite uses ON_ERROR_STOP and cleans up via ROLLBACK."""
        for sql_file in TESTS_SQL_DIR.glob("*.sql"):
            content = sql_file.read_text(encoding="utf-8")
            self.assertIn(r"\set ON_ERROR_STOP on", content, f"{sql_file.name} missing ON_ERROR_STOP")
            self.assertTrue(
                re.search(r"^\s*BEGIN\s*;", content, re.MULTILINE),
                f"{sql_file.name} missing BEGIN;",
            )
            self.assertTrue(
                re.search(r"^\s*ROLLBACK\s*;", content, re.MULTILINE),
                f"{sql_file.name} missing ROLLBACK;",
            )

    def test_test_auth_compat_fixture_integrity(self):
        """Verifies auth test fixture creates simulated auth schema and test helpers."""
        fixture_file = FIXTURES_DIR / "test_auth_compat.sql"
        self.assertTrue(fixture_file.exists(), "test_auth_compat.sql fixture missing")
        content = fixture_file.read_text(encoding="utf-8")
        self.assertIn("CREATE SCHEMA IF NOT EXISTS auth;", content)
        self.assertIn("CREATE TABLE IF NOT EXISTS auth.users", content)
        self.assertIn("CREATE OR REPLACE FUNCTION auth.uid()", content)
        self.assertIn("CREATE OR REPLACE FUNCTION auth.role()", content)
        self.assertIn("CREATE OR REPLACE FUNCTION auth.set_test_user", content)
        self.assertIn("CREATE OR REPLACE FUNCTION auth.reset_test_user", content)


if __name__ == "__main__":
    unittest.main()
