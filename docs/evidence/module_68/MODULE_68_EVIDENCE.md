# Module 68 Evidence: Cross-Device Sync Conflict Resolution & Deletion Separation

**Module:** Module 68 — Cross-Device Sync Conflict Resolution & Deletion Separation, including public-project presentation cleanup  
**Date:** November 3, 2026  
**Status:** COMPLETE (Code & Tests Verified; Blockers explicitly documented)  

---

## 1. Verified Repository Baselines

| Worktree / Branch | Baseline SHA | Clean Status | Pre-Module CI Run | Module 68 SHA | Module 68 CI Run |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `trustcue-backend` (`backend`) | `a4a79fc` | Clean before edits | Run 41575460306 SUCCESS | `9c33899` | Run 41579169181 SUCCESS |
| `trustcue-database` (`database`) | `50b02fb` | Clean before edits | Run 41539459520 SUCCESS | `3a92244` | Run 41579184686 SUCCESS |
| `trustcue-mobile` (`frontend`) | Tested Code `18d69ba`, Doc `670a9ae` | Clean before edits | Run 41575306630 SUCCESS | `cf38081` | Run 41579908031 SUCCESS |
| `main` | `a785db8` | Untouched, pristine | Reserved for final integration | `a785db8` | Untouched, pristine |

---

## 2. Public-Project Presentation Cleanup & Portfolio Readiness

TrustCue is a reusable public project and professional portfolio project. Tracked files across all three repositories have been audited and cleaned of personal and academic identifiers:

1. **Academic References Removed:**
   - Terminology removed: `SAP ID 63461`, `CS3643`, `Riphah International University`, `BSCS Semester 5-1, Fall 2026`.
   - Replaced in `README.md`, `COMPLETION_REGISTER.md`, `MODULE_LOG.md`, `PROJECT_STATE.md`, `ROADMAP.md`, `docs/demo/*`, `docs/viva/*`, `docs/evidence/*`, and backend/database architecture documents with generic product and developer descriptions.
2. **Personal Email Sanitization:**
   - Personal test email (`maliktaimoor655@gmail.com` and `maliktaimoor655+m60@gmail.com`) sanitized to `test-user@example.com` and `test-user+m60@example.com` across documentation, test account references, and XML UI capture dumps.
3. **Preserved Legitimate Identifiers:**
   - Valid Git attribution preserved: `Muhammad Taimoor Ajmal`.
   - Repository remotes preserved: `https://github.com/muhammadtaimoorajmal/trustcue-mobile.git`.
   - Package identity preserved: `io.github.muhammadtaimoorajmal.trustcue`.
   - Production signing keystores and keys preserved.
4. **License Audit:**
   - Verified that NO standard `LICENSE` file exists in `trustcue-mobile`, `trustcue-backend`, or `trustcue-database`.
   - As per policy, no license has been invented. This missing file is recorded as an open decision item for the repository owner (e.g. Apache 2.0 or MIT).

---

## 3. Deletion Behavior Matrix

| Action | Local SQLite Storage | Cloud Sync (`synced_reports`) | Other Devices (e.g. Client B) | Resync / Auto-Upload Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **1. Delete device only** (`tombstoneForCloud = false`) | Report and unreferenced snapshot are permanently removed from the local device database. Sync metadata cleared. | Cloud backup summary is **preserved** on the server. | Record is **preserved** on Client B. Client B continues to see the metadata summary. | Device does NOT push a tombstone. Because local record is gone, it will not re-upload unless explicitly re-created. |
| **2. Delete device & cloud** (`tombstoneForCloud = true`) | Report and unreferenced snapshot are permanently removed from local database. A pending tombstone record (`pending_delete`) is staged in `tableSyncMetadata`. | When sync runs, pushes `isDeleted: true` to `/api/v1/sync/reports`. Server marks record as tombstone or deletes row. | When Client B synchronizes, pulls tombstone (`isDeleted: true`) and invokes `applyRemoteTombstone()`, deleting the report locally. | Tombstone is cleared from client queue once server acknowledges receipt. Report cannot be resurrected by older updates. |
| **3. Delete all cloud backups** (`purgeCloudBackups`) | Local reports remain on device intact. Local sync metadata is reset (`clearSyncMetadata`). | Server deletes all rows for `user_id` from `public.synced_reports` via PostgREST/RPC, records `sync_purged_at = now()`, and sets `sync_enabled = false`. | On other devices, cloud summaries are cleared when sync metadata is reset. | **Resurrection Prevention:** Any local reports with `clientUpdatedAt <= sync_purged_at` are rejected by the server if re-uploaded. |
| **4. Disable cloud backup** (`setCloudSyncEnabled(false)`) | Local reports remain intact on device. | Existing cloud records remain on server (unless `purgeCloud = true` is selected). Profile `sync_enabled` is set to `false`. | Other devices cannot pull or push while `sync_enabled` is false (server returns 403 `sync_opt_in_required`). | Client halts all background sync and manual push/pull cycles until user explicitly re-enables sync. |
| **5. Delete account** (`deleteAccount`) | Full account wipe: invokes `deleteReportsForAccount(accountId)`, purging all local reports and sync metadata for that account. Guest data preserved. | Server endpoint `DELETE /api/v1/account` deletes auth user, profile, private avatar storage bucket objects, and synced reports atomically. | All data permanently erased across server and devices. | Irreversible. Account tokens and hardware-backed KeyStore tokens destroyed. |

---

## 4. Two-Client Convergence Verification

Verification executed using isolated SQLite storage instances for Client A and Client B with simulated PostgREST sync server:

1. **Metadata Summary Pull & Restore:**
   - Client A created rich report with message text and local rule findings.
   - Client A synchronized, uploading allowlisted summary (formatVersion, outcomeState, hasAiAnalysis, indicatorCount, categories, source).
   - Client B (fresh client) synchronized and pulled the record via `applyRemoteReport()`.
   - Client B restored the summary into SQLite with empty snapshot text (`snapshot.text == ''`).
   - Detail screen on Client B correctly rendered the cloud summary notice (`cloud_summary_no_text_notice`) without crashing.
2. **Local Rich Report Preservation (Non-Overwriting Guarantee):**
   - When Client A ran subsequent synchronization cycles, `applyRemoteReport()` inspected existing local records.
   - Detected that Client A possesses non-empty snapshot text (`existingText.trim().isNotEmpty`).
   - Client A's rich report text and findings were **100% preserved** and never overwritten by the empty cloud stub.
3. **Duplicate Prevention:**
   - Repeated sync cycles across both Client A and Client B maintained exact record counts with zero duplicate entries.

---

## 5. Deterministic Conflict Resolution & Fallback Hardening

1. **Conflict Resolution Rules:**
   - Newer timestamp wins: updates with `clientUpdatedAt > existing.clientUpdatedAt` replace existing records.
   - Stale timestamp rejected: updates with `clientUpdatedAt < existing.clientUpdatedAt` are dropped.
   - Equal timestamps: tombstone takes precedence (`existing.isDeleted && !incoming.isDeleted` is rejected; incoming `isDeleted: true` overwrites active).
2. **Fail-Closed Backend Database Hardening:**
   - Hardened `SyncService.push_reports`, `pull_reports`, and `purge_reports` in `trustcue_backend/services/sync_service.py`.
   - When `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are configured, any PostgREST RPC, REST HTTP error, or network exception records telemetry event `database_error` and immediately raises `TrustCueError(status_code=503, code="database_error")`.
   - Completely eliminated false 200 successes, false in-memory fallback writes, and false success telemetry during database failures.
3. **Cursor Advancement Invariant:**
   - In `ReportSyncService.synchronize()`, `_lastSyncTime` (pull cursor) is updated strictly **after** all incoming records and tombstones in the batch are committed to local SQLite storage.
   - Uploaded reports are marked as synced only after server returns HTTP 200 with matching IDs.

---

## 6. Test Execution Summary

### Backend (`trustcue-backend`)
- **Ruff:** All checks passed clean.
- **Pytest:** 189 passed, 0 failed (including new conflict resolution, tombstone precedence, and 503 fail-closed database error tests).
- **GitHub Actions CI:** Run [41579169181](https://github.com/muhammadtaimoorajmal/trustcue-mobile/actions/runs/41579169181) **SUCCESS**.

### Frontend (`trustcue-mobile`)
- **Flutter Analyze:** No issues found (0 errors, 0 warnings, 0 hints).
- **Unit & Integration Suites:**
  - `sqlite_report_repository_test.dart`: 34 passed, 0 failed.
  - `report_sync_service_test.dart`: 8 passed, 0 failed.
  - `two_client_convergence_test.dart`: 3 passed, 0 failed.
  - All 100 reports tests in `test/features/reports/`: 100 passed, 0 failed.
- **GitHub Actions CI:** Run [41579908031](https://github.com/muhammadtaimoorajmal/trustcue-mobile/actions/runs/41579908031) **SUCCESS** (Format, Analyze, Automated Test Suite, and Debug APK build all passed).

### Database (`trustcue-database`)
- **Static Schema & SQL Audit:** Clean; developer identifiers sanitized.
- **GitHub Actions CI:** Run [41579184686](https://github.com/muhammadtaimoorajmal/trustcue-mobile/actions/runs/41579184686) **SUCCESS**.

---

## 7. Release Packaging & Physical Device Verification

- **Script:** `powershell trustcue-mobile/frontend/scripts/build_release.ps1 -Install`
- **Target Artifact:** `frontend/build/app/outputs/flutter-apk/app-release.apk`
- **File Size:** 112,485,629 bytes (107.27 MB)
- **SHA-256 Checksum:** `9CE5CDCD23091F757BACE3E815C298F49D0FC9335D9657F7BECBC5A24020AB47`
- **Cryptographic Signing:** Verified using APK Signature Scheme v2 via `apksigner` (1 signer, valid 4096-bit RSA certificate).
- **Target Device:** Vivo V2207 (`10AC9R1ABF0013A`, Android 14 API 34).
- **Streamed Installation:** Succeeded via `adb install -r`.
- **Launch Verification:** Injected launch intent (`monkey -p io.github.muhammadtaimoorajmal.trustcue ...`), app launched cleanly and displayed Home dashboard with zero crashes. Captured evidence in `docs/evidence/module_68/01_device_launch_after_module_68.png`.

---

## 8. Open Hosted Blockers (Carried Forward)

The following items remain strictly blocked pending human execution in the hosted Supabase environment:
1. **Hosted Migrations 00009 & 00010:**
   - File: `trustcue-database/database/migrations/HOSTED_MIGRATIONS_00009_00010.sql`.
   - Blocked: Requires execution via Supabase SQL Editor by project owner.
2. **Durable v2 Quota Store:**
   - Blocked: Awaiting application of hosted migration 00009 to enable `public.quota_reservations`.
