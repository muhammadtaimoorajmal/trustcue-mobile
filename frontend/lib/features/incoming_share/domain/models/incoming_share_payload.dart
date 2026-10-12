import 'package:flutter/foundation.dart';

/// The category of payload extracted from an Android incoming share.
enum IncomingShareType {
  /// A plain text message or web link candidate.
  text,

  /// A single PNG or JPEG image.
  image,

  /// Both a single image and an accompanying text caption/message.
  mixed,

  /// An unparseable, oversized, multi-item, or prohibited payload.
  unsupported,
}

/// Immutable domain descriptor of an incoming share event delivered by the OS.
@immutable
class IncomingSharePayload {
  IncomingSharePayload({
    required this.eventId,
    required this.type,
    this.text,
    this.stagedImagePath,
    this.mimeType,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a text-only payload.
  factory IncomingSharePayload.text({
    required String eventId,
    required String text,
    DateTime? timestamp,
  }) => IncomingSharePayload(
    eventId: eventId,
    type: IncomingShareType.text,
    text: text,
    timestamp: timestamp,
  );

  /// Creates a single-image payload.
  factory IncomingSharePayload.image({
    required String eventId,
    required String stagedImagePath,
    String? mimeType,
    DateTime? timestamp,
  }) => IncomingSharePayload(
    eventId: eventId,
    type: IncomingShareType.image,
    stagedImagePath: stagedImagePath,
    mimeType: mimeType,
    timestamp: timestamp,
  );

  /// Creates a mixed payload containing both an image and text.
  factory IncomingSharePayload.mixed({
    required String eventId,
    required String text,
    required String stagedImagePath,
    String? mimeType,
    DateTime? timestamp,
  }) => IncomingSharePayload(
    eventId: eventId,
    type: IncomingShareType.mixed,
    text: text,
    stagedImagePath: stagedImagePath,
    mimeType: mimeType,
    timestamp: timestamp,
  );

  /// Creates an unsupported or erroneous payload.
  factory IncomingSharePayload.unsupported({
    required String eventId,
    String? errorMessage,
    DateTime? timestamp,
  }) => IncomingSharePayload(
    eventId: eventId,
    type: IncomingShareType.unsupported,
    errorMessage: errorMessage,
    timestamp: timestamp,
  );

  /// Creates a payload instance from native platform channel dictionary.
  factory IncomingSharePayload.fromMap(Map<dynamic, dynamic> map) {
    final eventId = (map['eventId'] as String?) ?? 'event-fallback';
    final rawType = (map['type'] as String?)?.toLowerCase();
    final text = map['text'] as String?;
    final imagePath =
        (map['stagedImagePath'] as String?) ?? (map['imagePath'] as String?);
    final mimeType = map['mimeType'] as String?;
    final errorMessage = map['errorMessage'] as String?;

    final IncomingShareType type;
    switch (rawType) {
      case 'text':
        type = IncomingShareType.text;
      case 'image':
        type = IncomingShareType.image;
      case 'mixed':
        type = IncomingShareType.mixed;
      case 'unsupported':
      default:
        type = IncomingShareType.unsupported;
    }

    return IncomingSharePayload(
      eventId: eventId,
      type: type,
      text: text,
      stagedImagePath: imagePath,
      mimeType: mimeType,
      errorMessage: errorMessage,
    );
  }

  /// Unique event identifier generated at intent receipt for deduplication and acknowledgment.
  final String eventId;

  /// The categorized payload type.
  final IncomingShareType type;

  /// The validated, uninterpreted text content if present.
  final String? text;

  /// The path to the staged app-owned image file in app cache if present.
  final String? stagedImagePath;

  /// The verified MIME type (e.g., 'image/png' or 'image/jpeg') if an image is present.
  final String? mimeType;

  /// A safe explanation if the share was rejected or partially unparseable.
  final String? errorMessage;

  /// Receipt timestamp.
  final DateTime timestamp;

  /// Whether this payload was flagged as unsupported or contains an error.
  bool get isUnsupported =>
      type == IncomingShareType.unsupported || errorMessage != null;

  /// Whether text is available.
  bool get hasText => text != null && text!.trim().isNotEmpty;

  /// Whether a staged image is available.
  bool get hasImage => stagedImagePath != null && stagedImagePath!.isNotEmpty;

  /// Whether both text and image are present.
  bool get isMixed => type == IncomingShareType.mixed || (hasText && hasImage);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomingSharePayload &&
          runtimeType == other.runtimeType &&
          eventId == other.eventId &&
          type == other.type &&
          text == other.text &&
          stagedImagePath == other.stagedImagePath &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(eventId, type, text, stagedImagePath, errorMessage);

  @override
  String toString() =>
      'IncomingSharePayload(eventId: $eventId, type: $type, hasText: $hasText, hasImage: $hasImage, hasError: ${errorMessage != null})';
}
