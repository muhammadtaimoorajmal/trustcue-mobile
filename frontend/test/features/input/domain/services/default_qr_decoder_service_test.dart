import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:trustcue_mobile/features/input/data/services/default_qr_decoder_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/qr_payload.dart';

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
  final String id = 'fake-id';
  final List<Barcode> barcodes;
  final bool shouldThrow;
  bool closed = false;

  @override
  Future<List<Barcode>> processImage(InputImage inputImage) async {
    if (shouldThrow) {
      throw Exception('Hardware decoder crash');
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
  late File sampleFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qr_test_');
    sampleFile = File('${tempDir.path}/qr.png');
    await sampleFile.writeAsString('dummy bytes');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('returns error when file does not exist', () async {
    final service = DefaultQrDecoderService();
    final res = await service.decode('${tempDir.path}/missing.png');
    expect(res.errorMessage, isNotNull);
    expect(res.isEmpty, isTrue);
  });

  test('returns empty result when no barcodes are found', () async {
    late _FakeBarcodeScanner scanner;
    final service = DefaultQrDecoderService(
      scannerFactory: () {
        scanner = _FakeBarcodeScanner(barcodes: const <Barcode>[]);
        return scanner;
      },
    );

    final res = await service.decode(sampleFile.path);
    expect(res.isEmpty, isTrue);
    expect(res.hasMultiple, isFalse);
    expect(scanner.closed, isTrue);
  });

  test('decodes single web URL QR code', () async {
    late _FakeBarcodeScanner scanner;
    final service = DefaultQrDecoderService(
      scannerFactory: () {
        scanner = _FakeBarcodeScanner(
          barcodes: [_FakeBarcode('https://example.com/login?token=abc')],
        );
        return scanner;
      },
    );

    final res = await service.decode(sampleFile.path);
    expect(res.hasSingle, isTrue);
    final payload = res.payloads.first;
    expect(payload.type, QrPayloadType.url);
    expect(payload.formatDescription, 'Web Address');
    expect(payload.linkInspection, isNotNull);
    expect(payload.linkInspection!.isLaunchable, isTrue);
    expect(payload.linkInspection!.host, 'example.com');
    expect(scanner.closed, isTrue);
  });

  test('deduplicates identical duplicate codes', () async {
    final service = DefaultQrDecoderService(
      scannerFactory: () => _FakeBarcodeScanner(
        barcodes: [
          _FakeBarcode('https://example.com'),
          _FakeBarcode('https://example.com'),
        ],
      ),
    );

    final res = await service.decode(sampleFile.path);
    expect(res.payloads.length, 1);
  });

  test('categorizes multiple distinct QR codes', () async {
    final service = DefaultQrDecoderService(
      scannerFactory: () => _FakeBarcodeScanner(
        barcodes: [
          _FakeBarcode('https://first.com'),
          _FakeBarcode('Plain message text snippet'),
        ],
      ),
    );

    final res = await service.decode(sampleFile.path);
    expect(res.hasMultiple, isTrue);
    expect(res.payloads[0].type, QrPayloadType.url);
    expect(res.payloads[1].type, QrPayloadType.plainText);
  });

  test('categorizes unsupported payloads (Wi-Fi, vCard, intent)', () async {
    final service = DefaultQrDecoderService(
      scannerFactory: () => _FakeBarcodeScanner(
        barcodes: [
          _FakeBarcode('WIFI:S:MyWifi;P:Secret;;'),
          _FakeBarcode('BEGIN:VCARD\nFN:John Doe\nEND:VCARD'),
          _FakeBarcode('upi://pay?pa=test@upi'),
        ],
      ),
    );

    final res = await service.decode(sampleFile.path);
    expect(res.payloads.length, 3);
    expect(res.payloads[0].type, QrPayloadType.unsupported);
    expect(res.payloads[0].formatDescription, 'Wi-Fi Configuration');
    expect(res.payloads[1].type, QrPayloadType.unsupported);
    expect(res.payloads[1].formatDescription, 'Contact Card');
    expect(res.payloads[2].type, QrPayloadType.unsupported);
    expect(res.payloads[2].formatDescription, 'Payment Intent');
  });

  test(
    'flags oversized payloads exceeding 4,096 bytes as unsupported',
    () async {
      final bigText = 'text: ${'a' * 4100}';
      final service = DefaultQrDecoderService(
        scannerFactory: () =>
            _FakeBarcodeScanner(barcodes: [_FakeBarcode(bigText)]),
      );

      final res = await service.decode(sampleFile.path);
      expect(res.payloads.first.isOversized, isTrue);
      expect(res.payloads.first.type, QrPayloadType.unsupported);
      expect(res.payloads.first.formatDescription, 'Oversized Payload');
    },
  );

  test('handles scanner exception gracefully and closes scanner', () async {
    late _FakeBarcodeScanner scanner;
    final service = DefaultQrDecoderService(
      scannerFactory: () {
        scanner = _FakeBarcodeScanner(shouldThrow: true);
        return scanner;
      },
    );

    final res = await service.decode(sampleFile.path);
    expect(res.errorMessage, contains('Hardware decoder crash'));
    expect(scanner.closed, isTrue);
  });
}
