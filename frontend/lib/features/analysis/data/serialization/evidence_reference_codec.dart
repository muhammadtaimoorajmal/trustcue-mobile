import '../../domain/models/evidence_reference.dart';

/// Codec for encoding and strictly decoding [EvidenceReference] instances.
class EvidenceReferenceCodec {
  const EvidenceReferenceCodec();

  /// Encodes an [EvidenceReference] into a version-1 JSON-compatible map.
  Map<String, dynamic> encode(EvidenceReference evidence) {
    return {
      'snapshotId': evidence.snapshotId,
      'startOffset': evidence.startOffset,
      'endOffset': evidence.endOffset,
      'exactExcerpt': evidence.exactExcerpt,
    };
  }

  /// Strictly decodes a JSON map into an [EvidenceReference].
  ///
  /// Throws [FormatException] if:
  /// - Required fields are missing or not of expected types.
  /// - Offsets are not strict integers (coercions from string or float are rejected).
  /// - Structural invariants fail (e.g., negative offset or excerpt length mismatch).
  EvidenceReference decode(Map<String, dynamic> json) {
    final snapshotIdValue = json['snapshotId'];
    if (snapshotIdValue is! String) {
      throw const FormatException(
        'EvidenceReference "snapshotId" must be a non-null String.',
      );
    }

    final startOffsetValue = json['startOffset'];
    if (startOffsetValue is! int) {
      throw const FormatException(
        'EvidenceReference "startOffset" must be a non-null int.',
      );
    }

    final endOffsetValue = json['endOffset'];
    if (endOffsetValue is! int) {
      throw const FormatException(
        'EvidenceReference "endOffset" must be a non-null int.',
      );
    }

    final exactExcerptValue = json['exactExcerpt'];
    if (exactExcerptValue is! String) {
      throw const FormatException(
        'EvidenceReference "exactExcerpt" must be a non-null String.',
      );
    }

    try {
      return EvidenceReference(
        snapshotId: snapshotIdValue,
        startOffset: startOffsetValue,
        endOffset: endOffsetValue,
        exactExcerpt: exactExcerptValue,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Invalid EvidenceReference: ${e.message}');
    }
  }
}
