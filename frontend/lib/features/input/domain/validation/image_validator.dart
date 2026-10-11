import 'dart:io';
import 'dart:typed_data';

import '../models/selected_image_descriptor.dart';
import 'image_validation_policy.dart';

/// Pure-Dart validator that inspects image magic bytes, chunk metadata,
/// and dimension boundaries without loading excessive bitmaps into memory.
class ImageValidator {
  const ImageValidator._();

  /// Validates an image [file] on disk, verifying file size before reading.
  static Future<ImageValidationResult> validateFile(File file) async {
    try {
      if (!await file.exists()) {
        return const ImageValidationResult.invalid(
          ImageValidationError(
            reason: ImageValidationReason.corruptOrUnreadable,
            message: 'We couldn’t open this image. Please choose another.',
          ),
        );
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return const ImageValidationResult.invalid(
          ImageValidationError(
            reason: ImageValidationReason.emptyFile,
            message: 'The selected image is empty. Please choose another.',
          ),
        );
      }

      if (fileSize > ImageValidationPolicy.maxByteCount) {
        return const ImageValidationResult.invalid(
          ImageValidationError(
            reason: ImageValidationReason.fileTooLarge,
            message:
                'This image is too large. Choose a PNG or JPEG under 10 MB.',
          ),
        );
      }

      final bytes = await file.readAsBytes();
      return validateBytes(bytes);
    } catch (_) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.corruptOrUnreadable,
          message: 'We couldn’t open this image. Please choose another.',
        ),
      );
    }
  }

  /// Validates raw in-memory image [bytes].
  static ImageValidationResult validateBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.emptyFile,
          message: 'The selected image is empty. Please choose another.',
        ),
      );
    }

    if (bytes.length > ImageValidationPolicy.maxByteCount) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.fileTooLarge,
          message: 'This image is too large. Choose a PNG or JPEG under 10 MB.',
        ),
      );
    }

    // Check GIF
    if (_isGif(bytes)) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.animatedImageUnsupported,
          message: 'Animated GIF images are not supported. Choose a static PNG or JPEG screenshot.',
        ),
      );
    }

    // Check PNG
    if (_isPng(bytes)) {
      return _validatePng(bytes);
    }

    // Check JPEG
    if (_isJpeg(bytes)) {
      return _validateJpeg(bytes);
    }

    // Other unsupported formats (WebP, BMP, TIFF, text, etc.)
    return const ImageValidationResult.invalid(
      ImageValidationError(
        reason: ImageValidationReason.unsupportedFormat,
        message: 'Choose a PNG or JPEG image under 10 MB.',
      ),
    );
  }

  static bool _isPng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 && // P
        bytes[2] == 0x4E && // N
        bytes[3] == 0x47 && // G
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  static bool _isJpeg(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  }

  static bool _isGif(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46; // GIF
  }

  static ImageValidationResult _validatePng(Uint8List bytes) {
    // Minimum PNG header + IHDR chunk: 8 + 4 (len) + 4 (type) + 13 (data) + 4 (crc) = 33 bytes.
    if (bytes.length < 33) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.corruptOrUnreadable,
          message: 'We couldn’t open this image. Please choose another.',
        ),
      );
    }

    // Verify first chunk is IHDR
    if (bytes[12] != 0x49 ||
        bytes[13] != 0x48 ||
        bytes[14] != 0x44 ||
        bytes[15] != 0x52) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.corruptOrUnreadable,
          message: 'We couldn’t open this image. Please choose another.',
        ),
      );
    }

    final width = _readUint32(bytes, 16);
    final height = _readUint32(bytes, 20);

    // Scan chunks for acTL (Animated PNG)
    var offset = 8;
    while (offset + 8 <= bytes.length) {
      final chunkLen = _readUint32(bytes, offset);
      final c0 = bytes[offset + 4];
      final c1 = bytes[offset + 5];
      final c2 = bytes[offset + 6];
      final c3 = bytes[offset + 7];

      // acTL chunk marker (0x61, 0x63, 0x54, 0x4C)
      if (c0 == 0x61 && c1 == 0x63 && c2 == 0x54 && c3 == 0x4C) {
        return const ImageValidationResult.invalid(
          ImageValidationError(
            reason: ImageValidationReason.animatedImageUnsupported,
            message: 'Animated PNG images are not supported. Choose a static screenshot.',
          ),
        );
      }

      // Stop scanning once IDAT or IEND is reached to prevent parsing large data
      if ((c0 == 0x49 && c1 == 0x44 && c2 == 0x41 && c3 == 0x54) ||
          (c0 == 0x49 && c1 == 0x45 && c2 == 0x4E && c3 == 0x44)) {
        break;
      }

      offset +=
          8 + chunkLen + 4; // Length + Type (8) + Data (chunkLen) + CRC (4)
      if (chunkLen < 0 || offset < 0) break; // Overflow protection
    }

    return _evaluateDimensions(
      format: ImageFormat.png,
      width: width,
      height: height,
      byteCount: bytes.length,
    );
  }

  static ImageValidationResult _validateJpeg(Uint8List bytes) {
    var offset = 2;
    var width = 0;
    var height = 0;

    while (offset + 1 < bytes.length) {
      // Skip padding bytes
      while (offset < bytes.length && bytes[offset] == 0xFF) {
        offset++;
      }
      if (offset >= bytes.length) break;

      final marker = bytes[offset];
      offset++;

      // EOI (0xD9) or SOS (0xDA)
      if (marker == 0xD9 || marker == 0xDA) break;

      // Standalone markers
      if (marker >= 0xD0 && marker <= 0xD7) continue;

      if (offset + 1 >= bytes.length) break;
      final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
      if (segmentLength < 2) break;

      // Check SOF markers: SOF0..SOF15 except DHT(0xC4), JPG(0xC8), DAC(0xCC)
      final isSof =
          (marker >= 0xC0 && marker <= 0xCF) &&
          (marker != 0xC4 && marker != 0xC8 && marker != 0xCC);

      if (isSof && offset + 6 < bytes.length) {
        height = (bytes[offset + 3] << 8) | bytes[offset + 4];
        width = (bytes[offset + 5] << 8) | bytes[offset + 6];
        break;
      }

      offset += segmentLength;
    }

    if (width <= 0 || height <= 0) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.corruptOrUnreadable,
          message: 'We couldn’t open this image. Please choose another.',
        ),
      );
    }

    return _evaluateDimensions(
      format: ImageFormat.jpeg,
      width: width,
      height: height,
      byteCount: bytes.length,
    );
  }

  static ImageValidationResult _evaluateDimensions({
    required ImageFormat format,
    required int width,
    required int height,
    required int byteCount,
  }) {
    if (width <= 0 || height <= 0) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.invalidDimensions,
          message:
              'We couldn’t determine image dimensions. Choose another image.',
        ),
      );
    }

    if (width > ImageValidationPolicy.maxDimension ||
        height > ImageValidationPolicy.maxDimension) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.dimensionTooLarge,
          message: 'This image is too large. Choose an image under 12,000 pixels in width and height.',
        ),
      );
    }

    final pixelCount = width * height;
    if (pixelCount > ImageValidationPolicy.maxPixelCount) {
      return const ImageValidationResult.invalid(
        ImageValidationError(
          reason: ImageValidationReason.pixelCountTooLarge,
          message: 'This image exceeds the 20 megapixel limit. Choose a smaller screenshot.',
        ),
      );
    }

    return ImageValidationResult.valid(
      format: format,
      width: width,
      height: height,
      byteCount: byteCount,
    );
  }

  static int _readUint32(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}
