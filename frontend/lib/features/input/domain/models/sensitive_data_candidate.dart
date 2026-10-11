import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_type.dart';

/// Represents a detected span of potentially sensitive information suggested for redaction.
class SensitiveDataCandidate {
  const SensitiveDataCandidate({
    required this.id,
    required this.type,
    required this.startIndex,
    required this.endIndex,
    required this.matchedText,
    required this.maskedLabel,
    required this.contextSummary,
    required this.revision,
  }) : assert(startIndex >= 0, 'startIndex must be non-negative'),
       assert(
         endIndex > startIndex,
         'endIndex must be strictly greater than startIndex',
       );

  /// Unique identifier within the detection session (e.g. "cand-1").
  final String id;

  /// The category of sensitive data detected.
  final SensitiveDataType type;

  /// Start-inclusive UTF-16 code unit offset in the source text.
  final int startIndex;

  /// End-exclusive UTF-16 code unit offset in the source text.
  final int endIndex;

  /// The exact substring matched at `[startIndex, endIndex]`.
  final String matchedText;

  /// A masked representation for safe UI display (e.g. `j***@gmail.com`, `•••• 4567`).
  final String maskedLabel;

  /// A snippet of surrounding text with the sensitive value masked to provide identification context.
  final String contextSummary;

  /// The review text revision identifier associated with this detection.
  final String revision;

  int get length => endIndex - startIndex;

  /// Returns true if this candidate's offset span overlaps with [other].
  bool overlaps(SensitiveDataCandidate other) {
    return startIndex < other.endIndex && endIndex > other.startIndex;
  }

  /// Verifies that this candidate accurately aligns with the provided [text]
  /// and does not split a Unicode surrogate pair.
  bool isValidIn(String text) {
    if (startIndex < 0 || endIndex > text.length || startIndex >= endIndex) {
      return false;
    }
    if (text.substring(startIndex, endIndex) != matchedText) {
      return false;
    }
    // Verify surrogate boundaries: do not split a surrogate pair
    if (_isSurrogate(text, startIndex) || _isSurrogate(text, endIndex)) {
      return false;
    }
    return true;
  }

  static bool _isSurrogate(String text, int index) {
    if (index <= 0 || index >= text.length) return false;
    final prev = text.codeUnitAt(index - 1);
    final curr = text.codeUnitAt(index);
    // 0xD800 to 0xDBFF is high surrogate, 0xDC00 to 0xDFFF is low surrogate
    return (prev >= 0xD800 && prev <= 0xDBFF) &&
        (curr >= 0xDC00 && curr <= 0xDFFF);
  }

  /// Masks string values to protect sensitive content in logs and diagnostics.
  @override
  String toString() {
    return 'SensitiveDataCandidate(id: $id, type: ${type.name}, range: [$startIndex, $endIndex], masked: $maskedLabel, rev: $revision)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensitiveDataCandidate &&
        other.id == id &&
        other.type == type &&
        other.startIndex == startIndex &&
        other.endIndex == endIndex &&
        other.matchedText == matchedText &&
        other.revision == revision;
  }

  @override
  int get hashCode =>
      Object.hash(id, type, startIndex, endIndex, matchedText, revision);
}
