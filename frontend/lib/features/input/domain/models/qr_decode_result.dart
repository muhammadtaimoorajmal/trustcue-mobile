import 'qr_payload.dart';

/// Aggregated result of scanning an image for QR codes.
class QrDecodeResult {
  const QrDecodeResult({required this.payloads, this.errorMessage});

  /// The list of distinct, deduplicated QR code payloads decoded from the image.
  final List<QrPayload> payloads;

  /// Error message if the scanner encountered an unrecoverable failure.
  final String? errorMessage;

  /// Whether no QR codes were detected in the image.
  bool get isEmpty => payloads.isEmpty;

  /// Whether more than one distinct QR code was detected in the image.
  bool get hasMultiple => payloads.length > 1;

  /// Whether exactly one QR code was detected.
  bool get hasSingle => payloads.length == 1;

  /// Empty result when no codes are found.
  factory QrDecodeResult.empty() =>
      const QrDecodeResult(payloads: <QrPayload>[]);

  /// Error result when an unexpected decoder exception occurred.
  factory QrDecodeResult.error(String message) =>
      QrDecodeResult(payloads: const <QrPayload>[], errorMessage: message);
}
