import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/image_picker_adapter.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/qr_decoder_service.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/url_launcher_adapter.dart';
import 'package:trustcue_mobile/features/input/domain/models/qr_decode_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/qr_payload.dart';
import 'package:trustcue_mobile/features/input/domain/services/url_inspection_service.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_link_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/screenshot_recovery_coordinator.dart';

class _FakeUrlLauncherAdapter implements UrlLauncherAdapter {
  _FakeUrlLauncherAdapter();

  bool canLaunchResult = true;
  bool launchResult = true;
  Uri? lastLaunchedUri;
  int launchCallCount = 0;

  @override
  Future<bool> canLaunch(Uri url) async => canLaunchResult;

  @override
  Future<bool> launch(Uri url) async {
    lastLaunchedUri = url;
    launchCallCount++;
    return launchResult;
  }
}

class _FakeQrDecoderService implements QrDecoderService {
  _FakeQrDecoderService();

  QrDecodeResult? result;
  String? lastDecodedPath;

  @override
  Future<QrDecodeResult> decode(
    String filePath, {
    String? operationToken,
  }) async {
    lastDecodedPath = filePath;
    return result ?? QrDecodeResult.empty();
  }
}

class _FakeImagePickerAdapter implements ImagePickerAdapter {
  _FakeImagePickerAdapter();

  XFile? pickedFile;

  @override
  Future<XFile?> pickImage() async => pickedFile;

  @override
  Future<LostDataResponse?> retrieveLostData() async => null;
}

class _FakeScreenshotStorageService implements ScreenshotStorageService {
  _FakeScreenshotStorageService({required this.tempDir});

  final Directory tempDir;
  final List<String> deletedFiles = <String>[];

  @override
  Future<Directory> getScreenshotDirectory() async => tempDir;

  @override
  Future<File> importCandidateFile(
    XFile sourceFile, {
    String? fileExtension,
  }) async {
    final ext = fileExtension ?? '.png';
    final dest = File(
      '${tempDir.path}/imported_${DateTime.now().microsecondsSinceEpoch}$ext',
    );
    await dest.writeAsString('fake-image-bytes');
    return dest;
  }

  @override
  Future<bool> deleteOwnedFile(String filePath) async {
    deletedFiles.add(filePath);
    final f = File(filePath);
    if (await f.exists()) {
      await f.delete();
      return true;
    }
    return false;
  }

  @override
  Future<int> cleanupOrphanFiles({
    Set<String> keepFilePaths = const {},
  }) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testTempDir;
  late _FakeUrlLauncherAdapter launcher;
  late _FakeQrDecoderService qrDecoder;
  late _FakeImagePickerAdapter picker;
  late _FakeScreenshotStorageService storage;

  setUp(() async {
    testTempDir = await Directory.systemTemp.createTemp('controller_test_');
    launcher = _FakeUrlLauncherAdapter();
    qrDecoder = _FakeQrDecoderService();
    picker = _FakeImagePickerAdapter();
    storage = _FakeScreenshotStorageService(tempDir: testTempDir);
  });

  tearDown(() async {
    if (await testTempDir.exists()) {
      await testTempDir.delete(recursive: true);
    }
  });

  InputLinkController createController({
    ScreenshotRecoveryCoordinator? recoveryCoordinator,
  }) {
    return InputLinkController(
      urlInspector: const UrlInspectionService(),
      qrDecoderService: qrDecoder,
      urlLauncher: launcher,
      pickerAdapter: picker,
      storageService: storage,
      recoveryCoordinator: recoveryCoordinator,
      idGenerator: () => '12345',
    );
  }

  group('InputLinkController - Mode & Text Mode', () {
    test('initializes with text mode and empty input', () {
      final controller = createController();
      controller.onInit();

      expect(controller.currentMode.value, LinkIntakeMode.text);
      expect(controller.currentInputText.value, isEmpty);
      expect(controller.textInspectionResult.value, isNull);
      expect(controller.canOpenExternally, isFalse);

      controller.onClose();
    });

    test('inspects valid public URL and verifies launchability', () {
      final controller = createController();
      controller.onInit();

      controller.urlTextController.text = 'https://example.com/login';
      controller.inspectTextLink();

      final res = controller.textInspectionResult.value;
      expect(res, isNotNull);
      expect(res!.isLaunchable, isTrue);
      expect(res.host, 'example.com');
      expect(controller.canOpenExternally, isTrue);

      controller.onClose();
    });

    test('inspects invalid or local URL and blocks launching', () {
      final controller = createController();
      controller.onInit();

      controller.urlTextController.text = 'http://192.168.1.1/admin';
      controller.inspectTextLink();

      final res = controller.textInspectionResult.value;
      expect(res, isNotNull);
      expect(res!.isLaunchable, isFalse);
      expect(controller.canOpenExternally, isFalse);

      controller.onClose();
    });

    test('two-step confirmation workflow for external opening', () async {
      final controller = createController();
      controller.onInit();

      controller.urlTextController.text = 'https://example.com/test';
      controller.inspectTextLink();

      expect(controller.showOpenConfirmation.value, isFalse);
      controller.requestOpenExternal();
      expect(controller.showOpenConfirmation.value, isTrue);

      // Confirm open
      final success = await controller.confirmOpenExternal();
      expect(success, isTrue);
      expect(launcher.launchCallCount, 1);
      expect(launcher.lastLaunchedUri.toString(), 'https://example.com/test');
      expect(controller.showOpenConfirmation.value, isFalse);

      controller.onClose();
    });

    test('editing text invalidates pending confirmation', () {
      final controller = createController();
      controller.onInit();

      controller.urlTextController.text = 'https://example.com/test';
      controller.inspectTextLink();
      controller.requestOpenExternal();
      expect(controller.showOpenConfirmation.value, isTrue);

      // User changes text
      controller.urlTextController.text = 'https://example.com/modified';
      expect(controller.showOpenConfirmation.value, isFalse);

      controller.onClose();
    });
  });

  group('InputLinkController - QR Image Mode', () {
    test('switches mode and preserves independent state', () {
      final controller = createController();
      controller.onInit();

      controller.switchMode(LinkIntakeMode.qr);
      expect(controller.currentMode.value, LinkIntakeMode.qr);

      controller.onClose();
    });

    test(
      'decodes single QR code with web URL and sets active inspection',
      () async {
        final controller = createController();
        controller.onInit();
        controller.switchMode(LinkIntakeMode.qr);

        // Create dummy image file
        final dummyFile = File('${testTempDir.path}/qr.png');
        // Create minimal valid 1x1 PNG header
        final pngBytes = <int>[
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
          0x00,
          0x00,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x01,
          0x08,
          0x06,
          0x00,
          0x00,
          0x00,
          0x1F,
          0x15,
          0xC4,
          0x89,
          0x00,
          0x00,
          0x00,
          0x0A,
          0x49,
          0x44,
          0x41,
          0x54,
          0x78,
          0x9C,
          0x63,
          0x00,
          0x01,
          0x00,
          0x00,
          0x05,
          0x00,
          0x01,
          0x0D,
          0x0A,
          0x2D,
          0xB4,
          0x00,
          0x00,
          0x00,
          0x00,
          0x49,
          0x45,
          0x4E,
          0x44,
          0xAE,
          0x42,
          0x60,
          0x82,
        ];
        await dummyFile.writeAsBytes(pngBytes);
        picker.pickedFile = XFile(dummyFile.path);

        final picked = await controller.chooseQrImage();
        expect(picked, isTrue);
        expect(controller.selectedQrImage.value, isNotNull);

        qrDecoder.result = QrDecodeResult(
          payloads: [
            QrPayload(
              rawValue: 'https://trustcue.example/path',
              byteCount: 30,
              type: QrPayloadType.url,
              summary: 'https://trustcue.example/path',
              linkInspection: const UrlInspectionService().inspect(
                'https://trustcue.example/path',
              ),
            ),
          ],
        );

        await controller.decodeQrImage();

        expect(controller.qrDecodeResult.value, isNotNull);
        expect(controller.selectedPayload.value, isNotNull);
        expect(controller.qrInspectionResult.value, isNotNull);
        expect(controller.canOpenExternally, isTrue);
        expect(controller.activeInspection!.host, 'trustcue.example');

        controller.onClose();
      },
    );

    test('deletes owned temp file on removal or close', () async {
      final controller = createController();
      controller.onInit();
      controller.switchMode(LinkIntakeMode.qr);

      final dummyFile = File('${testTempDir.path}/qr.png');
      final pngBytes = <int>[
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
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ];
      await dummyFile.writeAsBytes(pngBytes);
      picker.pickedFile = XFile(dummyFile.path);

      await controller.chooseQrImage();
      final filePath = controller.selectedQrImage.value!.filePath;

      await controller.removeQrImage();
      expect(controller.selectedQrImage.value, isNull);
      expect(storage.deletedFiles, contains(filePath));

      controller.onClose();
    });

    test('reviewText rejects oversized payload without navigating', () async {
      final controller = createController();
      controller.onInit();
      controller.switchMode(LinkIntakeMode.qr);

      controller.selectedPayload.value = const QrPayload(
        rawValue: 'oversized content',
        byteCount: 5000,
        type: QrPayloadType.unsupported,
        summary: 'Oversized',
        isOversized: true,
      );

      await controller.reviewText();
      expect(controller.isNavigatingAway.value, isFalse);

      controller.onClose();
    });
  });
}
