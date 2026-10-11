import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/image_picker_adapter.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/text_recognition_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_failure.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/selected_image_descriptor.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_screenshot_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_screenshot_screen.dart';

class FakePickerAdapter implements ImagePickerAdapter {
  XFile? candidateFile;
  @override
  Future<XFile?> pickImage() async => candidateFile;
  @override
  Future<LostDataResponse?> retrieveLostData() async => null;
}

class FakeStorageService implements ScreenshotStorageService {
  final List<String> deletedFiles = [];
  @override
  Future<Directory> getScreenshotDirectory() async => Directory.systemTemp;
  @override
  Future<File> importCandidateFile(
    XFile sourceFile, {
    String? fileExtension,
  }) async => File(sourceFile.path);
  @override
  Future<bool> deleteOwnedFile(String filePath) async {
    deletedFiles.add(filePath);
    return true;
  }

  @override
  Future<int> cleanupOrphanFiles({
    Set<String> keepFilePaths = const {},
  }) async => 0;
}

class FakeTextRecognitionService implements TextRecognitionService {
  Result<OcrResult>? nextResult;
  Completer<Result<OcrResult>>? inFlightCompleter;
  int processCalls = 0;
  final Set<String> cancelledTokens = {};

  @override
  Future<Result<OcrResult>> processImage({
    required String filePath,
    required String imageRevision,
    required String operationToken,
    Duration? timeout,
  }) async {
    processCalls++;
    if (inFlightCompleter != null) {
      return inFlightCompleter!.future;
    }
    return nextResult ??
        Result.success(
          OcrResult(
            snapshot: TextSnapshot(
              id: 'snap-1',
              source: InputSource.screenshot,
              text: 'Suspicious alert: Your account is locked.',
              createdAt: DateTime.now().toUtc(),
            ),
            imageRevision: imageRevision,
            extractionTimestamp: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<void> cancelOperation(String operationToken) async {
    cancelledTokens.add(operationToken);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late FakePickerAdapter fakePicker;
  late FakeStorageService fakeStorage;
  late FakeTextRecognitionService fakeOcr;
  late InputScreenshotController controller;
  late Directory tempDir;
  late File samplePng;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('screen_ocr_test_');
    samplePng = File('${tempDir.path}/test.png');
    samplePng.writeAsBytesSync([
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
      0x20,
      0x00,
      0x00,
      0x00,
      0x20,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);

    fakePicker = FakePickerAdapter();
    fakeStorage = FakeStorageService();
    fakeOcr = FakeTextRecognitionService();

    controller = InputScreenshotController(
      pickerAdapter: fakePicker,
      storageService: fakeStorage,
      ocrService: fakeOcr,
    );
  });

  tearDown(() {
    Get.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget createTestWidget({Brightness brightness = Brightness.light}) {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      initialRoute: AppRoutes.inputScreenshot,
      getPages: [
        GetPage(
          name: AppRoutes.home,
          page: () => const Scaffold(body: Text('Home Dashboard')),
        ),
        GetPage(
          name: AppRoutes.inputScreenshot,
          page: () => InputScreenshotScreen(
            imageBuilder: (context, path) => const SizedBox(
              key: Key('preview_box'),
              width: 200,
              height: 200,
            ),
          ),
          binding: BindingsBuilder(() {
            Get.lazyPut<InputScreenshotController>(() => controller);
          }),
        ),
        GetPage(
          name: AppRoutes.inputText,
          page: () => const Scaffold(body: Text('Message Text Screen')),
        ),
        GetPage(
          name: AppRoutes.guidance,
          page: () => const Scaffold(body: Text('Safe Use Guidance Screen')),
        ),
      ],
    );
  }

  void selectSampleImage() {
    controller.selectedImage.value = SelectedImageDescriptor(
      id: 'img-1',
      format: ImageFormat.png,
      width: 32,
      height: 32,
      byteCount: samplePng.lengthSync(),
      filePath: samplePng.path,
    );
  }

  testWidgets('Renders script and accuracy notices when image is selected', (
    tester,
  ) async {
    selectSampleImage();
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final scriptNotice = find.text(
      'Text extraction currently supports Latin-script text, including English. Urdu and Arabic text in images are not supported yet.',
    );
    await tester.ensureVisible(scriptNotice);
    expect(scriptNotice, findsOneWidget);

    final accuracyNotice = find.text(
      'Text extraction can miss or misread words. Check the result against your screenshot.',
    );
    await tester.ensureVisible(accuracyNotice);
    expect(accuracyNotice, findsOneWidget);

    final extractButton = find.widgetWithText(AppButton, 'Extract text');
    await tester.ensureVisible(extractButton);
    expect(extractButton, findsOneWidget);
  });

  testWidgets(
    'Tapping Extract text shows labeled progress and Cancel extraction',
    (tester) async {
      selectSampleImage();
      final completer = Completer<Result<OcrResult>>();
      fakeOcr.inFlightCompleter = completer;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final extractButton = find.widgetWithText(AppButton, 'Extract text');
      await tester.ensureVisible(extractButton);
      await tester.tap(extractButton);
      await tester.pump();

      final progressText = find.text('Extracting text on this device...');
      expect(progressText, findsOneWidget);

      final cancelButton = find.widgetWithText(AppButton, 'Cancel extraction');
      await tester.ensureVisible(cancelButton);
      expect(cancelButton, findsOneWidget);

      // Cancel extraction
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Text extraction was cancelled.'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Settling...'), findsOneWidget);

      completer.complete(
        Result.failure(const OcrFailure.userCancelled().toAnalysisFailure()),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AppButton, 'Retry extraction'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Successful extraction shows Extracted text, disclaimer, and SelectableText while preserving preview',
    (tester) async {
      selectSampleImage();
      fakeOcr.nextResult = Result.success(
        OcrResult(
          snapshot: TextSnapshot(
            id: 'snap-1',
            source: InputSource.screenshot,
            text: 'Payment required: Click to claim refund.',
            createdAt: DateTime.now().toUtc(),
          ),
          imageRevision: 'img-1',
          extractionTimestamp: DateTime.now().toUtc(),
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final extractButton = find.widgetWithText(AppButton, 'Extract text');
      await tester.ensureVisible(extractButton);
      await tester.tap(extractButton);
      await tester.pumpAndSettle();

      final extractedHeader = find.text('Extracted text');
      await tester.ensureVisible(extractedHeader);
      expect(extractedHeader, findsOneWidget);

      expect(
        find.text(
          'Extracted on this device. This text has not been reviewed or analyzed.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Payment required: Click to claim refund.'),
        findsOneWidget,
      );
      // Preview is still visible for comparison
      expect(find.byKey(const Key('preview_box')), findsOneWidget);
      expect(
        find.widgetWithText(AppButton, 'Extract text again'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Error state shows message, recovery suggestion, and action buttons',
    (tester) async {
      selectSampleImage();
      fakeOcr.nextResult = Result.failure(
        const OcrFailure.noReadableTextFound().toAnalysisFailure(),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final extractButton = find.widgetWithText(AppButton, 'Extract text');
      await tester.ensureVisible(extractButton);
      await tester.tap(extractButton);
      await tester.pumpAndSettle();

      final errorText = find.text('No readable text was found in this image.');
      await tester.ensureVisible(errorText);
      expect(errorText, findsOneWidget);

      expect(
        find.textContaining('This does not mean the message is safe'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppButton, 'Retry extraction'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(AppButton, 'Enter text manually'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Back button with extracted text prompts discard dialog warning about text',
    (tester) async {
      selectSampleImage();
      controller.ocrResult.value = OcrResult(
        snapshot: TextSnapshot(
          id: 'snap-1',
          source: InputSource.screenshot,
          text: 'Extracted sample text',
          createdAt: DateTime.now().toUtc(),
        ),
        imageRevision: 'img-1',
        extractionTimestamp: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Discard screenshot?'), findsOneWidget);
      expect(
        find.text(
          'You have a screenshot with extracted text. If you leave now, the preview and extracted text will be discarded.',
        ),
        findsOneWidget,
      );

      // Keep reviewing stays on screen
      await tester.tap(find.text('Keep reviewing'));
      await tester.pumpAndSettle();
      expect(find.text('Extracted text'), findsOneWidget);
    },
  );

  testWidgets('Operable at 200% text scale in dark theme', (tester) async {
    selectSampleImage();
    controller.ocrResult.value = OcrResult(
      snapshot: TextSnapshot(
        id: 'snap-1',
        source: InputSource.screenshot,
        text: 'Extracted scale test message',
        createdAt: DateTime.now().toUtc(),
      ),
      imageRevision: 'img-1',
      extractionTimestamp: DateTime.now().toUtc(),
    );

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(createTestWidget(brightness: Brightness.dark));
    await tester.pumpAndSettle();

    final extractedHeader = find.text('Extracted text');
    await tester.ensureVisible(extractedHeader);
    expect(extractedHeader, findsOneWidget);
    expect(find.text('Extracted scale test message'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
