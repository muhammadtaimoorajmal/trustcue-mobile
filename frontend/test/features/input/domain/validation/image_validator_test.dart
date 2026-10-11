import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/input/domain/models/selected_image_descriptor.dart';
import 'package:trustcue_mobile/features/input/domain/validation/image_validation_policy.dart';
import 'package:trustcue_mobile/features/input/domain/validation/image_validator.dart';

void main() {
  group('ImageValidator', () {
    final validPng = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x04, 0x38, // width = 1080
      0x00, 0x00, 0x09, 0x60, // height = 2400
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
      0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

    final validJpeg = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0,
      0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
      0x00, 0x01, 0x00, 0x00,
      0xFF, 0xC0, // SOF0
      0x00, 0x0B,
      0x08,
      0x07, 0x80, // height = 1920
      0x04, 0x38, // width = 1080
      0x01, 0x01, 0x11, 0x00,
      0xFF, 0xD9, // EOI
    ]);

    test('Accepts valid static PNG and parses dimensions accurately', () {
      final result = ImageValidator.validateBytes(validPng);

      expect(result.isValid, isTrue);
      expect(result.format, ImageFormat.png);
      expect(result.width, 1080);
      expect(result.height, 2400);
      expect(result.byteCount, validPng.length);
      expect(result.error, isNull);
    });

    test('Accepts valid static JPEG and parses dimensions accurately', () {
      final result = ImageValidator.validateBytes(validJpeg);

      expect(result.isValid, isTrue);
      expect(result.format, ImageFormat.jpeg);
      expect(result.width, 1080);
      expect(result.height, 1920);
      expect(result.byteCount, validJpeg.length);
      expect(result.error, isNull);
    });

    test('Rejects empty byte array', () {
      final result = ImageValidator.validateBytes(Uint8List(0));

      expect(result.isValid, isFalse);
      expect(result.error?.reason, ImageValidationReason.emptyFile);
      expect(result.error?.message, contains('empty'));
    });

    test('Rejects bytes exceeding 10 MiB limit', () {
      final oversizedBytes = Uint8List(ImageValidationPolicy.maxByteCount + 1);
      final result = ImageValidator.validateBytes(oversizedBytes);

      expect(result.isValid, isFalse);
      expect(result.error?.reason, ImageValidationReason.fileTooLarge);
      expect(result.error?.message, contains('under 10 MB'));
    });

    test('Rejects non-image and unsupported formats (text, webp, pdf)', () {
      final textBytes = Uint8List.fromList('Not an image file'.codeUnits);
      final result = ImageValidator.validateBytes(textBytes);

      expect(result.isValid, isFalse);
      expect(result.error?.reason, ImageValidationReason.unsupportedFormat);
      expect(result.error?.message, contains('PNG or JPEG'));
    });

    test('Rejects animated GIF', () {
      final gifBytes = Uint8List.fromList([
        0x47,
        0x49,
        0x46,
        0x38,
        0x39,
        0x61,
        0x0A,
        0x00,
        0x0A,
        0x00,
      ]);
      final result = ImageValidator.validateBytes(gifBytes);

      expect(result.isValid, isFalse);
      expect(
        result.error?.reason,
        ImageValidationReason.animatedImageUnsupported,
      );
      expect(result.error?.message, contains('Animated GIF'));
    });

    test('Rejects animated PNG (APNG with acTL chunk)', () {
      final apngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x64,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x08, 0x61, 0x63, 0x54, 0x4C, // acTL chunk
        0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      final result = ImageValidator.validateBytes(apngBytes);

      expect(result.isValid, isFalse);
      expect(
        result.error?.reason,
        ImageValidationReason.animatedImageUnsupported,
      );
      expect(result.error?.message, contains('Animated PNG'));
    });

    test('Rejects PNG exceeding dimension limit (12,001 px)', () {
      final oversizedDimensionPng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x2E, 0xE1, // width = 12001
        0x00, 0x00, 0x00, 0x64, // height = 100
        0x08, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      final result = ImageValidator.validateBytes(oversizedDimensionPng);

      expect(result.isValid, isFalse);
      expect(result.error?.reason, ImageValidationReason.dimensionTooLarge);
      expect(result.error?.message, contains('12,000 pixels'));
    });

    test('Rejects image exceeding 20 megapixel limit', () {
      // 5,000 x 4,500 = 22.5 MP (> 20 MP)
      final excessivePixelsPng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x13, 0x88, // width = 5000
        0x00, 0x00, 0x11, 0x94, // height = 4500
        0x08, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      final result = ImageValidator.validateBytes(excessivePixelsPng);

      expect(result.isValid, isFalse);
      expect(result.error?.reason, ImageValidationReason.pixelCountTooLarge);
      expect(result.error?.message, contains('20 megapixel'));
    });

    test('Validates file on disk and detects missing file safely', () async {
      final missingFile = File('non_existent_file.png');
      final result = await ImageValidator.validateFile(missingFile);

      expect(result.isValid, isFalse);
      expect(result.error?.reason, ImageValidationReason.corruptOrUnreadable);
    });
  });
}
