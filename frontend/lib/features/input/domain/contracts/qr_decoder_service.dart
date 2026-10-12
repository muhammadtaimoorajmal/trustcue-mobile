import '../models/qr_decode_result.dart';

/// Contract for scanning and decoding QR codes from an on-device image file.
abstract class QrDecoderService {
  /// Scans the image at [filePath] strictly for QR codes.
  ///
  /// Returns a [QrDecodeResult] containing any detected and deduplicated payloads.
  /// Implementations must not automatically open any decoded links or execute actions.
  Future<QrDecodeResult> decode(String filePath, {String? operationToken});
}
