import 'input_source.dart';

/// Immutable snapshot of exact digital communication text prepared for
/// review and analysis.
///
/// Invariants:
/// - [id] must be caller-supplied and non-empty. IDs are never invisibly
///   generated during construction or serialization to guarantee deterministic tests.
/// - [text] preserves the exact user input without trimming, normalization,
///   or redaction. Any subsequent edit must produce a distinct snapshot ID so
///   evidence references cannot silently drift or point to altered text.
/// - [text] may be empty to represent an initial draft. Later submission validation
///   decides whether a snapshot contains actionable content for analysis.
/// - [createdAt] is stored strictly in UTC.
/// - Does not store raw file bytes, on-device paths, credentials, or consent flags.
class TextSnapshot {
  final String id;
  final InputSource source;
  final String text;
  final DateTime createdAt;

  TextSnapshot({
    required this.id,
    required this.source,
    required this.text,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Snapshot ID must not be empty.');
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextSnapshot &&
        other.id == id &&
        other.source == source &&
        other.text == text &&
        other.createdAt.isAtSameMomentAs(createdAt);
  }

  @override
  int get hashCode =>
      Object.hash(id, source, text, createdAt.microsecondsSinceEpoch);

  @override
  String toString() {
    // Diagnostic output avoids exposing raw submitted text in logs.
    return 'TextSnapshot(id: $id, source: ${source.name}, textLength: ${text.length}, createdAt: ${createdAt.toIso8601String()})';
  }
}
