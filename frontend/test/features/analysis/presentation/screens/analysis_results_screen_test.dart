import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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
import 'package:trustcue_mobile/features/analysis/presentation/screens/analysis_results_screen.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

class _MockEngine implements AnalysisService {
  @override
  Future<Result<AnalysisReport>> analyze(TextSnapshot snapshot) async {
    return Result.success(
      AnalysisReport(
        id: 'rep-mock',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 1, 1),
        findings: const [],
        limitations: const [],
        suggestedActions: const [],
      ),
    );
  }
}

class _MockSynthesizer implements AssessmentSynthesizer {
  final LocalAssessment assessment;

  _MockSynthesizer(this.assessment);

  @override
  Result<LocalAssessment> synthesize({
    required AnalysisReport report,
    required AnalysisExecutionContext executionContext,
  }) {
    return Result.success(assessment);
  }
}

ReviewedTextResult _makeReview(String text) {
  final snap = TextSnapshot(
    id: 'snap-1',
    text: text,
    source: InputSource.messageText,
    createdAt: DateTime.utc(2026, 1, 1),
  );
  return ReviewedTextResult(
    snapshot: snap,
    sourceSnapshotId: 'src-1',
    sourceRevision: 'rev-1',
    reviewedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  tearDown(() {
    Get.reset();
  });

  Widget createTestWidget({
    required AnalysisResultsController controller,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    Get.put<AnalysisResultsController>(controller);
    return GetMaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const AnalysisResultsScreen(),
    );
  }

  group('AnalysisResultsScreen', () {
    testWidgets('renders indicatorsDetected state with complete hierarchy', (
      tester,
    ) async {
      final review = _makeReview(
        'Send your password immediately to avoid suspension.',
      );
      final finding = AnalysisFinding(
        id: 'f-1',
        category: 'requests_for_credentials',
        explanation: 'Requests user password.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.credential_request',
        evidence: [
          EvidenceReference(
            snapshotId: 'snap-1',
            startOffset: 10,
            endOffset: 18,
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
          id: 'edu.cred',
          categoryId: 'requests_for_credentials',
          whatObserved: 'A request for sensitive login credentials.',
          whyAttention: 'Legitimate services do not ask for passwords in unprompted messages.',
          whatCannotEstablish: 'Does not establish sender identity.',
          independentVerificationStep: 'Log in only through an official app.',
        ),
      );

      final assessment = LocalAssessment(
        reportId: 'rep-1',
        snapshotId: review.snapshot.id,
        snapshotSource: InputSource.messageText,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        factualSummary: 'Local checks identified 1 potential warning indicator: Requests for credentials.',
        groupedIndicators: [group],
        coverageInfo: AssessmentCoverageInfo(
          executedRuleIds: const ['rule.credential_request'],
          evaluatedCategories: const [IndicatorCategory.requestsForCredentials],
          skippedRuleIds: const ['rule.qr_structural'],
        ),
        uncertaintyNotes: const [
          'Local heuristic rules evaluate textual patterns.',
          'Sender identity was not verified.',
        ],
        actionableSteps: [
          AssessmentAction(
            id: 'action.protect_credentials',
            title: 'Do not disclose passwords',
            description: 'Never send your password in a message.',
            priority: AssessmentActionPriority.immediate,
            supportingFindingIds: const ['f-1'],
            supportingCategoryIds: const ['requests_for_credentials'],
          ),
        ],
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final pipeline = LocalAnalysisPipeline(
        engine: _MockEngine(),
        synthesizer: _MockSynthesizer(assessment),
        registry: LocalRuleCatalog.createRegistry(),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: review),
      );

      await tester.pumpWidget(createTestWidget(controller: controller));
      await tester.pumpAndSettle();

      // A. Header Banner
      expect(find.text('Local on-device analysis'), findsOneWidget);
      expect(
        find.text(
          'Evaluated on this device using local rules. Nothing was uploaded.',
        ),
        findsOneWidget,
      );

      // B. Outcome Summary
      expect(
        find.text('1 potential warning indicator detected'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Local checks identified 1 potential warning indicator: Requests for credentials.',
        ),
        findsOneWidget,
      );

      // C. Coverage and Limitations (with partial skipped coverage visible!)
      expect(find.text('Scope and rule coverage'), findsOneWidget);
      expect(
        find.text(
          'Partial coverage: 1 rule(s) were skipped due to input constraints.',
        ),
        findsOneWidget,
      );

      // Expand limitations
      await tester.ensureVisible(
        find.text('View limitations and uncertainty notes'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View limitations and uncertainty notes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Local heuristic rules evaluate textual patterns.'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Local heuristic rules evaluate textual patterns.'),
        findsOneWidget,
      );
      expect(find.text('Sender identity was not verified.'), findsOneWidget);

      // D. Evidence Trail
      await tester.ensureVisible(find.text('Evidence trail'));
      await tester.pumpAndSettle();
      expect(find.text('Evidence trail'), findsOneWidget);
      expect(find.text('Requests for credentials'), findsOneWidget);
      expect(find.text('What was observed:'), findsOneWidget);
      expect(
        find.text('A request for sensitive login credentials.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Rule provenance: rule.credential_request (on-device local rule)',
        ),
        findsOneWidget,
      );
      expect(find.text('"password"'), findsOneWidget);
      expect(find.text('offset [10, 18)'), findsOneWidget);
      expect(find.text('View in analyzed text'), findsOneWidget);

      // E. Suggested Next Steps
      await tester.ensureVisible(find.text('Suggested next steps'));
      await tester.pumpAndSettle();
      expect(find.text('Suggested next steps'), findsOneWidget);
      expect(find.text('Immediate protective step'), findsOneWidget);
      expect(find.text('Do not disclose passwords'), findsOneWidget);
      expect(
        find.text('Motivated by: requests_for_credentials'),
        findsOneWidget,
      );

      // F. Navigation Actions
      await tester.ensureVisible(find.text('Return to review and edit text'));
      await tester.pumpAndSettle();
      expect(find.text('Return to review and edit text'), findsOneWidget);
      expect(find.text('Review safe-use guidance'), findsOneWidget);

      // Ensure no nonfunctional Save, Share, AI, History buttons
      expect(find.text('Save report'), findsNothing);
      expect(find.text('Share report'), findsNothing);
      expect(find.text('History'), findsNothing);
    });

    testWidgets(
      'renders noIndicatorsMatched without green shield or safe verdict',
      (tester) async {
        final review = _makeReview('Hello, dinner tonight at 7?');
        final assessment = LocalAssessment(
          reportId: 'rep-no-match',
          snapshotId: review.snapshot.id,
          snapshotSource: InputSource.messageText,
          outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
          factualSummary: 'No indicators were matched by these local checks. This does not establish that the message is safe.',
          groupedIndicators: const [],
          coverageInfo: AssessmentCoverageInfo(
            executedRuleIds: const ['rule.credential_request'],
            evaluatedCategories: const [
              IndicatorCategory.requestsForCredentials,
            ],
          ),
          uncertaintyNotes: const ['Pattern matching cannot prove safety.'],
          actionableSteps: [
            AssessmentAction(
              id: 'action.general_caution',
              title: 'Verify unexpected requests independently',
              description:
                  'Always confirm requests through independent channels.',
              priority: AssessmentActionPriority.recommended,
              supportingFindingIds: const [],
              supportingCategoryIds: const [],
            ),
          ],
          createdAt: DateTime.utc(2026, 1, 1),
        );

        final pipeline = LocalAnalysisPipeline(
          engine: _MockEngine(),
          synthesizer: _MockSynthesizer(assessment),
          registry: LocalRuleCatalog.createRegistry(),
        );

        final controller = AnalysisResultsController(
          pipeline: pipeline,
          args: AnalysisResultsArgs(reviewResult: review),
        );

        await tester.pumpWidget(createTestWidget(controller: controller));
        await tester.pumpAndSettle();

        // Check for outcome title and explicit "Not a proof of safety" notice
        expect(find.text('No indicators matched'), findsOneWidget);
        expect(find.textContaining('Not a proof of safety'), findsOneWidget);

        // Verify no misleading claims
        expect(find.text('Safe'), findsNothing);
        expect(find.text('Verified safe'), findsNothing);

        // General caution action is rendered
        expect(
          find.text('Verify unexpected requests independently'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders failure state on invalid route arguments', (
      tester,
    ) async {
      final pipeline = LocalAnalysisPipeline(
        engine: _MockEngine(),
        synthesizer: _MockSynthesizer(
          LocalAssessment(
            reportId: 'r',
            snapshotId: 's',
            snapshotSource: InputSource.messageText,
            outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
            factualSummary: 'None',
            groupedIndicators: const [],
            coverageInfo: AssessmentCoverageInfo(
              executedRuleIds: const [],
              evaluatedCategories: const [],
            ),
            uncertaintyNotes: const [],
            actionableSteps: const [],
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
        registry: LocalRuleCatalog.createRegistry(),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: null, // Missing args!
      );

      await tester.pumpWidget(createTestWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Analysis unavailable'), findsOneWidget);
      expect(find.text('Return to review'), findsOneWidget);
    });

    testWidgets('supports dark theme and 200% text scale without overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;

      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final review = _makeReview('Account suspended. Verify now.');
      final assessment = LocalAssessment(
        reportId: 'rep-scale',
        snapshotId: review.snapshot.id,
        snapshotSource: InputSource.messageText,
        outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
        factualSummary: 'No indicators were matched by these local checks. This does not establish that the message is safe.',
        groupedIndicators: const [],
        coverageInfo: AssessmentCoverageInfo(
          executedRuleIds: const ['rule-1'],
          evaluatedCategories: const [
            IndicatorCategory.accountSuspensionOrThreats,
          ],
        ),
        uncertaintyNotes: const ['Limited English patterns.'],
        actionableSteps: const [],
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final pipeline = LocalAnalysisPipeline(
        engine: _MockEngine(),
        synthesizer: _MockSynthesizer(assessment),
        registry: LocalRuleCatalog.createRegistry(),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: review),
      );

      await tester.pumpWidget(
        createTestWidget(controller: controller, themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      expect(find.text('Local on-device analysis'), findsOneWidget);
      expect(find.text('No indicators matched'), findsOneWidget);
    });
  });
}
