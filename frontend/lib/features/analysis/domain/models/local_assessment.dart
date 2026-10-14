import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';

import 'assessment_action.dart';
import 'assessment_coverage_info.dart';
import 'assessment_indicator_group.dart';

/// The high-level outcome state of local assessment synthesis.
///
/// Principles:
/// - These states describe what local checks observed.
/// - They MUST NEVER be interpreted as a verdict of safety or definitive proof of malice.
enum AssessmentOutcomeState {
  /// Local rules identified one or more potential warning indicator patterns.
  indicatorsDetected,

  /// Evaluated local rules did not match any indicator patterns.
  /// Does NOT establish that the content is safe or legitimate.
  noIndicatorsMatched,

  /// Evaluation was constrained (e.g. empty rule catalog or all rules skipped).
  limitedCoverage;

  String toSerializedString() => name;
}

/// Immutable, deterministic assessment synthesizing local scam indicator findings,
/// educational explanations, scope limitations, and prioritized verification actions.
///
/// Invariants:
/// - [reportId] and [snapshotId] must be non-empty strings identifying the source analysis.
/// - [synthesisPolicyVersion] tracks the deterministic synthesis version (current: [currentSynthesisPolicyVersion]).
/// - [outcomeState] accurately reflects finding presence or coverage constraints.
/// - Does NOT calculate risk scores, fraud probabilities, confidence percentages, or safe verdicts.
/// - Collections are unmodifiable.
/// - [toString] is privacy-safe and never logs sensitive message excerpts or user credentials.
class LocalAssessment {
  static const String currentSynthesisPolicyVersion = '1.0.0';

  final String reportId;
  final String snapshotId;
  final InputSource snapshotSource;
  final String synthesisPolicyVersion;
  final AssessmentOutcomeState outcomeState;
  final String factualSummary;
  final List<AssessmentIndicatorGroup> groupedIndicators;
  final AssessmentCoverageInfo coverageInfo;
  final List<String> uncertaintyNotes;
  final List<AssessmentAction> actionableSteps;
  final DateTime createdAt;

  LocalAssessment({
    required this.reportId,
    required this.snapshotId,
    required this.snapshotSource,
    this.synthesisPolicyVersion = currentSynthesisPolicyVersion,
    required this.outcomeState,
    required this.factualSummary,
    required List<AssessmentIndicatorGroup> groupedIndicators,
    required this.coverageInfo,
    required List<String> uncertaintyNotes,
    required List<AssessmentAction> actionableSteps,
    required DateTime createdAt,
  }) : groupedIndicators = List.unmodifiable(groupedIndicators),
       uncertaintyNotes = List.unmodifiable(uncertaintyNotes),
       actionableSteps = List.unmodifiable(actionableSteps),
       createdAt = createdAt.toUtc() {
    if (reportId.trim().isEmpty) {
      throw ArgumentError.value(
        reportId,
        'reportId',
        'Report ID must not be empty.',
      );
    }
    if (snapshotId.trim().isEmpty) {
      throw ArgumentError.value(
        snapshotId,
        'snapshotId',
        'Snapshot ID must not be empty.',
      );
    }
    if (synthesisPolicyVersion.trim().isEmpty) {
      throw ArgumentError.value(
        synthesisPolicyVersion,
        'synthesisPolicyVersion',
        'Synthesis policy version must not be empty.',
      );
    }
    if (factualSummary.trim().isEmpty) {
      throw ArgumentError.value(
        factualSummary,
        'factualSummary',
        'Factual summary must not be empty.',
      );
    }

    if (outcomeState == AssessmentOutcomeState.indicatorsDetected &&
        this.groupedIndicators.isEmpty) {
      throw ArgumentError(
        'groupedIndicators must not be empty when outcomeState is indicatorsDetected.',
      );
    }
    if (outcomeState == AssessmentOutcomeState.noIndicatorsMatched &&
        this.groupedIndicators.isNotEmpty) {
      throw ArgumentError(
        'groupedIndicators must be empty when outcomeState is noIndicatorsMatched.',
      );
    }
  }

  /// Total count of individual findings across all indicator groups.
  int get totalFindingsCount =>
      groupedIndicators.fold(0, (sum, g) => sum + g.findings.length);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LocalAssessment) return false;
    if (other.reportId != reportId ||
        other.snapshotId != snapshotId ||
        other.snapshotSource != snapshotSource ||
        other.synthesisPolicyVersion != synthesisPolicyVersion ||
        other.outcomeState != outcomeState ||
        other.factualSummary != factualSummary ||
        other.coverageInfo != coverageInfo ||
        !other.createdAt.isAtSameMomentAs(createdAt) ||
        other.groupedIndicators.length != groupedIndicators.length ||
        other.uncertaintyNotes.length != uncertaintyNotes.length ||
        other.actionableSteps.length != actionableSteps.length) {
      return false;
    }
    for (var i = 0; i < groupedIndicators.length; i++) {
      if (groupedIndicators[i] != other.groupedIndicators[i]) return false;
    }
    for (var i = 0; i < uncertaintyNotes.length; i++) {
      if (uncertaintyNotes[i] != other.uncertaintyNotes[i]) return false;
    }
    for (var i = 0; i < actionableSteps.length; i++) {
      if (actionableSteps[i] != other.actionableSteps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    reportId,
    snapshotId,
    snapshotSource,
    synthesisPolicyVersion,
    outcomeState,
    factualSummary,
    coverageInfo,
    createdAt.microsecondsSinceEpoch,
    Object.hashAll(groupedIndicators),
    Object.hashAll(uncertaintyNotes),
    Object.hashAll(actionableSteps),
  );

  @override
  String toString() {
    return 'LocalAssessment(reportId: $reportId, snapshotId: $snapshotId, source: ${snapshotSource.name}, outcomeState: ${outcomeState.name}, groupsCount: ${groupedIndicators.length}, findingsTotal: $totalFindingsCount, actionsCount: ${actionableSteps.length}, createdAt: ${createdAt.toIso8601String()})';
  }
}
