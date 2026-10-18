import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/auth/data/services/account_api_client.dart';
import 'package:trustcue_mobile/features/auth/domain/models/user_profile.dart';
import 'package:trustcue_mobile/features/reports/data/serialization/cloud_report_summary_codec.dart';
import 'package:trustcue_mobile/features/reports/data/services/sync_api_client.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/cloud_sync_models.dart';

class SyncCycleResult {
  final int pushedCount;
  final int pulledCount;
  final int tombstonesApplied;
  final bool success;
  final String? message;
  final DateTime syncTime;

  const SyncCycleResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.tombstonesApplied,
    required this.success,
    this.message,
    required this.syncTime,
  });
}

/// Orchestrator service for Module 39 Cloud Report Synchronization.
///
/// Invariants:
/// - Sync is strictly disabled by default.
/// - Requires explicit user opt-in (`syncEnabled = true`).
/// - Strictly sanitizes payloads: zero raw message text, zero OCR, zero excerpts.
/// - Only manages account-scoped reports; guest reports are never uploaded.
class ReportSyncService {
  final LocalReportRepository repository;
  final SyncApiClient syncApiClient;
  final AccountApiClient accountApiClient;
  final CloudReportSummaryCodec summaryCodec;

  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  ReportSyncService({
    required this.repository,
    required this.syncApiClient,
    required this.accountApiClient,
    this.summaryCodec = const CloudReportSummaryCodec(),
  });

  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;

  /// Executes a full synchronization cycle (push pending local changes, pull remote tombstones/updates).
  Future<Result<SyncCycleResult>> synchronize({
    required String accountId,
    required bool syncEnabled,
    int syncGeneration = 1,
  }) async {
    if (!syncEnabled) {
      return Result.success(
        SyncCycleResult(
          pushedCount: 0,
          pulledCount: 0,
          tombstonesApplied: 0,
          success: true,
          message: 'Cloud sync is disabled.',
          syncTime: DateTime.now().toUtc(),
        ),
      );
    }

    if (_isSyncing) {
      return const Result.failure(
        AnalysisFailure.storage(
          'A synchronization cycle is already in progress.',
        ),
      );
    }

    _isSyncing = true;

    try {
      // 1. Collect pending uploads and pending tombstones
      final pendingUploadsRes = await repository
          .getPendingUploadReportSummaries(accountId);
      if (pendingUploadsRes.isFailure) {
        return Result.failure(pendingUploadsRes.failureOrNull!);
      }
      final pendingUploads = pendingUploadsRes.valueOrNull!;

      final pendingTombstonesRes = await repository.getPendingTombstones(
        accountId,
      );
      if (pendingTombstonesRes.isFailure) {
        return Result.failure(pendingTombstonesRes.failureOrNull!);
      }
      final pendingTombstones = pendingTombstonesRes.valueOrNull!;

      // 2. Prepare cloud items
      final itemsToPush = <CloudReportItem>[];
      final uploadIds = <String>[];

      for (final summary in pendingUploads) {
        final payload = summaryCodec.encodeSummary(summary);
        itemsToPush.add(
          CloudReportItem(
            clientReportId: summary.id,
            snapshotId: summary.snapshotId,
            schemaVersion: summary.schemaVersion,
            syncGeneration: syncGeneration,
            reportPayload: payload,
            isDeleted: false,
            clientUpdatedAt: summary.savedAt,
          ),
        );
        uploadIds.add(summary.id);
      }

      for (final tombId in pendingTombstones) {
        final now = DateTime.now().toUtc();
        itemsToPush.add(
          CloudReportItem(
            clientReportId: tombId,
            snapshotId: 'tombstone',
            schemaVersion: 1,
            syncGeneration: syncGeneration,
            reportPayload: const {
              'formatVersion': 1,
              'outcomeState': 'cautious',
            },
            isDeleted: true,
            deletedAt: now,
            clientUpdatedAt: now,
          ),
        );
      }

      int pushedCount = 0;
      if (itemsToPush.isNotEmpty) {
        final pushRes = await syncApiClient.pushReports(itemsToPush);
        if (pushRes.isFailure) {
          return Result.failure(pushRes.failureOrNull!);
        }
        final pushResult = pushRes.valueOrNull!;
        pushedCount = pushResult.acceptedCount;

        // Mark local records as synced
        if (uploadIds.isNotEmpty) {
          await repository.markReportsSynced(
            accountId,
            uploadIds,
            pushResult.serverTimestamp,
          );
        }
        if (pendingTombstones.isNotEmpty) {
          await repository.clearTombstones(accountId, pendingTombstones);
        }
      }

      // 3. Pull remote updates
      final pullRes = await syncApiClient.pullReports(since: _lastSyncTime);
      int pulledCount = 0;
      int tombstonesApplied = 0;

      if (pullRes.isSuccess) {
        final pullResult = pullRes.valueOrNull!;
        pulledCount = pullResult.reports.length;

        for (final remoteRecord in pullResult.reports) {
          if (remoteRecord.isDeleted) {
            await repository.applyRemoteTombstone(
              accountId,
              remoteRecord.clientReportId,
            );
            tombstonesApplied++;
          }
        }
        _lastSyncTime = pullResult.serverTimestamp;
      } else if (itemsToPush.isEmpty) {
        // If neither push nor pull succeeded, bubble up failure
        return Result.failure(pullRes.failureOrNull!);
      }

      return Result.success(
        SyncCycleResult(
          pushedCount: pushedCount,
          pulledCount: pulledCount,
          tombstonesApplied: tombstonesApplied,
          success: true,
          syncTime: _lastSyncTime ?? DateTime.now().toUtc(),
        ),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage('Unexpected error during synchronization: $e'),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Toggles cloud synchronization in the user's remote profile.
  ///
  /// Optionally purges existing cloud backup records when disabling.
  Future<Result<UserProfile>> setCloudSyncEnabled({
    required bool enabled,
    bool purgeCloud = false,
    String? accountId,
  }) async {
    if (!enabled && purgeCloud && accountId != null) {
      await purgeCloudBackups(accountId: accountId);
    }

    final updateRes = await accountApiClient.updateProfile(
      syncEnabled: enabled,
    );
    if (updateRes.isSuccess && enabled && accountId != null) {
      // Trigger initial sync upon enabling
      await synchronize(accountId: accountId, syncEnabled: true);
    }
    return updateRes;
  }

  /// Purges all cloud-backed report summaries for the specified account.
  Future<Result<int>> purgeCloudBackups({required String accountId}) async {
    final purgeRes = await syncApiClient.purgeSyncedReports();
    if (purgeRes.isFailure) {
      return Result.failure(purgeRes.failureOrNull!);
    }

    await repository.clearSyncMetadata(accountId);
    _lastSyncTime = null;
    return Result.success(purgeRes.valueOrNull!.purgedCount);
  }
}
