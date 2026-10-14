import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_coverage_info.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_indicator_group.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/category_educational_context.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';

void main() {
  final testDateTime = DateTime.utc(2026, 10, 15, 12, 0);

  AnalysisFinding createTestFinding({
    required String id,
    required String category,
  }) {
    return AnalysisFinding(
      id: id,
      category: category,
      explanation: 'Test finding explanation',
      origin: FindingOrigin.localRule,
      producerId: 'test.producer',
      evidence: [
        EvidenceReference(
          snapshotId: 'snap-1',
          startOffset: 0,
          endOffset: 5,
          exactExcerpt: 'Hello',
        ),
      ],
    );
  }

  AssessmentIndicatorGroup createTestGroup({
    required String categoryId,
    IndicatorCategory? category,
    required List<AnalysisFinding> findings,
  }) {
    return AssessmentIndicatorGroup(
      categoryId: categoryId,
      category: category,
      categoryLabel: category?.label ?? 'Label for $categoryId',
      findings: findings,
      educationalContext: CategoryEducationalContext(
        id: 'edu.$categoryId',
        categoryId: categoryId,
        whatObserved: 'What observed',
        whyAttention: 'Why attention',
        whatCannotEstablish: 'What cannot establish',
        independentVerificationStep: 'Verification step',
      ),
    );
  }

  AssessmentCoverageInfo createTestCoverage() {
    return AssessmentCoverageInfo(
      executedRuleIds: const ['rule.1', 'rule.2'],
      evaluatedCategories: const [
        IndicatorCategory.urgencyOrPressure,
        IndicatorCategory.requestsForCredentials,
      ],
    );
  }

  group('LocalAssessment Invariants and Immutability', () {
    test('constructs valid LocalAssessment with unmodifiable collections', () {
      final finding = createTestFinding(
        id: 'f-1',
        category: 'urgency_or_pressure',
      );
      final group = createTestGroup(
        categoryId: 'urgency_or_pressure',
        category: IndicatorCategory.urgencyOrPressure,
        findings: [finding],
      );
      final action = AssessmentAction(
        id: 'action.pause_before_acting',
        title: 'Pause',
        description: 'Take time',
        priority: AssessmentActionPriority.immediate,
        supportingFindingIds: const ['f-1'],
        supportingCategoryIds: const ['urgency_or_pressure'],
      );

      final assessment = LocalAssessment(
        reportId: 'rep-1',
        snapshotId: 'snap-1',
        snapshotSource: InputSource.messageText,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        factualSummary: 'Local checks identified 1 indicator.',
        groupedIndicators: [group],
        coverageInfo: createTestCoverage(),
        uncertaintyNotes: const ['Note 1', 'Note 2'],
        actionableSteps: [action],
        createdAt: testDateTime,
      );

      expect(assessment.reportId, 'rep-1');
      expect(assessment.snapshotId, 'snap-1');
      expect(assessment.snapshotSource, InputSource.messageText);
      expect(assessment.synthesisPolicyVersion, '1.0.0');
      expect(
        assessment.outcomeState,
        AssessmentOutcomeState.indicatorsDetected,
      );
      expect(assessment.totalFindingsCount, 1);

      // Verify unmodifiable collections throw UnsupportedError on mutation
      expect(
        () => (assessment.groupedIndicators as dynamic).add(group),
        throwsUnsupportedError,
      );
      expect(
        () => (assessment.uncertaintyNotes as dynamic).add('Note 3'),
        throwsUnsupportedError,
      );
      expect(
        () => (assessment.actionableSteps as dynamic).add(action),
        throwsUnsupportedError,
      );
    });

    test('rejects empty reportId, snapshotId, or factualSummary', () {
      final coverage = createTestCoverage();

      expect(
        () => LocalAssessment(
          reportId: '   ',
          snapshotId: 'snap-1',
          snapshotSource: InputSource.messageText,
          outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
          factualSummary: 'No matches',
          groupedIndicators: const [],
          coverageInfo: coverage,
          uncertaintyNotes: const [],
          actionableSteps: const [],
          createdAt: testDateTime,
        ),
        throwsArgumentError,
      );

      expect(
        () => LocalAssessment(
          reportId: 'rep-1',
          snapshotId: '   ',
          snapshotSource: InputSource.messageText,
          outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
          factualSummary: 'No matches',
          groupedIndicators: const [],
          coverageInfo: coverage,
          uncertaintyNotes: const [],
          actionableSteps: const [],
          createdAt: testDateTime,
        ),
        throwsArgumentError,
      );

      expect(
        () => LocalAssessment(
          reportId: 'rep-1',
          snapshotId: 'snap-1',
          snapshotSource: InputSource.messageText,
          outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
          factualSummary: '   ',
          groupedIndicators: const [],
          coverageInfo: coverage,
          uncertaintyNotes: const [],
          actionableSteps: const [],
          createdAt: testDateTime,
        ),
        throwsArgumentError,
      );
    });

    test('enforces outcomeState consistency with groupedIndicators', () {
      final coverage = createTestCoverage();
      final finding = createTestFinding(
        id: 'f-1',
        category: 'urgency_or_pressure',
      );
      final group = createTestGroup(
        categoryId: 'urgency_or_pressure',
        category: IndicatorCategory.urgencyOrPressure,
        findings: [finding],
      );

      // indicatorsDetected must NOT have empty groupedIndicators
      expect(
        () => LocalAssessment(
          reportId: 'rep-1',
          snapshotId: 'snap-1',
          snapshotSource: InputSource.messageText,
          outcomeState: AssessmentOutcomeState.indicatorsDetected,
          factualSummary: 'Summary',
          groupedIndicators: const [],
          coverageInfo: coverage,
          uncertaintyNotes: const [],
          actionableSteps: const [],
          createdAt: testDateTime,
        ),
        throwsArgumentError,
      );

      // noIndicatorsMatched must NOT have non-empty groupedIndicators
      expect(
        () => LocalAssessment(
          reportId: 'rep-1',
          snapshotId: 'snap-1',
          snapshotSource: InputSource.messageText,
          outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
          factualSummary: 'Summary',
          groupedIndicators: [group],
          coverageInfo: coverage,
          uncertaintyNotes: const [],
          actionableSteps: const [],
          createdAt: testDateTime,
        ),
        throwsArgumentError,
      );
    });

    test('privacy-safe toString does not leak sensitive content', () {
      final finding = createTestFinding(
        id: 'f-1',
        category: 'requests_for_credentials',
      );
      final group = createTestGroup(
        categoryId: 'requests_for_credentials',
        category: IndicatorCategory.requestsForCredentials,
        findings: [finding],
      );
      final action = AssessmentAction(
        id: 'action.protect_credentials',
        title: 'Do not disclose passwords',
        description: 'Never share passwords or PINs.',
        priority: AssessmentActionPriority.immediate,
        supportingFindingIds: const ['f-1'],
        supportingCategoryIds: const ['requests_for_credentials'],
      );

      final assessment = LocalAssessment(
        reportId: 'rep-1234',
        snapshotId: 'snap-5678',
        snapshotSource: InputSource.messageText,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        factualSummary: 'Local checks identified 1 indicator.',
        groupedIndicators: [group],
        coverageInfo: createTestCoverage(),
        uncertaintyNotes: const ['Some note'],
        actionableSteps: [action],
        createdAt: testDateTime,
      );

      final str = assessment.toString();
      expect(str, contains('rep-1234'));
      expect(str, contains('snap-5678'));
      expect(str, contains('indicatorsDetected'));
      expect(str, contains('groupsCount: 1'));
      expect(str, contains('findingsTotal: 1'));
      // Must not leak finding explanations or raw text in diagnostic string
      expect(str, isNot(contains('Test finding explanation')));
    });
  });

  group('AssessmentIndicatorGroup Invariants', () {
    test('rejects mismatched finding category in group', () {
      final finding = createTestFinding(
        id: 'f-1',
        category: 'requests_for_credentials',
      );
      expect(
        () => createTestGroup(
          categoryId: 'urgency_or_pressure',
          category: IndicatorCategory.urgencyOrPressure,
          findings: [finding],
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty findings list in group', () {
      expect(
        () => createTestGroup(
          categoryId: 'urgency_or_pressure',
          category: IndicatorCategory.urgencyOrPressure,
          findings: const [],
        ),
        throwsArgumentError,
      );
    });
  });

  group('AssessmentAction Deduplication & Merging', () {
    test('merges supporting finding and category references accurately', () {
      final action1 = AssessmentAction(
        id: 'action.pause_before_acting',
        title: 'Pause',
        description: 'Take time',
        priority: AssessmentActionPriority.immediate,
        supportingFindingIds: const ['f-2', 'f-1'],
        supportingCategoryIds: const ['urgency_or_pressure'],
      );

      final merged = action1.mergeSupportingReferences(
        additionalFindingIds: const ['f-3', 'f-1'],
        additionalCategoryIds: const ['account_suspension_or_threats'],
      );

      expect(merged.id, 'action.pause_before_acting');
      // Deterministically sorted and deduplicated
      expect(merged.supportingFindingIds, const ['f-1', 'f-2', 'f-3']);
      expect(merged.supportingCategoryIds, const [
        'account_suspension_or_threats',
        'urgency_or_pressure',
      ]);
    });
  });

  group('AssessmentCoverageInfo Scenarios', () {
    test('accurately identifies empty catalog vs executed rules', () {
      final emptyCoverage = AssessmentCoverageInfo(
        executedRuleIds: const [],
        evaluatedCategories: const [],
      );
      expect(emptyCoverage.isCatalogEmpty, isTrue);
      expect(emptyCoverage.hasLimitedCoverage, isTrue);
      expect(
        emptyCoverage.coverageDescription,
        contains('No local indicator rules were registered'),
      );

      final fullCoverage = AssessmentCoverageInfo(
        executedRuleIds: const ['rule.1', 'rule.2'],
        evaluatedCategories: const [IndicatorCategory.urgencyOrPressure],
      );
      expect(fullCoverage.isCatalogEmpty, isFalse);
      expect(fullCoverage.hasLimitedCoverage, isFalse);
      expect(
        fullCoverage.coverageDescription,
        contains('Evaluated 2 on-device rule(s)'),
      );

      final skippedCoverage = AssessmentCoverageInfo(
        executedRuleIds: const ['rule.1'],
        evaluatedCategories: const [IndicatorCategory.urgencyOrPressure],
        skippedRuleIds: const ['rule.skipped'],
      );
      expect(skippedCoverage.isCatalogEmpty, isFalse);
      expect(skippedCoverage.hasLimitedCoverage, isTrue);
      expect(
        skippedCoverage.coverageDescription,
        contains('1 rule(s) were skipped'),
      );
    });
  });
}
