import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_type.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Immutable in-memory result produced when a user confirms their reviewed and optionally redacted text.
///
/// Contains the newly generated [TextSnapshot], provenance references, and minimal redaction
/// count metadata. Original sensitive values and mapping tables are intentionally excluded.
class ReviewedTextResult {
  ReviewedTextResult({
    required this.snapshot,
    required this.sourceSnapshotId,
    required this.sourceRevision,
    required this.reviewedAt,
    Map<SensitiveDataType, int>? redactionCounts,
  }) : redactionCounts = Map.unmodifiable(redactionCounts ?? const {});

  /// The finalized, immutable [TextSnapshot] containing the exact reviewed/redacted text.
  final TextSnapshot snapshot;

  /// The ID of the original [TextSnapshot] that served as input for this review session.
  final String sourceSnapshotId;

  /// The revision identifier of the originating input (e.g. image revision).
  final String sourceRevision;

  /// UTC timestamp at which the user confirmed the reviewed text.
  final DateTime reviewedAt;

  /// Summary count of redactions applied by category (e.g. `{SensitiveDataType.phone: 1}`).
  final Map<SensitiveDataType, int> redactionCounts;

  /// Total count of redactions applied in this reviewed snapshot.
  int get totalRedactions =>
      redactionCounts.values.fold(0, (sum, count) => sum + count);

  @override
  String toString() {
    return 'ReviewedTextResult(snapshotId: ${snapshot.id}, sourceSnapshotId: $sourceSnapshotId, revision: $sourceRevision, reviewedAt: ${reviewedAt.toIso8601String()}, redactions: $totalRedactions)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReviewedTextResult &&
        other.snapshot == snapshot &&
        other.sourceSnapshotId == sourceSnapshotId &&
        other.sourceRevision == sourceRevision &&
        other.reviewedAt == reviewedAt;
  }

  @override
  int get hashCode =>
      Object.hash(snapshot, sourceSnapshotId, sourceRevision, reviewedAt);
}
