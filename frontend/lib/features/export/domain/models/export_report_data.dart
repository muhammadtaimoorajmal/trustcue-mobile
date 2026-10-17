import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';

/// An individual indicator finding item prepared specifically for export.
class ExportFindingItem {
  final String category;
  final FindingOrigin origin;
  final String producerId;
  final String explanation;
  final List<String> evidenceQuotes;

  const ExportFindingItem({
    required this.category,
    required this.origin,
    required this.producerId,
    required this.explanation,
    this.evidenceQuotes = const [],
  });

  bool get isAiAssisted => origin == FindingOrigin.remoteAi;
}

/// Dedicated, immutable domain model representing sanitized report data
/// formatted for external export and sharing.
///
/// Invariants & Privacy Protections:
/// - Never serializes raw database entities, account emails, auth tokens,
///   user IDs, or local filesystem paths.
/// - Clearly distinguishes [analyzedAt] (when the text was evaluated) from
///   [exportedAt] (when this export was generated).
/// - [reviewedText] is populated ONLY if explicitly authorized by user options.
/// - [isCloudSummaryOnly] indicates if this report was reconstructed from a
///   cloud metadata summary without access to the local snapshot or full findings.
/// - Guarantees honest limitations: never provides probabilistic fraud scores
///   or safety guarantees.
class ExportReportData {
  final String reportId;
  final DateTime analyzedAt;
  final DateTime exportedAt;
  final InputSource inputSource;
  final bool hasAiAnalysis;
  final String? aiProvider;
  final String? aiModel;
  final AssessmentOutcomeState outcomeState;
  final String outcomeSummary;
  final List<ExportFindingItem> findings;
  final List<String> limitations;
  final List<String> suggestedActions;
  final String? reviewedText;
  final bool isCloudSummaryOnly;

  ExportReportData({
    required this.reportId,
    required DateTime analyzedAt,
    required DateTime exportedAt,
    required this.inputSource,
    required this.hasAiAnalysis,
    this.aiProvider,
    this.aiModel,
    required this.outcomeState,
    required this.outcomeSummary,
    required List<ExportFindingItem> findings,
    required List<String> limitations,
    required List<String> suggestedActions,
    this.reviewedText,
    this.isCloudSummaryOnly = false,
  }) : analyzedAt = analyzedAt.toUtc(),
       exportedAt = exportedAt.toUtc(),
       findings = List.unmodifiable(findings),
       limitations = List.unmodifiable(limitations),
       suggestedActions = List.unmodifiable(suggestedActions) {
    if (reportId.trim().isEmpty) {
      throw ArgumentError.value(reportId, 'reportId', 'Report ID must not be empty.');
    }
  }

  /// Total count of indicator findings included in the export.
  int get findingCount => findings.length;

  /// Whether reviewed text is included in this export.
  bool get hasReviewedText => reviewedText != null && reviewedText!.trim().isNotEmpty;
}

