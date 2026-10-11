import '../../domain/models/input_source.dart';
import '../../domain/models/text_snapshot.dart';

/// Codec for encoding and strictly decoding [TextSnapshot] instances to/from JSON maps.
class TextSnapshotCodec {
  const TextSnapshotCodec();

  /// Encodes a [TextSnapshot] into a version-1 JSON-compatible map.
  Map<String, dynamic> encode(TextSnapshot snapshot) {
    return {
      'id': snapshot.id,
      'source': snapshot.source.toSerializedString(),
      'text': snapshot.text,
      'createdAt': snapshot.createdAt.toIso8601String(),
    };
  }

  /// Strictly decodes a JSON map into a [TextSnapshot].
  ///
  /// Throws [FormatException] if:
  /// - Required fields are missing or have incorrect types.
  /// - [source] is an unknown enum name.
  /// - [createdAt] is malformed or lacks explicit timezone indicator.
  /// - [id] fails invariant checks.
  TextSnapshot decode(Map<String, dynamic> json) {
    final idValue = json['id'];
    if (idValue is! String) {
      throw const FormatException(
        'TextSnapshot "id" must be a non-null String.',
      );
    }

    final sourceValue = json['source'];
    if (sourceValue is! String) {
      throw const FormatException(
        'TextSnapshot "source" must be a non-null String.',
      );
    }
    final source = InputSource.fromSerializedString(sourceValue);

    final textValue = json['text'];
    if (textValue is! String) {
      throw const FormatException(
        'TextSnapshot "text" must be a non-null String.',
      );
    }

    final createdAtValue = json['createdAt'];
    if (createdAtValue is! String) {
      throw const FormatException(
        'TextSnapshot "createdAt" must be a non-null String.',
      );
    }
    final createdAt = parseUtcTimestamp(createdAtValue, 'createdAt');

    try {
      return TextSnapshot(
        id: idValue,
        source: source,
        text: textValue,
        createdAt: createdAt,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Invalid TextSnapshot: ${e.message}');
    }
  }

  /// Parses an ISO-8601 timestamp and enforces UTC normalization and explicit timezone presence.
  static DateTime parseUtcTimestamp(String raw, String fieldName) {
    final upper = raw.toUpperCase();
    final tIndex = upper.indexOf('T');
    if (tIndex == -1) {
      throw FormatException(
        '$fieldName must be a full ISO-8601 date-time string with time component.',
      );
    }
    final timePart = upper.substring(tIndex + 1);
    final hasTimezone =
        timePart.contains('Z') ||
        timePart.contains('+') ||
        timePart.contains('-');
    if (!hasTimezone) {
      throw FormatException(
        '$fieldName must include explicit timezone information (e.g. "Z" or offset).',
      );
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('$fieldName is not a valid ISO-8601 timestamp.');
    }
    return parsed.toUtc();
  }
}
