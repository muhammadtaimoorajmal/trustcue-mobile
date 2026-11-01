import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:trustcue_mobile/features/input/data/services/default_qr_decoder_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/qr_payload.dart';
import 'package:trustcue_mobile/features/input/domain/services/url_inspection_service.dart';

/// Layer 1 Acceptance & Regression Test Suite for QR Intake and Safe Decoding.
///
/// Note on verification layer:
/// - This test suite evaluates pure-Dart mapping, security invariants, scheme protection,
///   boundary rules, and decoder classification on host/CI without requiring native Android
///   Google Play Services ML Kit binaries.
/// - Native ML Kit execution and physical UI verification are performed on hardware
///   (Vivo V2207, Android 14 API 34) and documented in fixture acceptance registers.
class _FakeBarcodeScanner implements BarcodeScanner {
  _FakeBarcodeScanner({
    this.barcodes = const <Barcode>[],
    this.shouldThrow = false,
  });

  @override
  final List<BarcodeFormat> formats = const <BarcodeFormat>[
    BarcodeFormat.qrCode,
  ];

  @override
  final String id = 'fake-qr-scanner';
  final List<Barcode> barcodes;
  final bool shouldThrow;
  bool closed = false;

  @override
  Future<List<Barcode>> processImage(InputImage inputImage) async {
    if (shouldThrow) {
      throw Exception('Native ML Kit barcode scanner processing error');
    }
    return barcodes;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _FakeBarcode implements Barcode {
  _FakeBarcode(this._raw);

  final String? _raw;

  @override
  String? get rawValue => _raw;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  late File sampleImageFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qr_acceptance_');
    sampleImageFile = File('${tempDir.path}/fixture_image.png');
    await sampleImageFile.writeAsBytes(<int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Layer 1 QR Acceptance: Real Fixture Corpus Mapping', () {
    test('Fixture 1 (images (3).jpg): Decodes valid web URL', () async {
      final service = DefaultQrDecoderService(
        scannerFactory: () => _FakeBarcodeScanner(
          barcodes: [_FakeBarcode('https://www.proofpoint.com')],
        ),
      );

      final result = await service.decode(sampleImageFile.path);
      expect(result.hasSingle, isTrue);
      final payload = result.payloads.first;
      expect(payload.type, QrPayloadType.url);
      expect(payload.formatDescription, 'Web Address');
      expect(payload.linkInspection, isNotNull);
      expect(payload.linkInspection!.host, 'www.proofpoint.com');
      expect(payload.linkInspection!.isLaunchable, isTrue);
    });

    test(
      'Fixture 2 (images (4).png): No QR code detected -> safe empty result',
      () async {
        final service = DefaultQrDecoderService(
          scannerFactory: () =>
              _FakeBarcodeScanner(barcodes: const <Barcode>[]),
        );

        final result = await service.decode(sampleImageFile.path);
        expect(result.isEmpty, isTrue);
        expect(result.payloads, isEmpty);
        expect(result.errorMessage, isNull);
      },
    );

    test('Fixture 3 (images (2).jpg): Plain text payload T7GHBY -> not launchable as URL', () async {
      final service = DefaultQrDecoderService(
        scannerFactory: () =>
            _FakeBarcodeScanner(barcodes: [_FakeBarcode('T7GHBY')]),
      );

      final result = await service.decode(sampleImageFile.path);
      expect(result.hasSingle, isTrue);
      final payload = result.payloads.first;
      expect(payload.type, QrPayloadType.plainText);
      expect(payload.formatDescription, 'Plain Text');
      expect(payload.rawValue, 'T7GHBY');
      expect(payload.linkInspection, isNull);
    });

    test('Fixture 4 (images (3).png): Decodes valid web URL', () async {
      final service = DefaultQrDecoderService(
        scannerFactory: () => _FakeBarcodeScanner(
          barcodes: [
            _FakeBarcode('https://informationsecurity.wustl.edu/news/'),
          ],
        ),
      );

      final result = await service.decode(sampleImageFile.path);
      expect(result.hasSingle, isTrue);
      final payload = result.payloads.first;
      expect(payload.type, QrPayloadType.url);
      expect(payload.linkInspection!.host, 'informationsecurity.wustl.edu');
      expect(payload.linkInspection!.isLaunchable, isTrue);
    });

    test(
      'Fixture 5 (images (1).jpg): No QR code detected -> safe empty result',
      () async {
        final service = DefaultQrDecoderService(
          scannerFactory: () =>
              _FakeBarcodeScanner(barcodes: const <Barcode>[]),
        );

        final result = await service.decode(sampleImageFile.path);
        expect(result.isEmpty, isTrue);
      },
    );

    test(
      'Fixture 6 (images (2).png): No QR code detected -> safe empty result',
      () async {
        final service = DefaultQrDecoderService(
          scannerFactory: () =>
              _FakeBarcodeScanner(barcodes: const <Barcode>[]),
        );

        final result = await service.decode(sampleImageFile.path);
        expect(result.isEmpty, isTrue);
      },
    );

    test('Fixture 7 (images (1).png): Decodes valid web URL', () async {
      final service = DefaultQrDecoderService(
        scannerFactory: () => _FakeBarcodeScanner(
          barcodes: [
            _FakeBarcode('https://blog.malwarebytes.com/author/metallicamvp/'),
          ],
        ),
      );

      final result = await service.decode(sampleImageFile.path);
      expect(result.hasSingle, isTrue);
      final payload = result.payloads.first;
      expect(payload.type, QrPayloadType.url);
      expect(payload.linkInspection!.host, 'blog.malwarebytes.com');
      expect(payload.linkInspection!.isLaunchable, isTrue);
    });

    test(
      'Fixture 8 (images.jpg): No QR code detected -> safe empty result',
      () async {
        final service = DefaultQrDecoderService(
          scannerFactory: () =>
              _FakeBarcodeScanner(barcodes: const <Barcode>[]),
        );

        final result = await service.decode(sampleImageFile.path);
        expect(result.isEmpty, isTrue);
      },
    );

    test('Fixture 9 (images.png): Decodes valid web URL', () async {
      final service = DefaultQrDecoderService(
        scannerFactory: () => _FakeBarcodeScanner(
          barcodes: [_FakeBarcode('https://scan.page/6866509157ad2')],
        ),
      );

      final result = await service.decode(sampleImageFile.path);
      expect(result.hasSingle, isTrue);
      final payload = result.payloads.first;
      expect(payload.type, QrPayloadType.url);
      expect(payload.linkInspection!.host, 'scan.page');
      expect(payload.linkInspection!.isLaunchable, isTrue);
    });
  });

  group('Layer 1 Supplementary Verification: Safety & Boundary Invariants', () {
    test('Missing file on disk returns error without crashing', () async {
      final service = DefaultQrDecoderService();
      final result = await service.decode(
        '${tempDir.path}/non_existent_file.png',
      );
      expect(result.isEmpty, isTrue);
      expect(result.errorMessage, contains('does not exist on device'));
    });

    test(
      'Hardware/engine crash throws exception gracefully and closes scanner',
      () async {
        late _FakeBarcodeScanner scanner;
        final service = DefaultQrDecoderService(
          scannerFactory: () {
            scanner = _FakeBarcodeScanner(shouldThrow: true);
            return scanner;
          },
        );

        final result = await service.decode(sampleImageFile.path);
        expect(
          result.errorMessage,
          contains('Native ML Kit barcode scanner processing error'),
        );
        expect(scanner.closed, isTrue);
      },
    );

    test('Deduplicates duplicate QR codes in single image', () async {
      final service = DefaultQrDecoderService(
        scannerFactory: () => _FakeBarcodeScanner(
          barcodes: [
            _FakeBarcode('https://trusted.org/info'),
            _FakeBarcode('https://trusted.org/info'),
            _FakeBarcode('https://trusted.org/info'),
          ],
        ),
      );

      final result = await service.decode(sampleImageFile.path);
      expect(result.payloads.length, 1);
      expect(result.hasMultiple, isFalse);
    });

    test(
      'Oversized payload exceeding 4,096 bytes marked unsupported',
      () async {
        final largePayload = 'https://example.com/data?q=${'x' * 4100}';
        final service = DefaultQrDecoderService(
          scannerFactory: () =>
              _FakeBarcodeScanner(barcodes: [_FakeBarcode(largePayload)]),
        );

        final result = await service.decode(sampleImageFile.path);
        expect(result.payloads.length, 1);
        final payload = result.payloads.first;
        expect(payload.isOversized, isTrue);
        expect(payload.type, QrPayloadType.unsupported);
        expect(payload.formatDescription, 'Oversized Payload');
      },
    );

    test('Dangerous schemes are strictly guarded and never classified as launchable web URLs', () async {
      final dangerousPayloads = <String>[
        'javascript:alert(document.cookie)',
        'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
        'file:///android_asset/secret.json',
        'intent://scan/#Intent;scheme=zxing;package=com.google.zxing.client.android;end',
        'upi://pay?pa=scam@bank&pn=Fraud&am=1000',
        'bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa?amount=50',
        'WIFI:S:FakeFreeWiFi;T:WPA;P:password123;;',
        'BEGIN:VCARD\nVERSION:3.0\nN:Malicious;VCard\nTEL:123456789\nEND:VCARD',
      ];

      for (final raw in dangerousPayloads) {
        final service = DefaultQrDecoderService(
          scannerFactory: () =>
              _FakeBarcodeScanner(barcodes: [_FakeBarcode(raw)]),
        );

        final result = await service.decode(sampleImageFile.path);
        expect(result.payloads.length, 1, reason: 'Failed for payload: $raw');
        final payload = result.payloads.first;

        // None of these should ever be a launchable Web Address
        expect(
          payload.type != QrPayloadType.url,
          isTrue,
          reason: 'Treated dangerous scheme as URL: $raw',
        );
        expect(
          payload.linkInspection?.isLaunchable ?? false,
          isFalse,
          reason: 'Marked launchable: $raw',
        );
      }
    });

    test('UrlInspectionService rejects dangerous schemes with specific unsupportedScheme code', () {
      const inspector = UrlInspectionService();

      final resJs = inspector.inspect('javascript:alert(1)');
      expect(resJs.isLaunchable, isFalse);
      expect(
        resJs.rejectionReason,
        contains('not supported for web navigation'),
      );

      final resFile = inspector.inspect('file:///etc/hosts');
      expect(resFile.isLaunchable, isFalse);
      expect(
        resFile.rejectionReason,
        contains('not supported for web navigation'),
      );

      final resData = inspector.inspect('data:text/html,test');
      expect(resData.isLaunchable, isFalse);
      expect(
        resData.rejectionReason,
        contains('not supported for web navigation'),
      );
    });
  });
}
