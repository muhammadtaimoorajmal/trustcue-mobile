import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Immutable result of on-device OCR text extraction from an image.
///
/// An [OcrResult] holds unreviewed extracted text. Its presence does NOT imply
/// that the user has reviewed or approved the text, that the content is safe,
/// or that consent has been given to transmit the text.
class OcrResult {
  final TextSnapshot snapshot;
  final String imageRevision;
  final String script;
  final DateTime extractionTimestamp;
  final List<String> limitations;

  OcrResult({
    required this.snapshot,
    required this.imageRevision,
    this.script = 'latin',
    required this.extractionTimestamp,
    List<String>? limitations,
  }) : limitations = List.unmodifiable(limitations ?? defaultLimitations);

  /// Default explicit limitations for TrustCue on-device OCR.
  static const List<String> defaultLimitations = [
    'Latin-script text only (including English).',
    'Urdu and Arabic text in images are not supported yet.',
    'Extracted text is unreviewed and may miss or misread words.',
    'Extraction does not imply safety or scam analysis.',
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrResult &&
          other.snapshot == snapshot &&
          other.imageRevision == imageRevision &&
          other.script == script &&
          other.extractionTimestamp == extractionTimestamp);

  @override
  int get hashCode =>
      Object.hash(snapshot, imageRevision, script, extractionTimestamp);

  @override
  String toString() =>
      'OcrResult(revision: $imageRevision, script: $script, timestamp: $extractionTimestamp)';
}
