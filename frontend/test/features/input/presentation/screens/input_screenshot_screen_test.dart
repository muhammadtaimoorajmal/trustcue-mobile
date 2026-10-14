import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/image_picker_adapter.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_screenshot_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_screenshot_screen.dart';
import 'package:trustcue_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';

class FakePickerAdapter implements ImagePickerAdapter {
  XFile? nextResult;

  @override
  Future<XFile?> pickImage() async => nextResult;

  @override
  Future<LostDataResponse?> retrieveLostData() async => null;
}

class FakeStorageService implements ScreenshotStorageService {
  late Directory tempDir;
  final Set<String> managedFiles = {};

  @override
  Future<Directory> getScreenshotDirectory() async => tempDir;

  @override
  Future<File> importCandidateFile(
    XFile sourceFile, {
    String? fileExtension,
  }) async {
    final target = File(
      '${tempDir.path}/imported-${managedFiles.length}${fileExtension ?? ".png"}',
    );
    final bytes = await sourceFile.readAsBytes();
    target.writeAsBytesSync(bytes);
    managedFiles.add(target.path);
    return target;
  }

  @override
  Future<bool> deleteOwnedFile(String filePath) async {
    managedFiles.remove(filePath);
    final f = File(filePath);
    if (f.existsSync()) {
      f.deleteSync();
      return true;
    }
    return false;
  }

  @override
  Future<int> cleanupOrphanFiles({
    Set<String> keepFilePaths = const {},
  }) async => 0;
}

// 1x1 valid PNG bytes to avoid Image.file decode exceptions in Flutter
final _validPng1x1 = Uint8List.fromList([
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  10,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  0,
  1,
  0,
  0,
  5,
  0,
  1,
  13,
  10,
  45,
  180,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  64,
  66,
  96,
  130,
]);

void main() {
  late Directory tempDir;
  late FakePickerAdapter fakePicker;
  late FakeStorageService fakeStorage;
  late InputScreenshotController testController;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trustcue_scrn_test_');
    fakePicker = FakePickerAdapter();
    fakeStorage = FakeStorageService()..tempDir = tempDir;
    testController = InputScreenshotController(
      pickerAdapter: fakePicker,
      storageService: fakeStorage,
    );
  });

  tearDown(() async {
    Get.reset();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Widget buildTestApp({
    ThemeMode themeMode = ThemeMode.light,
    double textScaleFactor = 1.0,
  }) {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: AppRoutes.inputScreenshot,
      getPages: [
        GetPage(
          name: AppRoutes.home,
          page: () => const Scaffold(body: Text('Home Dashboard')),
        ),
        GetPage(
          name: AppRoutes.inputScreenshot,
          page: () => InputScreenshotScreen(
            imageBuilder: (context, path) =>
                Image.memory(_validPng1x1, fit: BoxFit.contain),
          ),
          binding: BindingsBuilder(() {
            Get.lazyPut<InputScreenshotController>(() => testController);
          }),
        ),
        GetPage(
          name: AppRoutes.guidance,
          page: () => const OnboardingScreen(mode: OnboardingMode.review),
        ),
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        );
      },
    );
  }

  Future<void> chooseImageThroughUi(WidgetTester tester) async {
    await tester.runAsync(() async {
      await testController.chooseImage();
    });
    await tester.pumpAndSettle();
  }

  testWidgets('InputScreenshotScreen renders initial empty layout', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Screenshot'), findsOneWidget);
    expect(
      find.text('Choose a screenshot of the message you want to review.'),
      findsOneWidget,
    );
    expect(
      find.text('For suspicious messages captured in an image.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Image preview, text extraction, and local checks are available. Results are indicators, not a verdict.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Supported formats: PNG, JPEG (up to 10 MB, 20 MP).'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Choose image'), findsOneWidget);
    expect(find.text('Safety reminder'), findsOneWidget);
    expect(
      find.text(
        'Check the image for passwords, OTPs, account numbers, and personal details before reviewing.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppButton, 'Review safe-use guidance'),
      findsOneWidget,
    );
  });

  testWidgets('Review safe-use guidance navigates to guidance screen', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    final guidanceButton = find.widgetWithText(
      AppButton,
      'Review safe-use guidance',
    );
    await tester.ensureVisible(guidanceButton);
    await tester.tap(guidanceButton);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.guidance);
  });

  testWidgets('Back button without image navigates to Home without dialog', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Home Dashboard'), findsOneWidget);
    expect(find.text('Discard screenshot?'), findsNothing);
  });

  testWidgets(
    'Choosing an image displays preview, metadata, and no file path',
    (tester) async {
      final imageFile = File('${tempDir.path}/test_image.png');
      imageFile.writeAsBytesSync(_validPng1x1);
      fakePicker.nextResult = XFile(imageFile.path);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await chooseImageThroughUi(tester);

      // Verify preview state
      expect(find.text('Screenshot preview'), findsOneWidget);
      expect(
        find.text(
          'Inspect the image before proceeding. Zoom and pan are available.',
        ),
        findsOneWidget,
      );
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Pinch or drag to zoom and pan.'), findsOneWidget);

      // Verify metadata
      expect(find.text('Image details'), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);
      expect(find.text('1 × 1 px'), findsOneWidget);

      // CRITICAL: Ensure filesystem path is strictly NOT displayed
      expect(find.textContaining('test_image.png'), findsNothing);
      expect(find.textContaining('imported-'), findsNothing);
      expect(find.textContaining(tempDir.path), findsNothing);

      // Verify notice & action buttons
      expect(
        find.text(
          'Selected for local preview. TrustCue has not uploaded or analyzed this image.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Replace image'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Remove image'), findsOneWidget);
    },
  );

  testWidgets(
    'Remove image prompts dialog; cancel keeps preview; confirm clears preview',
    (tester) async {
      final imageFile = File('${tempDir.path}/remove_test.png');
      imageFile.writeAsBytesSync(_validPng1x1);
      fakePicker.nextResult = XFile(imageFile.path);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await chooseImageThroughUi(tester);

      expect(find.text('Screenshot preview'), findsOneWidget);

      // Tap Remove image
      final removeButton = find.widgetWithText(AppButton, 'Remove image');
      await tester.ensureVisible(removeButton);
      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Remove screenshot?'), findsOneWidget);
      expect(
        find.text(
          'This removes the preview from TrustCue. The original image remains safely in your gallery.',
        ),
        findsOneWidget,
      );

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Preview remains
      expect(find.text('Screenshot preview'), findsOneWidget);

      // Tap Remove image again
      await tester.ensureVisible(removeButton);
      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      // Tap Remove in dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      // Reset back to empty selection
      expect(find.text('Screenshot preview'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Choose image'), findsOneWidget);
    },
  );

  testWidgets(
    'Back button with image prompts discard dialog; keep stays; discard navigates back',
    (tester) async {
      final imageFile = File('${tempDir.path}/discard_test.png');
      imageFile.writeAsBytesSync(_validPng1x1);
      fakePicker.nextResult = XFile(imageFile.path);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await chooseImageThroughUi(tester);

      expect(find.text('Screenshot preview'), findsOneWidget);

      // Tap Back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Discard dialog appears
      expect(find.text('Discard screenshot?'), findsOneWidget);
      expect(
        find.text(
          'You have a screenshot selected for preview. If you leave now, the preview will be discarded.',
        ),
        findsOneWidget,
      );

      // Tap Keep reviewing
      await tester.tap(find.text('Keep reviewing'));
      await tester.pumpAndSettle();

      // Remains on preview screen
      expect(find.text('Screenshot preview'), findsOneWidget);

      // Tap Back again
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Tap Discard
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      // Navigates to Home
      expect(find.text('Home Dashboard'), findsOneWidget);
    },
  );

  testWidgets('Screen handles 200% text scale in dark theme without overflow', (
    tester,
  ) async {
    final imageFile = File('${tempDir.path}/dark_test.png');
    imageFile.writeAsBytesSync(_validPng1x1);
    fakePicker.nextResult = XFile(imageFile.path);

    await tester.pumpWidget(
      buildTestApp(themeMode: ThemeMode.dark, textScaleFactor: 2.0),
    );
    await tester.pumpAndSettle();

    await chooseImageThroughUi(tester);

    expect(find.text('Screenshot preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
