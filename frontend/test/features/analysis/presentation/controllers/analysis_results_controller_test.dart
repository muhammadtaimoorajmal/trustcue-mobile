import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_execution_context.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_service.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/assessment_synthesizer.dart';
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
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

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
}
