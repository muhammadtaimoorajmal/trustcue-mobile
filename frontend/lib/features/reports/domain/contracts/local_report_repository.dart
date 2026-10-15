import 'package:trustcue_mobile/core/types/result.dart';
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
  /// Overwriting an existing report with a conflicting/different snapshot is strictly rejected.
  Future<Result<SavedReport>> saveReport(SavedReport report);

  /// Retrieves a full [SavedReport] by its unique [id], including reconstructed findings
  /// and verified reviewed text snapshot.
  ///
  /// Returns `null` if the report does not exist.
  /// Returns a failure if the record is corrupt, unsupported, or fails snapshot validation.
  Future<Result<SavedReport?>> getReportById(String id);

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

  /// Deletes the report identified by [id] and cleans up its snapshot if unreferenced.
  ///
  /// Returns `true` if a record was deleted, `false` if not found.
  Future<Result<bool>> deleteReport(String id);

  /// Returns the total count of saved reports, optionally filtered by [accountId].
  Future<Result<int>> getReportCount({String? accountId});

  /// Releases database connections and resources cleanly.
  Future<void> close();
}
