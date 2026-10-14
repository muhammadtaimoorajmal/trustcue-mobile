import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/image_picker_adapter.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/qr_decoder_service.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/url_launcher_adapter.dart';
import 'package:trustcue_mobile/features/input/domain/models/qr_decode_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/qr_payload.dart';
import 'package:trustcue_mobile/features/input/domain/models/selected_image_descriptor.dart';
import 'package:trustcue_mobile/features/input/domain/services/url_inspection_service.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_link_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_link_screen.dart';

class _FakeUrlLauncherAdapter implements UrlLauncherAdapter {
  Uri? lastLaunched;
  @override
  Future<bool> canLaunch(Uri url) async => true;

  @override
  Future<bool> launch(Uri url) async {
    lastLaunched = url;
    return true;
  }
}

class _FakeQrDecoderService implements QrDecoderService {
  QrDecodeResult? resultToReturn;

  @override
  Future<QrDecodeResult> decode(
    String filePath, {
    String? operationToken,
  }) async {
    return resultToReturn ?? QrDecodeResult.empty();
  }
}

class _FakeImagePickerAdapter implements ImagePickerAdapter {
  @override
  Future<XFile?> pickImage() async => null;

  @override
  Future<LostDataResponse?> retrieveLostData() async => null;
}

class _FakeScreenshotStorageService implements ScreenshotStorageService {
  @override
  Future<Directory> getScreenshotDirectory() async => Directory.systemTemp;

  @override
  Future<File> importCandidateFile(
    XFile sourceFile, {
    String? fileExtension,
  }) async => File('dummy.png');

  @override
  Future<bool> deleteOwnedFile(String filePath) async => true;

  @override
  Future<int> cleanupOrphanFiles({
    Set<String> keepFilePaths = const {},
  }) async => 0;
}

Widget createTestWidget({
  required InputLinkController controller,
  Widget Function(BuildContext, String)? imageBuilder,
}) {
  Get.replace<InputLinkController>(controller);

  return GetMaterialApp(
    theme: AppTheme.lightTheme,
    home: InputLinkScreen(
      imageBuilder:
          imageBuilder ??
          (context, path) => const SizedBox(
            key: Key('mock_image_widget'),
            height: 100,
            width: 100,
          ),
    ),
  );
}

void main() {
  late _FakeUrlLauncherAdapter launcher;
  late _FakeQrDecoderService qrDecoder;

  setUp(() {
    Get.reset();
    launcher = _FakeUrlLauncherAdapter();
    qrDecoder = _FakeQrDecoderService();
  });

  tearDown(() {
    Get.reset();
  });

  InputLinkController createController() {
    return InputLinkController(
      urlInspector: const UrlInspectionService(),
      qrDecoderService: qrDecoder,
      urlLauncher: launcher,
      pickerAdapter: _FakeImagePickerAdapter(),
      storageService: _FakeScreenshotStorageService(),
      idGenerator: () => 'test-id',
    );
  }

  testWidgets('renders screen title, guidance banner, and mode selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = createController();
    await tester.pumpWidget(createTestWidget(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Link or QR code'), findsOneWidget);
    expect(
      find.text(
        'Link inspection and local checks are available. Results are indicators, not a verdict.',
      ),
      findsOneWidget,
    );
    expect(find.text('Safety reminder'), findsOneWidget);
    expect(find.text('Web address'), findsAtLeastNWidgets(1));
    expect(find.text('QR image'), findsOneWidget);
    expect(find.text('Inspect link'), findsOneWidget);
  });

  testWidgets(
    'inspects typed link and displays destination review with confirmation dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = createController();
      await tester.pumpWidget(createTestWidget(controller: controller));
      await tester.pumpAndSettle();

      // Enter a valid URL
      await tester.enterText(
        find.widgetWithText(TextField, 'Destination URL'),
        'https://example.com/welcome',
      );
      await tester.pumpAndSettle();

      // Tap inspect link
      await tester.ensureVisible(find.text('Inspect link'));
      await tester.tap(find.text('Inspect link'));
      await tester.pumpAndSettle();

      // Destination review section should appear
      expect(find.text('Destination Review'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
      expect(
        find.text('Destination is eligible for external opening.'),
        findsOneWidget,
      );
      expect(find.text('Open externally'), findsOneWidget);

      // Tap Open externally to prompt confirmation dialog
      await tester.ensureVisible(find.text('Open externally'));
      await tester.tap(find.text('Open externally'));
      await tester.pumpAndSettle();

      expect(find.text('Open in external browser?'), findsOneWidget);
      expect(find.text('Open destination'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Open destination
      await tester.ensureVisible(find.text('Open destination'));
      await tester.tap(find.text('Open destination'));
      await tester.pumpAndSettle();

      expect(launcher.lastLaunched.toString(), 'https://example.com/welcome');
      expect(find.text('Open in external browser?'), findsNothing);
    },
  );

  testWidgets(
    'switches to QR tab, shows image preview, and decodes QR payload',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = createController();
      await tester.pumpWidget(createTestWidget(controller: controller));
      await tester.pumpAndSettle();

      // Switch to QR image mode
      await tester.ensureVisible(find.text('QR image'));
      await tester.tap(find.text('QR image'));
      await tester.pumpAndSettle();

      expect(find.text('Choose QR image'), findsOneWidget);

      // Simulate an image selected
      controller.selectedQrImage.value = SelectedImageDescriptor(
        id: 'qr-1',
        format: ImageFormat.png,
        width: 800,
        height: 800,
        byteCount: 50000,
        filePath: '/tmp/test_qr.png',
      );
      await tester.pumpAndSettle();

      expect(find.text('Selected QR image'), findsOneWidget);
      expect(find.text('Decode QR code'), findsOneWidget);
      expect(find.byKey(const Key('mock_image_widget')), findsOneWidget);

      // Setup fake QR decode result
      qrDecoder.resultToReturn = QrDecodeResult(
        payloads: [
          QrPayload(
            rawValue: 'https://trustcue.test/dashboard',
            byteCount: 32,
            type: QrPayloadType.url,
            summary: 'https://trustcue.test/dashboard',
            linkInspection: const UrlInspectionService().inspect(
              'https://trustcue.test/dashboard',
            ),
          ),
        ],
      );

      // Tap Decode QR code
      await tester.ensureVisible(find.text('Decode QR code'));
      await tester.tap(find.text('Decode QR code'));
      await tester.pumpAndSettle();

      expect(find.text('Decoded QR code'), findsOneWidget);
      expect(find.text('Destination Review'), findsOneWidget);
      expect(find.text('trustcue.test'), findsOneWidget);
    },
  );

  testWidgets('displays list when multiple distinct QR codes are found', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = createController();
    await tester.pumpWidget(createTestWidget(controller: controller));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('QR image'));
    await tester.tap(find.text('QR image'));
    await tester.pumpAndSettle();

    controller.selectedQrImage.value = SelectedImageDescriptor(
      id: 'qr-multi',
      format: ImageFormat.png,
      width: 800,
      height: 800,
      byteCount: 50000,
      filePath: '/tmp/test_qr.png',
    );
    await tester.pumpAndSettle();

    qrDecoder.resultToReturn = QrDecodeResult(
      payloads: [
        const QrPayload(
          rawValue: 'https://first-code.com',
          byteCount: 22,
          type: QrPayloadType.url,
          summary: 'https://first-code.com',
        ),
        const QrPayload(
          rawValue: 'https://second-code.com',
          byteCount: 23,
          type: QrPayloadType.url,
          summary: 'https://second-code.com',
        ),
      ],
    );

    await tester.ensureVisible(find.text('Decode QR code'));
    await tester.tap(find.text('Decode QR code'));
    await tester.pumpAndSettle();

    expect(find.text('Detected 2 QR codes'), findsOneWidget);
    expect(find.text('https://first-code.com'), findsOneWidget);
    expect(find.text('https://second-code.com'), findsOneWidget);
  });
}
