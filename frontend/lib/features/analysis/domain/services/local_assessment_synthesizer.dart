import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_execution_context.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_coverage_info.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_indicator_group.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/category_educational_catalog.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';

/// Pure-Dart deterministic implementation of [AssessmentSynthesizer].
///
/// Guarantees:
/// - Transforms an [AnalysisReport] and [AnalysisExecutionContext] into an immutable [LocalAssessment].
/// - Pure function evaluation with zero platform, widget, or network dependencies.
/// - Deterministic group and action ordering across runs and collection permutations.
/// - Deduplicates actions by stable ID while merging all supporting finding and category IDs.
/// - Never computes fraud probabilities, numerical risk scores, confidence percentages, or safe verdicts.
/// - Preserves every finding and its evidence references without loss or truncation.
/// - Provides neutral fallbacks for uncataloged categories without crashing or dropping findings.
class LocalAssessmentSynthesizer implements AssessmentSynthesizer {
  final DateTime Function() _clock;

  LocalAssessmentSynthesizer({DateTime Function()? clock})
    : _clock = clock ?? _defaultClock;

  @override
  Result<LocalAssessment> synthesize({
    required AnalysisReport report,
    required AnalysisExecutionContext executionContext,
  }) {
    // 1. Validate basic report structure and snapshot consistency
    if (report.id.trim().isEmpty) {
      return Result.failure(
        AnalysisFailure.malformedData(
          'AnalysisReport ID must not be empty for assessment synthesis.',
          'empty_report_id',
        ),
      );
    }
    if (report.snapshot.id.trim().isEmpty) {
      return Result.failure(
        AnalysisFailure.malformedData(
          'AnalysisReport snapshot ID must not be empty.',
          'empty_snapshot_id',
        ),
      );
    }

    // 2. Validate findings integrity
    for (final finding in report.findings) {
      if (finding.category.trim().isEmpty) {
        return Result.failure(
          AnalysisFailure.malformedData(
            'Finding "${finding.id}" contains an empty category identifier.',
            'empty_finding_category',
          ),
        );
      }
      if (finding.evidence.isEmpty) {
        return Result.failure(
          AnalysisFailure.malformedData(
            'Finding "${finding.id}" contains no evidence references.',
            'empty_finding_evidence',
          ),
        );
      }
    }

    // 3. Determine coverage info and outcome state
    final coverageInfo = AssessmentCoverageInfo(
      executedRuleIds: executionContext.executedRuleIds,
      evaluatedCategories: executionContext.evaluatedCategories,
      skippedRuleIds: executionContext.skippedRuleIds,
    );

    final AssessmentOutcomeState outcomeState;
    final String factualSummary;

    final isConstrainedScope =
        executionContext.isCatalogEmpty ||
        (executionContext.executedRuleIds.isEmpty &&
            executionContext.skippedRuleIds.isNotEmpty);

    if (isConstrainedScope && report.findings.isEmpty) {
      outcomeState = AssessmentOutcomeState.limitedCoverage;
      if (executionContext.isCatalogEmpty) {
        factualSummary = 'Local analysis completed with limited rule coverage (no local rules were registered or evaluated).';
      } else {
        factualSummary =
            'Local analysis completed with limited rule coverage (${executionContext.skippedRuleIds.length} rule(s) were skipped due to unsupported input scope).';
      }
    } else if (report.findings.isEmpty) {
      outcomeState = AssessmentOutcomeState.noIndicatorsMatched;
      factualSummary = 'No indicators were matched by these local checks. This does not establish that the message is safe.';
    } else {
      outcomeState = AssessmentOutcomeState.indicatorsDetected;
      // Factual summary will be populated with observed category names after grouping
      factualSummary = '';
    }

    // 4. Group findings deterministically by category
    final groupedIndicators = <AssessmentIndicatorGroup>[];
    if (outcomeState == AssessmentOutcomeState.indicatorsDetected) {
      final findingsByCategory = <String, List<AnalysisFinding>>{};
      for (final finding in report.findings) {
        findingsByCategory.putIfAbsent(finding.category, () => []).add(finding);
      }

      // Sort categories deterministically:
      // Known canonical categories follow IndicatorCategory.values order.
      // Unknown categories sort alphabetically at the end.
      final sortedCategoryIds = findingsByCategory.keys.toList()
        ..sort((a, b) {
          final catA = IndicatorCategory.fromId(a);
          final catB = IndicatorCategory.fromId(b);
          if (catA != null && catB != null) {
            return catA.index.compareTo(catB.index);
          }
          if (catA != null && catB == null) return -1;
          if (catA == null && catB != null) return 1;
          return a.compareTo(b);
        });

      for (final catId in sortedCategoryIds) {
        final catFindings = findingsByCategory[catId]!;
        final knownCategory = IndicatorCategory.fromId(catId);
        final label =
            knownCategory?.label ?? 'Unclassified indicator ("$catId")';
        final educationalContext = CategoryEducationalCatalog.getContext(catId);

        groupedIndicators.add(
          AssessmentIndicatorGroup(
            categoryId: catId,
            category: knownCategory,
            categoryLabel: label,
            findings: catFindings,
            educationalContext: educationalContext,
          ),
        );
      }
    }

    // 5. Build finalized factual summary for indicatorsDetected
    final String finalSummary;
    if (outcomeState == AssessmentOutcomeState.indicatorsDetected) {
      final categoryLabels = groupedIndicators
          .map((g) => g.categoryLabel)
          .join(', ');
      final findingCount = report.findings.length;
      final groupCount = groupedIndicators.length;
      final findingText = findingCount == 1
          ? '1 potential warning indicator'
          : '$findingCount potential warning indicators';
      final groupText = groupCount == 1
          ? '1 category'
          : '$groupCount categories';
      finalSummary =
          'Local checks identified $findingText across $groupText: $categoryLabels.';
    } else {
      finalSummary = factualSummary;
    }

    // 6. Generate and deduplicate actionable steps
    final actionMap = <String, AssessmentAction>{};

    if (outcomeState == AssessmentOutcomeState.noIndicatorsMatched ||
        outcomeState == AssessmentOutcomeState.limitedCoverage) {
      final defaultAction =
          CategoryEducationalCatalog.createGeneralCautionAction();
      actionMap[defaultAction.id] = defaultAction;
    } else {
      for (final group in groupedIndicators) {
        final findingIds = group.findings.map((f) => f.id).toList();
        final groupActions = CategoryEducationalCatalog.getActionsForCategory(
          categoryId: group.categoryId,
          findingIds: findingIds,
        );

        for (final action in groupActions) {
          final existing = actionMap[action.id];
          if (existing == null) {
            actionMap[action.id] = action;
          } else {
            actionMap[action.id] = existing.mergeSupportingReferences(
              additionalFindingIds: action.supportingFindingIds,
              additionalCategoryIds: action.supportingCategoryIds,
            );
          }
        }
      }
    }

    // Sort actions deterministically:
    // 1. Priority index (immediate first, recommended second, conditional third)
    // 2. Action ID alphabetically
    final sortedActions = actionMap.values.toList()
      ..sort((a, b) {
        final prioComp = a.priority.index.compareTo(b.priority.index);
        if (prioComp != 0) return prioComp;
        return a.id.compareTo(b.id);
      });

    // 7. Compose honest uncertainty notes and provenance constraints
    final uncertaintyNotes = <String>[
      'Local heuristic rules evaluate textual and structural patterns. They can miss sophisticated threats or flag benign messages.',
      'Pattern matching is designed for English-language text and offline URL structures; communications in other languages have limited or no coverage.',
      'Sender identity, sender authorization, and destination reputation were not verified.',
      'Analysis was executed entirely on-device; no network queries, external lookups, or remote AI models were used.',
    ];

    if (report.snapshot.source == InputSource.screenshot) {
      uncertaintyNotes.add(
        'Text was extracted from an image via optical character recognition (OCR) and may contain transcription errors, omissions, or formatting artifacts. Review by the user does not guarantee complete transcription accuracy.',
      );
    }

    final reviewMeta = executionContext.trustedReviewMetadata;
    if (reviewMeta != null && reviewMeta.totalRedactions > 0) {
      uncertaintyNotes.add(
        'Text was edited or redacted during user review (${reviewMeta.totalRedactions} redaction(s) applied). Certain indicators dependent on full conversational context or specific addresses may not be observable.',
      );
    } else if (reviewMeta == null) {
      uncertaintyNotes.add(
        'If this text was edited or redacted prior to analysis, omitted context may affect indicator detection.',
      );
    }

    // 8. Construct immutable assessment
    final assessment = LocalAssessment(
      reportId: report.id,
      snapshotId: report.snapshot.id,
      snapshotSource: report.snapshot.source,
      outcomeState: outcomeState,
      factualSummary: finalSummary,
      groupedIndicators: groupedIndicators,
      coverageInfo: coverageInfo,
      uncertaintyNotes: uncertaintyNotes,
      actionableSteps: sortedActions,
      createdAt: _clock().toUtc(),
    );

    return Result.success(assessment);
  }

  static DateTime _defaultClock() => DateTime.now().toUtc();
}
