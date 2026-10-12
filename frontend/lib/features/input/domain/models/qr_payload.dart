import 'link_inspection_result.dart';

/// The recognized classification of decoded QR code contents.
enum QrPayloadType {
  /// Payload parsed as a web address (http or https).
  url,

  /// Payload contains plain text or non-web alphanumeric content.
  plainText,

  /// Payload is an unsupported action type (e.g. Wi-Fi config, vCard, payment intent, binary).
  unsupported,
}

/// Represents one distinct QR code payload decoded from an image.
class QrPayload {
  const QrPayload({
    required this.rawValue,
    required this.byteCount,
    required this.type,
    required this.summary,
    this.isOversized = false,
    this.linkInspection,
    this.formatDescription = 'Plain Text',
  });

  /// The exact decoded text value.
  final String rawValue;

  /// The size of the raw decoded payload in UTF-8 bytes.
  final int byteCount;

  /// The semantic type classification of this payload.
  final QrPayloadType type;

  /// A short single-line summary or preview of the decoded contents.
  final String summary;

  /// Whether the decoded payload exceeds the maximum 4,096-byte limit.
  final bool isOversized;

  /// The link inspection details if this payload represents a web address.
  final LinkInspectionResult? linkInspection;

  /// Human-readable label for payload type.
  final String formatDescription;

  @override
  String toString() => 'QrPayload(type: ${type.name}, bytes: $byteCount)';
}
