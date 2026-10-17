import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/data/services/analysis_api_client.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_execution_context.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_service.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_coverage_info.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_indicator_group.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/category_educational_context.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/upload_consent.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import '../../../auth/mocks/fake_auth_repository.dart';

class _FakeEngine implements AnalysisService {
  final Future<Result<AnalysisReport>> Function(TextSnapshot snapshot)?
  onAnalyze;

  _FakeEngine({this.onAnalyze});

  @override
  Future<Result<AnalysisReport>> analyze(TextSnapshot snapshot) async {
    if (onAnalyze != null) return onAnalyze!(snapshot);
    return Result.success(
      AnalysisReport(
        id: 'rep-1',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 1, 1),
        findings: const [],
        limitations: const [],
        suggestedActions: const [],
      ),
    );
  }
}

class _FakeSynthesizer implements AssessmentSynthesizer {
  final Result<LocalAssessment> Function(
    AnalysisReport report,
    AnalysisExecutionContext context,
  )?
  onSynthesize;

  _FakeSynthesizer({this.onSynthesize});

  @override
  Result<LocalAssessment> synthesize({
    required AnalysisReport report,
    required AnalysisExecutionContext executionContext,
  }) {
    if (onSynthesize != null) return onSynthesize!(report, executionContext);
    return Result.success(
      LocalAssessment(
        reportId: report.id,
        snapshotId: report.snapshot.id,
        snapshotSource: report.snapshot.source,
        outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
        factualSummary: 'No indicators were matched.',
        groupedIndicators: const [],
        coverageInfo: AssessmentCoverageInfo(
          executedRuleIds: const ['rule-1'],
          evaluatedCategories: const [IndicatorCategory.requestsForCredentials],
        ),
        uncertaintyNotes: const ['Sample note'],
        actionableSteps: const [],
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }
}

ReviewedTextResult _createSampleReviewResult({
  String text = 'Your bank account is locked. Send password.',
  String snapshotId = 'snap-1',
}) {
  final snapshot = TextSnapshot(
    id: snapshotId,
    text: text,
    source: InputSource.messageText,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  return ReviewedTextResult(
    snapshot: snapshot,
    sourceSnapshotId: 'src-1',
    sourceRevision: 'rev-1',
    reviewedAt: DateTime.utc(2026, 1, 1),
  );
}

LocalAssessment _createSampleAssessment({
  required AssessmentOutcomeState outcomeState,
  required String snapshotId,
  List<AssessmentIndicatorGroup> groups = const [],
}) {
  return LocalAssessment(
    reportId: 'rep-1',
    snapshotId: snapshotId,
    snapshotSource: InputSource.messageText,
    outcomeState: outcomeState,
    factualSummary: outcomeState == AssessmentOutcomeState.indicatorsDetected
        ? 'Identified 1 indicator.'
        : 'No indicators matched.',
    groupedIndicators: groups,
    coverageInfo: AssessmentCoverageInfo(
      executedRuleIds: const ['rule.credential_request'],
      evaluatedCategories: const [IndicatorCategory.requestsForCredentials],
    ),
    uncertaintyNotes: const ['Local on-device pattern matching only.'],
    actionableSteps: [
      AssessmentAction(
        id: 'action.protect_credentials',
        title: 'Do not disclose passwords',
        description:
            'Never share passwords in response to unexpected messages.',
        priority: AssessmentActionPriority.immediate,
        supportingFindingIds: const ['f-1'],
        supportingCategoryIds: const ['requests_for_credentials'],
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  tearDown(() {
    Get.reset();
  });

  group('AnalysisResultsController Lifecycle & State', () {
    test(
      'missing route arguments transitions to failedOrUnsupported',
      () async {
        final pipeline = LocalAnalysisPipeline(
          engine: _FakeEngine(),
          synthesizer: _FakeSynthesizer(),
          registry: LocalRuleCatalog.createRegistry(),
        );

        final controller = AnalysisResultsController(
          pipeline: pipeline,
          args: null,
        );
        controller.onInit();

        expect(controller.state.value, AnalysisState.failedOrUnsupported);
        expect(controller.errorMessage.value, contains('missing or invalid'));
        expect(controller.assessment.value, isNull);
      },
    );

    test('invalid review result transitions to failedOrUnsupported', () async {
      final pipeline = LocalAnalysisPipeline(
        engine: _FakeEngine(),
        synthesizer: _FakeSynthesizer(),
        registry: LocalRuleCatalog.createRegistry(),
      );

      // Snapshot with empty text
      final invalidSnapshot = TextSnapshot(
        id: 'snap-empty',
        text: '',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final invalidReview = ReviewedTextResult(
        snapshot: invalidSnapshot,
        sourceSnapshotId: 'src-1',
        sourceRevision: 'rev-1',
        reviewedAt: DateTime.utc(2026, 1, 1),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: invalidReview),
      );
      controller.onInit();

      expect(controller.state.value, AnalysisState.failedOrUnsupported);
      expect(controller.errorMessage.value, contains('missing or invalid'));
    });

    test('successful analysis with indicators transitions to completedWithIndicators', () async {
      final review = _createSampleReviewResult();
      final finding = AnalysisFinding(
        id: 'f-1',
        category: 'requests_for_credentials',
        explanation: 'Requests password.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.credential_request',
        evidence: [
          EvidenceReference(
            snapshotId: review.snapshot.id,
            startOffset: 34,
            endOffset: 42,
            exactExcerpt: 'password',
          ),
        ],
      );
      final group = AssessmentIndicatorGroup(
        categoryId: 'requests_for_credentials',
        category: IndicatorCategory.requestsForCredentials,
        categoryLabel: 'Requests for credentials',
        findings: [finding],
        educationalContext: const CategoryEducationalContext(
          id: 'edu.credential_request',
          categoryId: 'requests_for_credentials',
          whatObserved: 'Password request pattern',
          whyAttention: 'Organizations rarely ask for credentials in chat',
          whatCannotEstablish: 'Does not establish sender identity',
          independentVerificationStep: 'Use known official channels',
        ),
      );

      final expectedAssessment = _createSampleAssessment(
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        snapshotId: review.snapshot.id,
        groups: [group],
      );

      final pipeline = LocalAnalysisPipeline(
        engine: _FakeEngine(),
        synthesizer: _FakeSynthesizer(
          onSynthesize: (report, ctx) => Result.success(expectedAssessment),
        ),
        registry: LocalRuleCatalog.createRegistry(),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: review),
      );
      controller.onInit();

      await Future<void>.delayed(Duration.zero);

      expect(controller.state.value, AnalysisState.completedWithIndicators);
      expect(controller.assessment.value, equals(expectedAssessment));
      expect(controller.errorMessage.value, isNull);
    });

    test('successful analysis with no matches transitions to completedWithNoMatches', () async {
      final review = _createSampleReviewResult(
        text: 'Meeting at 3pm tomorrow in room 204.',
      );
      final expectedAssessment = _createSampleAssessment(
        outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
        snapshotId: review.snapshot.id,
      );

      final pipeline = LocalAnalysisPipeline(
        engine: _FakeEngine(),
        synthesizer: _FakeSynthesizer(
          onSynthesize: (report, ctx) => Result.success(expectedAssessment),
        ),
        registry: LocalRuleCatalog.createRegistry(),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: review),
      );
      controller.onInit();

      await Future<void>.delayed(Duration.zero);

      expect(controller.state.value, AnalysisState.completedWithNoMatches);
      expect(
        controller.assessment.value?.outcomeState,
        AssessmentOutcomeState.noIndicatorsMatched,
      );
    });

    test('pipeline failure transitions to failedOrUnsupported', () async {
      final review = _createSampleReviewResult();
      final pipeline = LocalAnalysisPipeline(
        engine: _FakeEngine(
          onAnalyze: (snap) async => Result.failure(
            AnalysisFailure.unsupportedInput(
              'Input message contains unsupported encoding.',
              'encoding_error',
            ),
          ),
        ),
        synthesizer: _FakeSynthesizer(),
        registry: LocalRuleCatalog.createRegistry(),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: review),
      );
      controller.onInit();

      await Future<void>.delayed(Duration.zero);

      expect(controller.state.value, AnalysisState.failedOrUnsupported);
      expect(controller.errorMessage.value, contains('unsupported encoding'));
      expect(controller.assessment.value, isNull);
    });

    test('stale result is ignored if controller is closed before pipeline finishes', () async {
      final review = _createSampleReviewResult();
      final completer = Completer<Result<AnalysisReport>>();

      final pipeline = LocalAnalysisPipeline(
        engine: _FakeEngine(onAnalyze: (snap) => completer.future),
        synthesizer: _FakeSynthesizer(),
        registry: LocalRuleCatalog.createRegistry(),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: review),
      );
      controller.onInit();

      expect(controller.state.value, AnalysisState.running);

      // Dispose controller while operation is in-flight
      controller.onClose();

      // Now complete the pipeline
      completer.complete(
        Result.success(
          AnalysisReport(
            id: 'rep-late',
            snapshot: review.snapshot,
            analyzedAt: DateTime.utc(2026, 1, 1),
            findings: const [],
            limitations: const [],
            suggestedActions: const [],
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);

      // Controller should not have mutated its disposed state
      expect(controller.assessment.value, isNull);
    });

    test('retryAnalysis restarts analysis when previous run failed', () async {
      final review = _createSampleReviewResult();
      var attempts = 0;

      final pipeline = LocalAnalysisPipeline(
        engine: _FakeEngine(
          onAnalyze: (snap) async {
            attempts++;
            if (attempts == 1) {
              return Result.failure(
                AnalysisFailure.malformedData('Transient failure', 'transient'),
              );
            }
            return Result.success(
              AnalysisReport(
                id: 'rep-retry',
                snapshot: snap,
                analyzedAt: DateTime.utc(2026, 1, 1),
                findings: const [],
                limitations: const [],
                suggestedActions: const [],
              ),
            );
          },
        ),
        synthesizer: _FakeSynthesizer(),
        registry: LocalRuleCatalog.createRegistry(),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: review),
      );
      controller.onInit();

      await Future<void>.delayed(Duration.zero);
      expect(controller.state.value, AnalysisState.failedOrUnsupported);
      expect(attempts, 1);

      // Trigger retry
      controller.retryAnalysis();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.value, AnalysisState.completedWithNoMatches);
      expect(attempts, 2);
    });
  });

  group('AnalysisResultsController Cloud AI Tests', () {
    late LocalAnalysisPipeline dummyPipeline;
    late ReviewedTextResult reviewResult;

    setUp(() {
      dummyPipeline = LocalAnalysisPipeline(
        engine: _FakeEngine(),
        synthesizer: _FakeSynthesizer(),
        registry: LocalRuleCatalog.createRegistry(),
      );
      reviewResult = _createSampleReviewResult();
    });

    testWidgets(
      'unauthenticated user requesting AI transitions to failed with sign-in notice',
      (tester) async {
        final fakeAuth = FakeAuthRepository(
          initialStatus: AuthStatus.unauthenticated,
        );

        final controller = AnalysisResultsController(
          pipeline: dummyPipeline,
          args: AnalysisResultsArgs(reviewResult: reviewResult),
          authRepository: fakeAuth,
        );
        controller.onInit();
        await tester.pump();

        // Verify local assessment completes first
        expect(controller.state.value, AnalysisState.completedWithNoMatches);
        expect(controller.assessment.value, isNotNull);
        expect(controller.aiState.value, AiAnalysisState.idle);

        // Create a dummy context for the call
        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.requestAiAnalysis(context);
              return const SizedBox.shrink();
            },
          ),
        );
        await tester.pump();

        // AI state transitions to failed, but local assessment remains intact!
        expect(controller.aiState.value, AiAnalysisState.failed);
        expect(
          controller.aiErrorMessage.value,
          contains('requires an authenticated account'),
        );
        expect(controller.assessment.value, isNotNull);
        expect(controller.state.value, AnalysisState.completedWithNoMatches);
      },
    );

    testWidgets(
      'authenticated user with valid consent executes AI analysis successfully',
      (tester) async {
        final fakeAuth = FakeAuthRepository(
          initialStatus: AuthStatus.authenticated,
          initialUser: AuthUser(
            id: 'user-auth-123',
            email: 'test@trustcue.app',
            emailVerified: true,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );

        final fakeApiClient = _FakeAnalysisApiClient();

        final controller = AnalysisResultsController(
          pipeline: dummyPipeline,
          args: AnalysisResultsArgs(reviewResult: reviewResult),
          authRepository: fakeAuth,
          apiClient: fakeApiClient,
        );
        controller.onInit();
        await tester.pump();

        // Pre-seed affirmative consent
        controller.currentConsent.value = UploadConsent.affirmative(
          snapshot: reviewResult.snapshot,
          accountId: 'user-auth-123',
        );

        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.requestAiAnalysis(context);
              return const SizedBox.shrink();
            },
          ),
        );
        await tester.pump();

        expect(controller.aiState.value, AiAnalysisState.completed);
        expect(controller.aiReport.value?.reportId, equals('rep-ai-test'));
        expect(controller.assessment.value, isNotNull);
      },
    );

    testWidgets(
      'server failure transitions aiState to failed and preserves local assessment',
      (tester) async {
        final fakeAuth = FakeAuthRepository(
          initialStatus: AuthStatus.authenticated,
          initialUser: AuthUser(
            id: 'user-auth-123',
            email: 'test@trustcue.app',
            emailVerified: true,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );

        final fakeApiClient = _FakeAnalysisApiClient(
          onAnalyzeWithAi:
              ({
                required snapshot,
                required consent,
                required sourceRevision,
                currentAccountId,
              }) async {
                return const Result.failure(
                  AnalysisFailure.unavailable('Server connection lost.'),
                );
              },
        );

        final controller = AnalysisResultsController(
          pipeline: dummyPipeline,
          args: AnalysisResultsArgs(reviewResult: reviewResult),
          authRepository: fakeAuth,
          apiClient: fakeApiClient,
        );
        controller.onInit();
        await tester.pump();

        controller.currentConsent.value = UploadConsent.affirmative(
          snapshot: reviewResult.snapshot,
          accountId: 'user-auth-123',
        );

        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.requestAiAnalysis(context);
              return const SizedBox.shrink();
            },
          ),
        );
        await tester.pump();

        expect(controller.aiState.value, AiAnalysisState.failed);
        expect(
          controller.aiErrorMessage.value,
          equals('Server connection lost.'),
        );
        // Local assessment is preserved
        expect(controller.assessment.value, isNotNull);
      },
    );

    test('invalidateConsent resets consent, report, and aiState', () {
      final controller = AnalysisResultsController(
        pipeline: dummyPipeline,
        args: AnalysisResultsArgs(reviewResult: reviewResult),
      );

      controller.currentConsent.value = UploadConsent.affirmative(
        snapshot: reviewResult.snapshot,
        accountId: 'user-123',
      );
      controller.aiState.value = AiAnalysisState.completed;
      controller.aiReport.value = AiAnalysisReport(
        reportId: 'rep-test',
        snapshotId: reviewResult.snapshot.id,
        provider: 'groq',
        model: 'qwen',
        analyzedAt: DateTime.utc(2026, 1, 1),
        factualSummary: 'summary',
        findings: const [],
        uncertaintyNotes: const [],
        suggestedActions: const [],
      );

      controller.invalidateConsent();

      expect(controller.currentConsent.value, isNull);
      expect(controller.aiReport.value, isNull);
      expect(controller.aiState.value, equals(AiAnalysisState.idle));
      expect(controller.aiErrorMessage.value, isNull);
    });

    testWidgets(
      'invalidates AI results and clears consent when auth status/account changes',
      (tester) async {
        final authRepo = FakeAuthRepository(
          initialStatus: AuthStatus.authenticated,
          initialUser: AuthUser(
            id: 'user-original',
            email: 'orig@trustcue.com',
            emailVerified: true,
            createdAt: DateTime.now(),
          ),
        );

        final controller = AnalysisResultsController(
          pipeline: dummyPipeline,
          args: AnalysisResultsArgs(reviewResult: reviewResult),
          authRepository: authRepo,
          apiClient: _FakeAnalysisApiClient(),
        );
        controller.onInit();
        await tester.pump();

        controller.currentConsent.value = UploadConsent.affirmative(
          snapshot: reviewResult.snapshot,
          accountId: 'user-original',
        );
        controller.aiState.value = AiAnalysisState.completed;
        controller.aiReport.value = AiAnalysisReport(
          reportId: 'rep-test',
          snapshotId: reviewResult.snapshot.id,
          provider: 'groq',
          model: 'qwen',
          analyzedAt: DateTime.utc(2026, 1, 1),
          factualSummary: 'summary',
          findings: const [],
          uncertaintyNotes: const [],
          suggestedActions: const [],
        );

        // User logs out or changes account
        authRepo.setStatus(AuthStatus.unauthenticated, user: null);
        await tester.pump();

        expect(controller.currentConsent.value, isNull);
        expect(controller.aiReport.value, isNull);
        expect(controller.aiState.value, equals(AiAnalysisState.idle));

        controller.onClose();
      },
    );
  });
}

class _FakeAnalysisApiClient extends AnalysisApiClient {
  final Future<Result<AiAnalysisReport>> Function({
    required TextSnapshot snapshot,
    required UploadConsent consent,
    required String sourceRevision,
    String? currentAccountId,
  })?
  onAnalyzeWithAi;

  _FakeAnalysisApiClient({this.onAnalyzeWithAi})
    : super(tokenProvider: () async => 'valid-token');

  @override
  Future<Result<AiAnalysisReport>> analyzeWithAi({
    required TextSnapshot snapshot,
    required UploadConsent consent,
    required String sourceRevision,
    String? currentAccountId,
  }) async {
    if (onAnalyzeWithAi != null) {
      return onAnalyzeWithAi!(
        snapshot: snapshot,
        consent: consent,
        sourceRevision: sourceRevision,
        currentAccountId: currentAccountId,
      );
    }
    return Result.success(
      AiAnalysisReport(
        reportId: 'rep-ai-test',
        snapshotId: snapshot.id,
        provider: 'groq',
        model: 'qwen/qwen3.8-27b',
        analyzedAt: DateTime.utc(2026, 1, 1),
        factualSummary: 'AI test summary',
        findings: const [],
        uncertaintyNotes: const ['Note 1'],
        suggestedActions: const [],
      ),
    );
  }
}
