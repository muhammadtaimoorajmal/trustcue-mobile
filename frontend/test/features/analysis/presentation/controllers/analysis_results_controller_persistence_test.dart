import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

import '../../../auth/mocks/fake_auth_repository.dart';

class FakeLocalReportRepository implements LocalReportRepository {
  final Map<String, SavedReport> storage = {};
  bool shouldFailSave = false;
  String failureMessage = 'Simulated database disk full failure.';
  int saveCallCount = 0;

  @override
  Future<Result<void>> initialize() async => const Result.success(null);

  @override
  Future<Result<SavedReport>> saveReport(SavedReport report) async {
    saveCallCount++;
    if (shouldFailSave) {
      return Result.failure(AnalysisFailure.storage(failureMessage));
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
  }) async => const Result.success([]);

  @override
  Future<Result<List<SavedReportSummary>>> searchReportSummaries({
    required String query,
    String? accountId,
    InputSource? inputSource,
    bool? hasAiAnalysis,
    int limit = 50,
    int offset = 0,
  }) async => const Result.success([]);

  @override
  Future<Result<bool>> deleteReport(
    String id, {
    String? accountId,
    bool enforceAccountScope = false,
  }) async {
    final report = storage[id];
    if (report == null) return const Result.success(false);
    if (enforceAccountScope && report.accountId != accountId) {
      return const Result.success(false);
    }
    storage.remove(id);
    return const Result.success(true);
  }

  @override
  Future<Result<int>> getReportCount({
    String? accountId,
    String? query,
    InputSource? inputSource,
    bool? hasAiAnalysis,
  }) async => Result.success(storage.length);

  @override
  Future<void> close() async {}
}

void main() {
  group('AnalysisResultsController Persistence Tests', () {
    late LocalAnalysisPipeline pipeline;
    late TextSnapshot snapshot;
    late ReviewedTextResult reviewResult;
    late FakeLocalReportRepository fakeReportRepo;
    late FakeAuthRepository fakeAuthRepo;

    setUp(() {
      final registry = LocalRuleCatalog.createRegistry();
      final engine = LocalRuleEngine(registry: registry);
      final synthesizer = LocalAssessmentSynthesizer();
      pipeline = LocalAnalysisPipeline(
        engine: engine,
        synthesizer: synthesizer,
        registry: registry,
      );

      snapshot = TextSnapshot(
        id: 'snap-ctrl-001',
        text: 'Urgent: Your account is suspended. Send funds immediately.',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      reviewResult = ReviewedTextResult(
        snapshot: snapshot,
        sourceSnapshotId: 'src-1',
        sourceRevision: 'rev-1',
        reviewedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      fakeReportRepo = FakeLocalReportRepository();
      fakeAuthRepo = FakeAuthRepository();
    });

    test('initializes with notSaved status', () async {
      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: reviewResult),
        reportRepository: fakeReportRepo,
        authRepository: fakeAuthRepo,
      );

      expect(controller.saveStatus.value, equals(ReportSaveStatus.notSaved));
      expect(controller.isSaving.value, isFalse);
      expect(controller.saveErrorMessage.value, isNull);
    });

    test(
      'saveReportOnDevice successfully persists report for guest user',
      () async {
        final controller = AnalysisResultsController(
          pipeline: pipeline,
          args: AnalysisResultsArgs(reviewResult: reviewResult),
          reportRepository: fakeReportRepo,
          authRepository: fakeAuthRepo,
        );

        await controller.startAnalysis();
        expect(controller.assessment.value, isNotNull);

        await controller.saveReportOnDevice();

        expect(controller.saveStatus.value, equals(ReportSaveStatus.saved));
        expect(controller.isSaving.value, isFalse);
        expect(fakeReportRepo.saveCallCount, equals(1));

        final saved = fakeReportRepo.storage.values.first;
        expect(saved.accountId, isNull); // Guest mode
        expect(saved.snapshot.id, equals('snap-ctrl-001'));
        expect(saved.totalFindingsCount, greaterThan(0));
      },
    );

    test(
      'saveReportOnDevice associates report with authenticated user ID',
      () async {
        fakeAuthRepo.setStatus(
          AuthStatus.authenticated,
          user: AuthUser(
            id: 'authenticated-user-uuid',
            email: 'user@example.com',
            emailVerified: true,
            createdAt: DateTime.utc(2026, 10, 15),
          ),
        );

        final controller = AnalysisResultsController(
          pipeline: pipeline,
          args: AnalysisResultsArgs(reviewResult: reviewResult),
          reportRepository: fakeReportRepo,
          authRepository: fakeAuthRepo,
        );

        await controller.startAnalysis();
        await controller.saveReportOnDevice();

        expect(controller.saveStatus.value, equals(ReportSaveStatus.saved));
        final saved = fakeReportRepo.storage.values.first;
        expect(saved.accountId, equals('authenticated-user-uuid'));
      },
    );

    test('save failure transitions to failed state and preserves results on screen', () async {
      fakeReportRepo.shouldFailSave = true;

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: reviewResult),
        reportRepository: fakeReportRepo,
        authRepository: fakeAuthRepo,
      );

      await controller.startAnalysis();
      final assessmentBeforeSave = controller.assessment.value;
      expect(assessmentBeforeSave, isNotNull);

      await controller.saveReportOnDevice();

      expect(controller.saveStatus.value, equals(ReportSaveStatus.failed));
      expect(
        controller.saveErrorMessage.value,
        contains('Simulated database disk full failure.'),
      );
      // Invariant: Assessment results are 100% preserved
      expect(controller.assessment.value, equals(assessmentBeforeSave));

      // Retry after resolving failure
      fakeReportRepo.shouldFailSave = false;
      await controller.saveReportOnDevice();

      expect(controller.saveStatus.value, equals(ReportSaveStatus.saved));
      expect(controller.saveErrorMessage.value, isNull);
    });

    test('starting fresh analysis resets save status to notSaved', () async {
      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: reviewResult),
        reportRepository: fakeReportRepo,
        authRepository: fakeAuthRepo,
      );

      await controller.startAnalysis();
      await controller.saveReportOnDevice();
      expect(controller.saveStatus.value, equals(ReportSaveStatus.saved));

      // Re-trigger analysis
      await controller.startAnalysis();
      expect(controller.saveStatus.value, equals(ReportSaveStatus.notSaved));
    });
  });
}
