import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/auth/data/services/avatar_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvatarImageService Validation & Format Detection', () {
    late Uint8List validJpeg;
    late Uint8List validPng;
    late Uint8List validWebp;
    late Uint8List textFileBytes;
    late Uint8List exeBytes;

    setUp(() {
      // Minimal valid JPEG header: FF D8 FF E0 00 10 4A 46 49 46 00 01
      validJpeg = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
        0x00,
        0x01,
        0x01,
        0x01,
        0x00,
        0x48,
      ]);

      // Minimal valid PNG header: 89 50 4E 47 0D 0A 1A 0A 00 00 00 0D
      validPng = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
      ]);

      // Minimal valid WebP header: 'RIFF' size 'WEBP'
      validWebp = Uint8List.fromList([
        0x52,
        0x49,
        0x46,
        0x46,
        0x24,
        0x00,
        0x00,
        0x00,
        0x57,
        0x45,
        0x42,
        0x50,
        0x56,
        0x50,
        0x38,
        0x20,
      ]);

      textFileBytes = Uint8List.fromList(
        'This is a plain text file pretending to be an avatar image.'.codeUnits,
      );

      exeBytes = Uint8List.fromList([
        0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00, // MZ header
      ]);
    });

    test('detects JPEG format from magic bytes', () {
      final format = AvatarImageService.detectFormat(validJpeg);
      expect(format, equals(AvatarFormat.jpeg));
      expect(format?.mimeType, equals('image/jpeg'));
    });

    test('detects PNG format from magic bytes', () {
      final format = AvatarImageService.detectFormat(validPng);
      expect(format, equals(AvatarFormat.png));
      expect(format?.mimeType, equals('image/png'));
    });

    test('detects WebP format from magic bytes', () {
      final format = AvatarImageService.detectFormat(validWebp);
      expect(format, equals(AvatarFormat.webp));
      expect(format?.mimeType, equals('image/webp'));
    });

    test('rejects non-image formats (text, executable)', () {
      expect(AvatarImageService.detectFormat(textFileBytes), isNull);
      expect(AvatarImageService.detectFormat(exeBytes), isNull);
    });

    test('validate accepts valid JPEG, PNG, and WebP', () {
      expect(AvatarImageService.validate(validJpeg).isSuccess, isTrue);
      expect(AvatarImageService.validate(validPng).isSuccess, isTrue);
      expect(AvatarImageService.validate(validWebp).isSuccess, isTrue);
    });

    test('validate rejects empty byte array', () {
      final res = AvatarImageService.validate(Uint8List(0));
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull?.message, contains('empty'));
    });

    test('validate rejects files exceeding 2MB ceiling', () {
      // 2MB + 1 byte
      final oversizedBytes = Uint8List(2 * 1024 * 1024 + 1);
      // Give it PNG magic header
      oversizedBytes[0] = 0x89;
      oversizedBytes[1] = 0x50;
      oversizedBytes[2] = 0x4E;
      oversizedBytes[3] = 0x47;
      oversizedBytes[4] = 0x0D;
      oversizedBytes[5] = 0x0A;
      oversizedBytes[6] = 0x1A;
      oversizedBytes[7] = 0x0A;

      final res = AvatarImageService.validate(oversizedBytes);
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull?.message, contains('exceeds the 2MB limit'));
    });

    test('validate rejects unrecognized format with helpful guidance', () {
      final res = AvatarImageService.validate(textFileBytes);
      expect(res.isFailure, isTrue);
      expect(
        res.failureOrNull?.message,
        contains('Allowed formats: JPEG, PNG, or WebP'),
      );
    });

    test('uploadAvatar formats path under user ID prefix', () async {
      final service = AvatarImageService();
      final res = await service.uploadAvatar(
        userId: 'user-uuid-1234',
        imageBytes: validPng,
      );

      expect(res.isSuccess, isTrue);
      final path = res.valueOrNull!;
      expect(path, startsWith('user-uuid-1234/avatar_'));
      expect(path, endsWith('.png'));
    });

    test(
      'uploadAvatar fails early on invalid format without network call',
      () async {
        final service = AvatarImageService();
        final res = await service.uploadAvatar(
          userId: 'user-uuid-1234',
          imageBytes: exeBytes,
        );

        expect(res.isFailure, isTrue);
        expect(res.failureOrNull?.message, contains('Allowed formats'));
      },
    );
  });
}
