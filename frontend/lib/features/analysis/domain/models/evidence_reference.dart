import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Immutable reference pointing to verifiable excerpt evidence within a [TextSnapshot].
///
/// Offsets are defined as 0-based UTF-16 code-unit offsets into the exact snapshot text.
/// Every evidence reference must link strictly to actual text in the snapshot;
/// invented quotations or loose approximations are prohibited.
class EvidenceReference {
  final String snapshotId;
  final int startOffset;
  final int endOffset;
  final String exactExcerpt;

  EvidenceReference({
    required this.snapshotId,
    required this.startOffset,
    required this.endOffset,
    required this.exactExcerpt,
  }) {
    if (snapshotId.trim().isEmpty) {
      throw ArgumentError.value(
        snapshotId,
        'snapshotId',
        'Referenced snapshot ID must not be empty.',
      );
    }
    if (startOffset < 0) {
      throw ArgumentError.value(
        startOffset,
        'startOffset',
        'Start offset must be non-negative.',
      );
    }
    if (endOffset <= startOffset) {
      throw ArgumentError(
        'End offset ($endOffset) must be strictly greater than start offset ($startOffset).',
      );
    }
    if (exactExcerpt.isEmpty) {
      throw ArgumentError.value(
        exactExcerpt,
        'exactExcerpt',
        'Exact excerpt must not be empty.',
      );
    }
    if (exactExcerpt.length != (endOffset - startOffset)) {
      throw ArgumentError(
        'Excerpt length (${exactExcerpt.length}) does not match offset span (${endOffset - startOffset}).',
      );
    }
  }

  /// Validates this evidence reference against the referenced [snapshot].
  ///
  /// Throws [ArgumentError] if:
  /// - [snapshot.id] does not match [snapshotId].
  /// - [endOffset] exceeds snapshot text length.
  /// - Substring in snapshot text does not strictly match [exactExcerpt].
  /// - Either [startOffset] or [endOffset] splits a UTF-16 surrogate pair.
  void validateAgainst(TextSnapshot snapshot) {
    if (snapshot.id != snapshotId) {
      throw ArgumentError(
        'Evidence references snapshot "$snapshotId", but target snapshot has id "${snapshot.id}".',
      );
    }

    final text = snapshot.text;
    if (endOffset > text.length) {
      throw ArgumentError(
        'Evidence end offset ($endOffset) exceeds snapshot text length (${text.length}).',
      );
    }

    final actualSubstring = text.substring(startOffset, endOffset);
    if (actualSubstring != exactExcerpt) {
      throw ArgumentError(
        'Evidence excerpt mismatch at offsets [$startOffset, $endOffset).',
      );
    }

    if (isSurrogateSplit(text, startOffset)) {
      throw ArgumentError(
        'Evidence start offset ($startOffset) splits a UTF-16 surrogate pair.',
      );
    }

    if (isSurrogateSplit(text, endOffset)) {
      throw ArgumentError(
        'Evidence end offset ($endOffset) splits a UTF-16 surrogate pair.',
      );
    }
  }

  /// Checks whether [offset] splits a UTF-16 surrogate pair in [text].
  static bool isSurrogateSplit(String text, int offset) {
    if (offset <= 0 || offset >= text.length) return false;
    final prevUnit = text.codeUnitAt(offset - 1);
    final currUnit = text.codeUnitAt(offset);
    final isPrevLead = prevUnit >= 0xD800 && prevUnit <= 0xDBFF;
    final isCurrTrail = currUnit >= 0xDC00 && currUnit <= 0xDFFF;
    return isPrevLead && isCurrTrail;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvidenceReference &&
        other.snapshotId == snapshotId &&
        other.startOffset == startOffset &&
        other.endOffset == endOffset &&
        other.exactExcerpt == exactExcerpt;
  }

  @override
  int get hashCode =>
      Object.hash(snapshotId, startOffset, endOffset, exactExcerpt);

  @override
  String toString() {
    // Diagnostic output avoids exposing excerpt text in logs.
    return 'EvidenceReference(snapshot: $snapshotId, span: [$startOffset, $endOffset), length: ${exactExcerpt.length})';
  }
}
