import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Immutable domain model representing an analysis report durably saved
/// on the local device with explicit user authorization.
///
/// Invariants & Guarantees:
/// - Bound to an exact [snapshot] (reviewed text only, no raw OCR or screenshot images).
/// - [localReport] contains the deterministic on-device rule findings.
/// - [aiReport] contains optional cloud-assisted findings (if requested by user).
/// - [accountId] is null for guest/offline sessions or matches the user's UUID.
/// - [schemaVersion] tracks the stored payload schema version (current: [currentSchemaVersion]).
/// - [savedAt] and [analyzedAt] are normalized to UTC.
/// - Every finding across local and AI reports must strictly validate against [snapshot].
/// - Zero passwords, auth tokens, API keys, or raw prompts are stored.
class SavedReport {
  static const int currentSchemaVersion = 1;

  final String id;
  final int schemaVersion;
  final TextSnapshot snapshot;
  final String? accountId;
  final DateTime analyzedAt;
  final DateTime savedAt;
  final AnalysisReport localReport;
  final AiAnalysisReport? aiReport;

  SavedReport({
    required this.id,
    this.schemaVersion = currentSchemaVersion,
    required this.snapshot,
    this.accountId,
    required DateTime analyzedAt,
    required DateTime savedAt,
    required this.localReport,
    this.aiReport,
  }) : analyzedAt = analyzedAt.toUtc(),
       savedAt = savedAt.toUtc() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'SavedReport ID must not be empty.');
    }
    if (schemaVersion != currentSchemaVersion) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Unsupported schema version: $schemaVersion (supported: $currentSchemaVersion).',
      );
    }

    // Verify local report invariants against snapshot
    localReport.validateAgainst(snapshot);

    // Verify AI report invariants against snapshot if present
    if (aiReport != null) {
      aiReport!.validateAgainst(snapshot);
    }
  }

  /// Whether this saved report includes verified cloud AI findings.
  bool get hasAiAnalysis => aiReport != null;

  /// The input source through which the message was provided.
  InputSource get inputSource => snapshot.source;

  /// Total count of all findings across local rules and optional cloud AI.
  int get totalFindingsCount =>
      localReport.findings.length + (aiReport?.findings.length ?? 0);

  /// Factual outcome state based on whether scam indicator patterns were detected.
  AssessmentOutcomeState get outcomeState {
    if (totalFindingsCount > 0) {
      return AssessmentOutcomeState.indicatorsDetected;
    }
    return AssessmentOutcomeState.noIndicatorsMatched;
  }

  /// Generates a clean, single-line preview snippet of the reviewed text (max 100 characters).
  String get previewText {
    final clean = snapshot.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 100) return clean;
    return '${clean.substring(0, 97)}...';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SavedReport) return false;
    return other.id == id &&
        other.schemaVersion == schemaVersion &&
        other.snapshot == snapshot &&
        other.accountId == accountId &&
        other.analyzedAt.isAtSameMomentAs(analyzedAt) &&
        other.savedAt.isAtSameMomentAs(savedAt) &&
        other.localReport == localReport &&
        other.aiReport?.reportId == aiReport?.reportId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    schemaVersion,
    snapshot,
    accountId,
    analyzedAt.microsecondsSinceEpoch,
    savedAt.microsecondsSinceEpoch,
    localReport,
    aiReport?.reportId,
  );

  @override
  String toString() =>
      'SavedReport(id: $id, snapshotId: ${snapshot.id}, accountId: $accountId, findings: $totalFindingsCount, hasAi: $hasAiAnalysis)';
}
