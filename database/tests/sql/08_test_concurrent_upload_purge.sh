#!/usr/bin/env bash
# ==============================================================================
# Script: 08_test_concurrent_upload_purge.sh
# Description: Real concurrent PostgreSQL test verifying that an upload paused
#              around a purge cannot resurrect stale data or bypass serialization.
# ==============================================================================

set -euo pipefail

echo "=== Starting Concurrent Upload/Purge Race Test ==="

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGDATABASE="${PGDATABASE:-trustcue_db}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres_ci_password}"
export PGPASSWORD

psql_cmd() {
  psql -v ON_ERROR_STOP=1 -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" "$@"
}

USER_ID="e0000000-0000-0000-0000-000000000001"

echo "--- Setup: provisioning test user and initial profile (gen=1, sync=true) ---"
psql_cmd -c "
SELECT auth.reset_test_user();
INSERT INTO auth.users (id, email) VALUES ('$USER_ID', 'race_user@test.com') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.profiles (id, display_name, sync_enabled, sync_generation)
VALUES ('$USER_ID', 'Race User', TRUE, 1)
ON CONFLICT (id) DO UPDATE SET sync_enabled = TRUE, sync_generation = 1, sync_purged_at = NULL;
DELETE FROM public.synced_reports WHERE user_id = '$USER_ID';
"

echo "--- Scenario 1: Upload paused inside transaction; concurrent Purge serializes ---"
# Background Job A: Starts upload transaction, acquires FOR SHARE on profile, sleeps 2s, inserts and commits.
psql_cmd -c "
BEGIN;
SELECT auth.set_test_user('$USER_ID'::uuid, 'authenticated');
-- Acquire FOR SHARE lock on user profile (same lock acquired by fn_validate_synced_report_write)
SELECT sync_generation FROM public.profiles WHERE id = '$USER_ID' FOR SHARE;
-- Deliberately pause upload holding the profile lock
SELECT pg_sleep(2);
-- Write generation-1 report
INSERT INTO public.synced_reports (
    user_id, client_report_id, snapshot_id, sync_generation, report_payload, client_updated_at
) VALUES (
    '$USER_ID', 'rep-race-001', 'snap-001', 1,
    '{\"formatVersion\": 1, \"outcomeState\": \"cautious\", \"hasAiAnalysis\": false, \"indicatorCount\": 0, \"categories\": [], \"source\": \"messageText\"}'::jsonb,
    now()
);
COMMIT;
" &
PID_UPLOAD=$!

# Foreground Job B: Wait for Job A to enter transaction, then run purge_synced_reports.
# purge_synced_reports requests FOR UPDATE on profile, which MUST block until Job A commits.
sleep 0.5
psql_cmd -c "
-- Call purge. Blocks on profile FOR UPDATE until Upload commits, then atomically purges all reports and bumps generation to 2.
SELECT public.purge_synced_reports('$USER_ID'::uuid);
"

wait $PID_UPLOAD

# Verify Scenario 1 result
REPORT_COUNT=$(psql_cmd -t -A -c "SELECT count(*) FROM public.synced_reports WHERE user_id = '$USER_ID';")
PROFILE_GEN=$(psql_cmd -t -A -c "SELECT sync_generation FROM public.profiles WHERE id = '$USER_ID';")
SYNC_ENABLED=$(psql_cmd -t -A -c "SELECT sync_enabled FROM public.profiles WHERE id = '$USER_ID';")

echo "Scenario 1 Result: reports=$REPORT_COUNT, generation=$PROFILE_GEN, sync_enabled=$SYNC_ENABLED"
if [ "$REPORT_COUNT" -ne 0 ]; then
  echo "FAIL: Stale report survived purge in Scenario 1! (count=$REPORT_COUNT)"
  exit 1
fi
if [ "$PROFILE_GEN" -ne 2 ] || [ "$SYNC_ENABLED" != "f" ]; then
  echo "FAIL: Profile generation or sync_enabled not updated correctly in Scenario 1!"
  exit 1
fi
echo "PASS: Scenario 1 verified. Stale upload during purge was atomically deleted."

echo "--- Scenario 2: Purge paused inside transaction; concurrent Upload blocked & rejected ---"
# Reset sync_enabled for testing
psql_cmd -c "UPDATE public.profiles SET sync_enabled = TRUE WHERE id = '$USER_ID';"

# Background Job A: Starts purge transaction, locks profile FOR UPDATE, sleeps 2s, completes purge to gen 3.
psql_cmd -c "
BEGIN;
SELECT 1 FROM public.profiles WHERE id = '$USER_ID' FOR UPDATE;
DELETE FROM public.synced_reports WHERE user_id = '$USER_ID';
-- Deliberately pause purge holding FOR UPDATE lock
SELECT pg_sleep(2);
UPDATE public.profiles
SET sync_generation = sync_generation + 1,
    sync_purged_at = timezone('utc'::text, now()),
    sync_enabled = FALSE
WHERE id = '$USER_ID';
COMMIT;
" &
PID_PURGE=$!

# Foreground Job B: Wait for Job A to hold FOR UPDATE lock, then attempt to insert with old generation 2.
# Trigger tr_validate_synced_report_write will block on FOR SHARE until Purge commits.
# Once Purge commits, trigger unblocks, sees generation is now 3 and sync is disabled, and raises exception.
sleep 0.5
set +e
ERROR_OUTPUT=$(psql_cmd -c "
SELECT auth.set_test_user('$USER_ID'::uuid, 'authenticated');
INSERT INTO public.synced_reports (
    user_id, client_report_id, snapshot_id, sync_generation, report_payload, client_updated_at
) VALUES (
    '$USER_ID', 'rep-stale-002', 'snap-002', 2,
    '{\"formatVersion\": 1, \"outcomeState\": \"cautious\", \"hasAiAnalysis\": false, \"indicatorCount\": 0, \"categories\": [], \"source\": \"messageText\"}'::jsonb,
    now()
);
" 2>&1)
PSQL_EXIT_CODE=$?
set -e

wait $PID_PURGE

if [ $PSQL_EXIT_CODE -eq 0 ]; then
  echo "FAIL: Concurrent upload unexpectedly succeeded!"
  exit 1
fi

if ! echo "$ERROR_OUTPUT" | grep -qE "(Stale generation|Sync opt-in required)"; then
  echo "FAIL: Concurrent upload was rejected but with unexpected error: $ERROR_OUTPUT"
  exit 1
fi

REPORT_COUNT_2=$(psql_cmd -t -A -c "SELECT count(*) FROM public.synced_reports WHERE user_id = '$USER_ID';")
echo "Scenario 2 Result: reports=$REPORT_COUNT_2"
if [ "$REPORT_COUNT_2" -ne 0 ]; then
  echo "FAIL: Stale report was inserted during concurrent purge in Scenario 2!"
  exit 1
fi
echo "PASS: Scenario 2 verified. Concurrent upload blocked on purge lock and was cleanly rejected."

echo "=== All Concurrent Upload/Purge Race Tests PASSED Successfully ==="

