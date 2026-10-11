import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'analysis_finding.dart';

/// Immutable analysis report documenting evaluated scam indicators,
/// explicit methodology limitations, and actionable verification steps.
///
/// Invariants & Guarantees:
/// - [id] must be non-empty.
/// - [schemaVersion] identifies the data contract format (current: [currentSchemaVersion]).
/// - [snapshot] represents the exact, unredacted text snapshot evaluated.
/// - [analyzedAt] is represented consistently in UTC.
/// - [findings] cannot contain duplicate finding IDs.
/// - Every finding and evidence reference must strictly validate against [snapshot].
/// - An empty [findings] list indicates ONLY that no findings were detected by
///   the rules evaluated. It MUST NEVER be interpreted as a guarantee of safety.
/// - Does not include raw file bytes, source file paths, or private credentials.
class AnalysisReport {
  static const int currentSchemaVersion = 1;

  final String id;
  final int schemaVersion;
  final TextSnapshot snapshot;
  final DateTime analyzedAt;
  final List<AnalysisFinding> findings;
  final List<String> limitations;
  final List<String> suggestedActions;

  AnalysisReport({
    required this.id,
    this.schemaVersion = currentSchemaVersion,
    required this.snapshot,
    required DateTime analyzedAt,
    required List<AnalysisFinding> findings,
    required List<String> limitations,
    required List<String> suggestedActions,
  }) : analyzedAt = analyzedAt.toUtc(),
       findings = List.unmodifiable(findings),
       limitations = List.unmodifiable(limitations),
       suggestedActions = List.unmodifiable(suggestedActions) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Report ID must not be empty.');
    }
    if (schemaVersion != currentSchemaVersion) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Unsupported schema version: $schemaVersion (supported: $currentSchemaVersion).',
      );
    }

    final seenFindingIds = <String>{};
    for (final finding in this.findings) {
      if (!seenFindingIds.add(finding.id)) {
        throw ArgumentError(
          'Duplicate finding ID detected in report: "${finding.id}".',
        );
      }
      finding.validateAgainst(snapshot);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnalysisReport) return false;
    if (other.id != id ||
        other.schemaVersion != schemaVersion ||
        other.snapshot != snapshot ||
        !other.analyzedAt.isAtSameMomentAs(analyzedAt) ||
        other.findings.length != findings.length ||
        other.limitations.length != limitations.length ||
        other.suggestedActions.length != suggestedActions.length) {
      return false;
    }
    for (var i = 0; i < findings.length; i++) {
      if (findings[i] != other.findings[i]) return false;
    }
    for (var i = 0; i < limitations.length; i++) {
      if (limitations[i] != other.limitations[i]) return false;
    }
    for (var i = 0; i < suggestedActions.length; i++) {
      if (suggestedActions[i] != other.suggestedActions[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    schemaVersion,
    snapshot,
    analyzedAt.microsecondsSinceEpoch,
    Object.hashAll(findings),
    Object.hashAll(limitations),
    Object.hashAll(suggestedActions),
  );

  @override
  String toString() {
    return 'AnalysisReport(id: $id, schemaVersion: $schemaVersion, snapshotId: ${snapshot.id}, findingsCount: ${findings.length}, analyzedAt: ${analyzedAt.toIso8601String()})';
  }
}
