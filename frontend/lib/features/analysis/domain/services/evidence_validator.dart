import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Service ensuring strict evidence integrity for emitted findings against an evaluated [TextSnapshot].
///
/// Enforces:
/// - Exact snapshot ID reference matching.
/// - Valid 0-based UTF-16 code-unit offsets within snapshot length.
/// - End-exclusive ranges ([startOffset, endOffset)).
/// - No splitting of UTF-16 surrogate pairs.
/// - Exact string excerpt equality against snapshot substring.
/// - Non-empty evidence collection.
/// - Local rule origin and matching producer identity.
class EvidenceValidator {
  const EvidenceValidator._();

  /// Validates [finding] and all its evidence references against [snapshot].
  ///
  /// Throws [ArgumentError] if any contract or integrity invariant is violated.
  static void validateFinding(
    AnalysisFinding finding,
    TextSnapshot snapshot, {
    String? expectedProducerId,
    String? expectedCategoryId,
  }) {
    if (finding.origin != FindingOrigin.localRule) {
      throw ArgumentError(
        'Local rule finding "${finding.id}" must have origin FindingOrigin.localRule, got ${finding.origin.name}.',
      );
    }

    if (expectedProducerId != null &&
        finding.producerId != expectedProducerId) {
      throw ArgumentError(
        'Finding producer ID "${finding.producerId}" does not match rule producer "$expectedProducerId".',
      );
    }

    if (expectedCategoryId != null && finding.category != expectedCategoryId) {
      throw ArgumentError(
        'Finding category "${finding.category}" does not match rule category "$expectedCategoryId".',
      );
    }

    if (finding.evidence.isEmpty) {
      throw ArgumentError(
        'Finding "${finding.id}" must contain at least one evidence reference.',
      );
    }

    for (final evidence in finding.evidence) {
      validateReference(evidence, snapshot);
    }
  }

  /// Validates a single [EvidenceReference] against [snapshot].
  ///
  /// Throws [ArgumentError] if the reference fails any integrity check.
  static void validateReference(
    EvidenceReference evidence,
    TextSnapshot snapshot,
  ) {
    evidence.validateAgainst(snapshot);
  }

  /// Safely extracts an [EvidenceReference] from [snapshot] across `[startOffset, endOffset)`.
  ///
  /// Throws [ArgumentError] if the range is invalid or splits a UTF-16 surrogate pair.
  static EvidenceReference createReference({
    required TextSnapshot snapshot,
    required int startOffset,
    required int endOffset,
  }) {
    final text = snapshot.text;
    if (startOffset < 0) {
      throw ArgumentError.value(startOffset, 'startOffset', 'Must be >= 0.');
    }
    if (endOffset <= startOffset) {
      throw ArgumentError(
        'End offset ($endOffset) must be greater than start offset ($startOffset).',
      );
    }
    if (endOffset > text.length) {
      throw ArgumentError(
        'End offset ($endOffset) exceeds snapshot length (${text.length}).',
      );
    }
    if (EvidenceReference.isSurrogateSplit(text, startOffset)) {
      throw ArgumentError(
        'Start offset ($startOffset) splits a UTF-16 surrogate pair.',
      );
    }
    if (EvidenceReference.isSurrogateSplit(text, endOffset)) {
      throw ArgumentError(
        'End offset ($endOffset) splits a UTF-16 surrogate pair.',
      );
    }

    final excerpt = text.substring(startOffset, endOffset);
    return EvidenceReference(
      snapshotId: snapshot.id,
      startOffset: startOffset,
      endOffset: endOffset,
      exactExcerpt: excerpt,
    );
  }
}
