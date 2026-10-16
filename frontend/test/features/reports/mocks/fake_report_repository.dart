import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

/// In-memory fake repository implementation for fast, deterministic unit & widget tests.
class FakeReportRepository implements LocalReportRepository {
  final Map<String, SavedReport> storage = {};
  bool shouldFailSave = false;
  bool shouldFailLoad = false;
  bool shouldFailDelete = false;
  String failureMessage = 'Simulated database storage error.';
  int saveCallCount = 0;
  int deleteCallCount = 0;

  @override
  Future<Result<void>> initialize() async => const Result.success(null);

  @override
  Future<Result<SavedReport>> saveReport(SavedReport report) async {
    saveCallCount++;
    if (shouldFailSave) {
      return Result.failure(AnalysisFailure.storage(failureMessage));
    }

    final existing = storage[report.id];
    if (existing != null) {
      if (existing.snapshot.id != report.snapshot.id) {
        return Result.failure(
          AnalysisFailure.storage(
            'A report with ID "${report.id}" already exists with a different snapshot.',
          ),
        );
      }
    }

    storage[report.id] = report;
    return Result.success(report);
  }

  @override
  Future<Result<SavedReport?>> getReportById(
    String id, {
    String? accountId,
    bool enforceAccountScope = false,
  }) async {
    if (shouldFailLoad) {
      return Result.failure(AnalysisFailure.storage(failureMessage));
    }

    final report = storage[id];
    if (report == null) return const Result.success(null);

    if (enforceAccountScope && report.accountId != accountId) {
      return const Result.success(null);
    }

    return Result.success(report);
  }

  @override
  Future<Result<List<SavedReportSummary>>> getReportSummaries({
    String? accountId,
    int limit = 50,
    int offset = 0,
  }) async {
    return searchReportSummaries(
      query: '',
      accountId: accountId,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Result<List<SavedReportSummary>>> searchReportSummaries({
    required String query,
    String? accountId,
    InputSource? inputSource,
    bool? hasAiAnalysis,
    int limit = 50,
    int offset = 0,
  }) async {
    if (shouldFailLoad) {
      return Result.failure(AnalysisFailure.storage(failureMessage));
    }

    final normalizedQuery = query.trim().toLowerCase();

    final filtered = storage.values.where((rep) {
      // Account scope
      if (rep.accountId != accountId) return false;

      // Input source
      if (inputSource != null && rep.snapshot.source != inputSource) {
        return false;
      }

      // Provenance
      if (hasAiAnalysis != null && rep.hasAiAnalysis != hasAiAnalysis) {
        return false;
      }

      // Search query
      if (normalizedQuery.isNotEmpty) {
        final matchesText = rep.snapshot.text.toLowerCase().contains(
          normalizedQuery,
        );
        final matchesPreview = rep.previewText.toLowerCase().contains(
          normalizedQuery,
        );
        if (!matchesText && !matchesPreview) return false;
      }

      return true;
    }).toList();

    // Sort by savedAt descending
    filtered.sort((a, b) => b.savedAt.compareTo(a.savedAt));

    final paged = filtered.skip(offset).take(limit).map((rep) {
      return SavedReportSummary(
        id: rep.id,
        schemaVersion: rep.schemaVersion,
        snapshotId: rep.snapshot.id,
        accountId: rep.accountId,
        inputSource: rep.snapshot.source,
        analyzedAt: rep.analyzedAt,
        savedAt: rep.savedAt,
        hasAiAnalysis: rep.hasAiAnalysis,
        aiProvider: rep.aiReport?.provider,
        aiModel: rep.aiReport?.model,
        findingsCount: rep.totalFindingsCount,
        outcomeState: rep.outcomeState,
        previewText: rep.previewText,
      );
    }).toList();

    return Result.success(paged);
  }

  final Set<String> syncedReportIds = {};
  final Set<String> pendingTombstoneIds = {};

  @override
  Future<Result<bool>> deleteReport(
    String id, {
    String? accountId,
    bool enforceAccountScope = false,
    bool tombstoneForCloud = false,
  }) async {
    deleteCallCount++;
    if (shouldFailDelete) {
      return Result.failure(AnalysisFailure.storage(failureMessage));
    }

    final report = storage[id];
    if (report == null) return const Result.success(false);

    if (enforceAccountScope && report.accountId != accountId) {
      return const Result.success(false);
    }

    storage.remove(id);
    syncedReportIds.remove(id);
    if (tombstoneForCloud && accountId != null) {
      pendingTombstoneIds.add(id);
    }
    return const Result.success(true);
  }

  @override
  Future<Result<int>> getReportCount({
    String? accountId,
    String? query,
    InputSource? inputSource,
    bool? hasAiAnalysis,
  }) async {
    final result = await searchReportSummaries(
      query: query ?? '',
      accountId: accountId,
      inputSource: inputSource,
      hasAiAnalysis: hasAiAnalysis,
      limit: 999999,
      offset: 0,
    );

    if (result.isFailure) {
      return Result.failure(result.failureOrNull!);
    }

    return Result.success(result.valueOrNull?.length ?? 0);
  }

  @override
  Future<Result<int>> deleteReportsForAccount(String accountId) async {
    deleteCallCount++;
    if (shouldFailDelete) {
      return Result.failure(AnalysisFailure.storage(failureMessage));
    }
    final toRemove = storage.entries
        .where((e) => e.value.accountId == accountId)
        .map((e) => e.key)
        .toList();
    for (final key in toRemove) {
      storage.remove(key);
      syncedReportIds.remove(key);
    }
    pendingTombstoneIds.clear();
    return Result.success(toRemove.length);
  }

  @override
  Future<Result<List<SavedReportSummary>>> getPendingUploadReportSummaries(
    String accountId,
  ) async {
    if (shouldFailLoad) {
      return Result.failure(AnalysisFailure.storage(failureMessage));
    }
    final pending = storage.values
        .where(
          (rep) =>
              rep.accountId == accountId && !syncedReportIds.contains(rep.id),
        )
        .map(
          (rep) => SavedReportSummary(
            id: rep.id,
            schemaVersion: rep.schemaVersion,
            snapshotId: rep.snapshot.id,
            accountId: rep.accountId,
            inputSource: rep.snapshot.source,
            analyzedAt: rep.analyzedAt,
            savedAt: rep.savedAt,
            hasAiAnalysis: rep.hasAiAnalysis,
            aiProvider: rep.aiReport?.provider,
            aiModel: rep.aiReport?.model,
            findingsCount: rep.totalFindingsCount,
            outcomeState: rep.outcomeState,
            previewText: rep.previewText,
          ),
        )
        .toList();
    return Result.success(pending);
  }

  @override
  Future<Result<List<String>>> getPendingTombstones(String accountId) async {
    if (shouldFailLoad) {
      return Result.failure(AnalysisFailure.storage(failureMessage));
    }
    return Result.success(pendingTombstoneIds.toList());
  }

  @override
  Future<Result<void>> markReportsSynced(
    String accountId,
    List<String> reportIds,
    DateTime syncedAt,
  ) async {
    syncedReportIds.addAll(reportIds);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> clearTombstones(
    String accountId,
    List<String> reportIds,
  ) async {
    pendingTombstoneIds.removeAll(reportIds);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> applyRemoteTombstone(
    String accountId,
    String reportId,
  ) async {
    final report = storage[reportId];
    if (report != null && report.accountId == accountId) {
      storage.remove(reportId);
    }
    pendingTombstoneIds.remove(reportId);
    syncedReportIds.remove(reportId);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> clearSyncMetadata(String accountId) async {
    syncedReportIds.clear();
    pendingTombstoneIds.clear();
    return const Result.success(null);
  }

  @override
  Future<void> close() async {}
}
