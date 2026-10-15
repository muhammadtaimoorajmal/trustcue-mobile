import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Immutable representation of the validated server-assisted AI analysis response.
///
/// Invariants:
/// - [reportId] is the unique server-generated audit report ID.
/// - [snapshotId] matches the client-submitted [TextSnapshot.id].
/// - [findings] hold verified findings labeled with [FindingOrigin.remoteAi].
/// - All findings and evidence excerpts must strictly validate against the submitted [TextSnapshot].
/// - An empty [findings] list represents that no scam patterns were detected;
///   it must NEVER be interpreted as a guarantee of safety or legitimacy.
class AiAnalysisReport {
  final String reportId;
  final String snapshotId;
  final String provider;
  final String model;
  final DateTime analyzedAt;
  final String factualSummary;
  final List<AnalysisFinding> findings;
  final List<String> uncertaintyNotes;
  final List<AssessmentAction> suggestedActions;

  AiAnalysisReport({
    required this.reportId,
    required this.snapshotId,
    required this.provider,
    required this.model,
    required DateTime analyzedAt,
    required this.factualSummary,
    required List<AnalysisFinding> findings,
    required List<String> uncertaintyNotes,
    required List<AssessmentAction> suggestedActions,
  }) : analyzedAt = analyzedAt.toUtc(),
       findings = List.unmodifiable(findings),
       uncertaintyNotes = List.unmodifiable(uncertaintyNotes),
       suggestedActions = List.unmodifiable(suggestedActions) {
    if (reportId.trim().isEmpty) {
      throw ArgumentError.value(
        reportId,
        'reportId',
        'Report ID cannot be empty.',
      );
    }
    if (snapshotId.trim().isEmpty) {
      throw ArgumentError.value(
        snapshotId,
        'snapshotId',
        'Snapshot ID cannot be empty.',
      );
    }
    if (provider.trim().isEmpty) {
      throw ArgumentError.value(
        provider,
        'provider',
        'Provider cannot be empty.',
      );
    }
    if (factualSummary.trim().isEmpty) {
      throw ArgumentError.value(
        factualSummary,
        'factualSummary',
        'Factual summary cannot be empty.',
      );
    }
  }

  /// Validates that the report's snapshot ID and all finding evidence offsets
  /// match the exact reviewed [snapshot].
  void validateAgainst(TextSnapshot snapshot) {
    if (snapshot.id != snapshotId) {
      throw ArgumentError(
        'Snapshot ID mismatch: report bound to "$snapshotId" but snapshot is "${snapshot.id}".',
      );
    }
    for (final finding in findings) {
      finding.validateAgainst(snapshot);
    }
  }
}
