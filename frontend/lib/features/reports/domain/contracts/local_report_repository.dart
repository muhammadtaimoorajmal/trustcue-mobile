import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

/// Contract for pure-local report persistence and lifecycle operations on device.
///
/// Invariants & Guarantees:
/// - 100% offline; zero network calls or cloud synchronization.
/// - Operates in OS app-private storage.
/// - Atomic operations: reports and their exact snapshots are persisted within ACID transactions.
/// - Strict snapshot invariant: reports are validated against their snapshots before saving and upon loading.
/// - Safe duplicate saving: saving identical report ID and snapshot is idempotent; attempting to overwrite with a different snapshot returns an error.
/// - Guest reports are preserved offline and scoped (`accountId == null`); account reports are isolated by user UUID.
abstract class LocalReportRepository {
  /// Initializes the storage engine and applies pending schema migrations.
  Future<Result<void>> initialize();

  /// Persists a validated [report] and its associated reviewed snapshot atomically.
  ///
  /// Repeated calls with identical report ID and snapshot ID are safe and idempotent.
  /// If a report is saved with additional AI findings for the same snapshot, it safely updates
  /// the stored record. Overwriting an existing report with a different snapshot is strictly rejected.
  Future<Result<SavedReport>> saveReport(SavedReport report);

  /// Retrieves a full [SavedReport] by its unique [id], including reconstructed findings
  /// and verified reviewed text snapshot.
  ///
  /// If [enforceAccountScope] is true:
  /// - If [accountId] is null, only matches reports with `accountId == null` (guest).
  /// - If [accountId] is provided, only matches reports with matching `accountId`.
  /// Returns `null` if the report does not exist or does not match account scope.
  /// Returns a failure if the record is corrupt, unsupported, or fails snapshot validation.
  Future<Result<SavedReport?>> getReportById(
    String id, {
    String? accountId,
    bool enforceAccountScope = false,
  });

  /// Retrieves a bounded page of [SavedReportSummary] records ordered by analysis timestamp descending.
  ///
  /// Does NOT deserialize full report JSON or unredacted message text into memory.
  /// If [accountId] is provided, restricts results to reports owned by that account.
  /// If [accountId] is null, restricts results to guest reports.
  Future<Result<List<SavedReportSummary>>> getReportSummaries({
    String? accountId,
    int limit = 50,
    int offset = 0,
  });

  /// Searches saved report summaries matching [query] over reviewed text snapshots and preview text.
  ///
  /// Invariants & Guarantees:
  /// - Fully local SQLite query with parameterized `LIKE ... ESCAPE '\'`.
  /// - Wildcards (`%`, `_`, `\`) in [query] are sanitized.
  /// - Case-insensitive for 7-bit ASCII characters. Non-ASCII script matching (e.g. Urdu)
  ///   is exact/case-preserving.
  /// - Optionally filters by [inputSource] and [hasAiAnalysis].
  /// - Scoped to [accountId] (or guest if `accountId == null`).
  /// - Bounded by [limit] and [offset] without loading full payloads into memory.
  Future<Result<List<SavedReportSummary>>> searchReportSummaries({
    required String query,
    String? accountId,
    InputSource? inputSource,
    bool? hasAiAnalysis,
    int limit = 50,
    int offset = 0,
  });

  /// Deletes the report identified by [id] and cleans up its snapshot if unreferenced.
  ///
  /// If [enforceAccountScope] is true:
  /// - If [accountId] is null, only deletes reports with `accountId == null` (guest).
  /// - If [accountId] is provided, only deletes reports with matching `accountId`.
  /// If [tombstoneForCloud] is true and [accountId] is provided, records a pending
  /// tombstone in sync metadata so cloud sync purges the cloud record.
  /// Returns `true` if a record was deleted, `false` if not found or unauthorized.
  Future<Result<bool>> deleteReport(
    String id, {
    String? accountId,
    bool enforceAccountScope = false,
    bool tombstoneForCloud = false,
  });

  /// Returns the total count of saved reports, optionally filtered by [accountId],
  /// [query], [inputSource], and [hasAiAnalysis].
  Future<Result<int>> getReportCount({
    String? accountId,
    String? query,
    InputSource? inputSource,
    bool? hasAiAnalysis,
  });

  /// Permanently deletes all reports and orphan snapshots owned by [accountId].
  ///
  /// Guarantees that guest reports (`accountId == null`) and other accounts'
  /// records are strictly preserved.
  Future<Result<int>> deleteReportsForAccount(String accountId);

  /// Permanently deletes all unauthenticated guest reports (`accountId == null`).
  ///
  /// Prunes unreferenced snapshots. Does not touch authenticated account data.
  Future<Result<int>> deleteGuestReports();

  /// Prunes reports saved prior to [cutoff] according to local retention policy.
  ///
  /// Guarantees:
  /// - Prunes unreferenced snapshots.
  /// - Does NOT generate cloud tombstones (local retention pruning only).
  /// - If [accountId] is provided, only prunes reports for that account.
  /// - If [includeGuest] is true, also prunes guest reports older than [cutoff].
  Future<Result<int>> pruneReportsOlderThan(
    DateTime cutoff, {
    String? accountId,
    bool includeGuest = false,
  });

  /// Retrieves pending upload reports for the specified account.
  Future<Result<List<SavedReportSummary>>> getPendingUploadReportSummaries(
    String accountId,
  );

  /// Retrieves list of report IDs pending cloud tombstone deletion.
  Future<Result<List<String>>> getPendingTombstones(String accountId);

  /// Marks reports as successfully synced to the cloud.
  Future<Result<void>> markReportsSynced(
    String accountId,
    List<String> reportIds,
    DateTime syncedAt,
  );

  /// Clears tombstone records after successful deletion synchronization.
  Future<Result<void>> clearTombstones(
    String accountId,
    List<String> reportIds,
  );

  /// Applies a remote cloud tombstone to local storage, deleting the local report
  /// if owned by [accountId].
  Future<Result<void>> applyRemoteTombstone(String accountId, String reportId);

  /// Clears sync metadata tracking for the specified account.
  Future<Result<void>> clearSyncMetadata(String accountId);

  /// Releases database connections and resources cleanly.
  Future<void> close();
}
