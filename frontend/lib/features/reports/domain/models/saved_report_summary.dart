import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';

/// Lightweight summary of a locally saved analysis report.
///
/// Designed specifically for bounded pagination and efficient list rendering
/// in the history screen (Module 37) without loading full report payloads
/// or unredacted text bodies into memory.
class SavedReportSummary {
  final String id;
  final int schemaVersion;
  final String snapshotId;
  final String? accountId;
  final InputSource inputSource;
  final DateTime analyzedAt;
  final DateTime savedAt;
  final bool hasAiAnalysis;
  final String? aiProvider;
  final String? aiModel;
  final int findingsCount;
  final AssessmentOutcomeState outcomeState;
  final String previewText;

  const SavedReportSummary({
    required this.id,
    required this.schemaVersion,
    required this.snapshotId,
    this.accountId,
    required this.inputSource,
    required this.analyzedAt,
    required this.savedAt,
    required this.hasAiAnalysis,
    this.aiProvider,
    this.aiModel,
    required this.findingsCount,
    required this.outcomeState,
    required this.previewText,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SavedReportSummary) return false;
    return other.id == id &&
        other.schemaVersion == schemaVersion &&
        other.snapshotId == snapshotId &&
        other.accountId == accountId &&
        other.inputSource == inputSource &&
        other.analyzedAt.isAtSameMomentAs(analyzedAt) &&
        other.savedAt.isAtSameMomentAs(savedAt) &&
        other.hasAiAnalysis == hasAiAnalysis &&
        other.aiProvider == aiProvider &&
        other.aiModel == aiModel &&
        other.findingsCount == findingsCount &&
        other.outcomeState == outcomeState &&
        other.previewText == previewText;
  }

  @override
  int get hashCode => Object.hash(
    id,
    schemaVersion,
    snapshotId,
    accountId,
    inputSource,
    analyzedAt.microsecondsSinceEpoch,
    savedAt.microsecondsSinceEpoch,
    hasAiAnalysis,
    aiProvider,
    aiModel,
    findingsCount,
    outcomeState,
    previewText,
  );

  @override
  String toString() =>
      'SavedReportSummary(id: $id, preview: "$previewText", findings: $findingsCount, hasAi: $hasAiAnalysis)';
}
