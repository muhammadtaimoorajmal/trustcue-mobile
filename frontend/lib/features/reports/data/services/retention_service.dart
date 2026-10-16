import 'dart:developer' as developer;

import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_preferences.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/retention_policy.dart';

/// Service coordinating local report retention and automated pruning.
///
/// Invariants & Rules:
/// - Defaults to [RetentionPolicy.never] (no silent automated deletion).
/// - Operates exclusively on local device SQLite storage; never triggers cloud deletion.
/// - Prunes unreferenced reviewed snapshots transactionally.
/// - Clock changes / time travel: if device clock is anomalous (cutoff in the future), safely aborts without data loss.
class RetentionService {
  final RetentionPreferences preferences;
  final LocalReportRepository repository;

  RetentionService({required this.preferences, required this.repository});

  /// Retrieves the active retention policy.
  Future<RetentionPolicy> getPolicy() => preferences.getRetentionPolicy();

  /// Updates the active retention policy.
  Future<void> setPolicy(RetentionPolicy policy) =>
      preferences.setRetentionPolicy(policy);

  /// Executes retention pruning based on the active policy.
  ///
  /// Returns the number of expired reports pruned from local storage.
  /// Returns 0 if policy is [RetentionPolicy.never] or if no reports exceeded cutoff.
  Future<Result<int>> pruneExpiredReports({
    DateTime? now,
    String? currentAccountId,
    bool includeGuest = true,
  }) async {
    try {
      final policy = await preferences.getRetentionPolicy();
      if (policy == RetentionPolicy.never || policy.days <= 0) {
        return const Result.success(0);
      }

      final referenceTime = now ?? DateTime.now().toUtc();
      final cutoff = referenceTime.subtract(Duration(days: policy.days));

      // Safeguard against clock tampering / backward clock shifts:
      // If cutoff computed is unexpectedly in the future, abort safely.
      if (cutoff.isAfter(referenceTime)) {
        developer.log(
          'Clock anomaly detected during retention pruning. Aborting.',
          name: 'TrustCue.Retention',
        );
        return const Result.success(0);
      }

      return await repository.pruneReportsOlderThan(
        cutoff,
        accountId: currentAccountId,
        includeGuest: includeGuest,
      );
    } catch (e) {
      developer.log(
        'Error during retention pruning: $e',
        name: 'TrustCue.Retention',
      );
      return Result.failure(
        AnalysisFailure.storage('Failed to prune expired reports: $e'),
      );
    }
  }
}
