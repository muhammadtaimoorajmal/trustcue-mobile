import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/contracts/incoming_share_adapter.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/models/incoming_share_payload.dart';
import 'package:trustcue_mobile/features/incoming_share/presentation/controllers/incoming_share_coordinator.dart';
import 'package:trustcue_mobile/features/incoming_share/presentation/widgets/incoming_share_dialog.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

class _FakeIncomingShareAdapter implements IncomingShareAdapter {
  final _controller = StreamController<IncomingSharePayload>.broadcast();
  final List<String> consumedIds = [];
  final List<String> cleanedFiles = [];

  @override
  Stream<IncomingSharePayload> get shareStream => _controller.stream;

  @override
  Future<IncomingSharePayload?> getInitialShare() async => null;

  @override
  Future<bool> consumeShare(String eventId) async {
    consumedIds.add(eventId);
    return true;
  }

  @override
  Future<bool> cleanStagedFile(String filePath) async {
    cleanedFiles.add(filePath);
    return true;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class _FakeOnboardingPreferences implements OnboardingPreferences {
  @override
  Future<int?> readVersion() async => OnboardingPreferences.currentVersion;

  @override
  Future<void> saveVersion(int newVersion) async {}
}

class _FakeScreenshotStorageService implements ScreenshotStorageService {
  _FakeScreenshotStorageService(this.tempDir);
  final Directory tempDir;

  @override
  Future<Directory> getScreenshotDirectory() async => tempDir;

  @override
  Future<File> importCandidateFile(
    XFile sourceFile, {
    String? fileExtension,
  }) async {
    final dest = File(
      '${tempDir.path}/imported_image${fileExtension ?? ".png"}',
    );
    await dest.writeAsBytes(await sourceFile.readAsBytes());
    return dest;
  }

  @override
  Future<bool> deleteOwnedFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  @override
  Future<int> cleanupOrphanFiles({
    Set<String> keepFilePaths = const {},
  }) async => 0;
}

final _validPngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x04, 0x38, // width = 1080
  0x00, 0x00, 0x09, 0x60, // height = 2400
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('IncomingShareDialog Widget Tests', () {
    late _FakeIncomingShareAdapter fakeAdapter;
    late Directory tempDir;
    late IncomingShareCoordinator coordinator;
    late File stagedImageFile;
    late File stagedMixedFile;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Get.testMode = true;
      tempDir = await Directory.systemTemp.createTemp('trustcue_dialog_test_');
      stagedImageFile = File('${tempDir.path}/staged_image.png');
      stagedImageFile.writeAsBytesSync(_validPngBytes);
      stagedMixedFile = File('${tempDir.path}/staged_mixed.png');
      stagedMixedFile.writeAsBytesSync(_validPngBytes);

      fakeAdapter = _FakeIncomingShareAdapter();

      coordinator = IncomingShareCoordinator(
        adapter: fakeAdapter,
        preferences: _FakeOnboardingPreferences(),
        storageService: _FakeScreenshotStorageService(tempDir),
        idGenerator: () => 'fixed-id-dlg',
      );
      await coordinator.init();
    });

    tearDown(() async {
      coordinator.onClose();
      fakeAdapter.dispose();
      Get.reset();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Widget createTestApp(
      IncomingSharePayload payload, {
      ThemeData? theme,
      double textScale = 1.0,
    }) {
      return GetMaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        getPages: [
          GetPage(
            name: '/',
            page: () => MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: IncomingShareDialog(
                  coordinator: coordinator,
                  payload: payload,
                  imageBuilder: (context, path) => const SizedBox(
                    key: Key('shared_image_preview'),
                    height: 180,
                    child: Text('Image preview active'),
                  ),
                ),
              ),
            ),
          ),
          GetPage(
            name: AppRoutes.inputText,
            page: () => const Scaffold(body: Text('Input Text Screen')),
          ),
          GetPage(
            name: AppRoutes.inputLink,
            page: () => const Scaffold(body: Text('Input Link Screen')),
          ),
          GetPage(
            name: AppRoutes.inputScreenshot,
            page: () => const Scaffold(body: Text('Input Screenshot Screen')),
          ),
        ],
      );
    }

    testWidgets('Renders standard text share with Use as message and Dismiss', (
      tester,
    ) async {
      final payload = IncomingSharePayload.text(
        eventId: 'text-msg-1',
        text: 'Payment notification for your account',
      );

      await tester.pumpWidget(createTestApp(payload));
      await tester.pumpAndSettle();

      expect(find.text('Shared message received'), findsOneWidget);
      expect(
        find.text('Payment notification for your account'),
        findsOneWidget,
      );
      expect(find.textContaining('Non-clickable preview'), findsOneWidget);
      expect(find.text('Use as message'), findsOneWidget);
      expect(find.text('Inspect as link'), findsNothing);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets(
      'Renders single web address text with both Use as message and Inspect as link',
      (tester) async {
        final payload = IncomingSharePayload.text(
          eventId: 'text-link-1',
          text: 'https://verify-portal.example.com/login',
        );

        await tester.pumpWidget(createTestApp(payload));
        await tester.pumpAndSettle();

        expect(find.text('Shared message received'), findsOneWidget);
        expect(
          find.text('https://verify-portal.example.com/login'),
          findsOneWidget,
        );
        expect(
          find.text('This content is formatted as a single web address.'),
          findsOneWidget,
        );
        expect(find.text('Use as message'), findsOneWidget);
        expect(find.text('Inspect as link'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders image share with Use as screenshot and Use as QR image',
      (tester) async {
        final payload = IncomingSharePayload.image(
          eventId: 'image-share-1',
          stagedImagePath: stagedImageFile.path,
          mimeType: 'image/png',
        );

        await tester.pumpWidget(createTestApp(payload));
        await tester.pumpAndSettle();

        expect(find.text('Shared image received'), findsOneWidget);
        expect(
          find.textContaining('Your original gallery photo was not modified'),
          findsOneWidget,
        );
        expect(find.text('Use as screenshot'), findsOneWidget);
        expect(find.text('Use as QR image'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);
      },
    );

    testWidgets('Renders mixed share with both text and image action options', (
      tester,
    ) async {
      final payload = IncomingSharePayload.mixed(
        eventId: 'mixed-share-1',
        text: 'https://security-notice.com',
        stagedImagePath: stagedMixedFile.path,
        mimeType: 'image/png',
      );

      await tester.pumpWidget(createTestApp(payload));
      await tester.pumpAndSettle();

      expect(find.text('Shared content received'), findsOneWidget);
      expect(
        find.textContaining(
          'Both an image and text were received with this share',
        ),
        findsOneWidget,
      );
      expect(find.text('Use image as screenshot'), findsOneWidget);
      expect(find.text('Use image as QR'), findsOneWidget);
      expect(find.text('Use text as message'), findsOneWidget);
      expect(find.text('Inspect text as link'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets(
      'Renders unsupported payload with error message and Dismiss only',
      (tester) async {
        final payload = IncomingSharePayload.unsupported(
          eventId: 'unsupported-1',
          errorMessage:
              'Sharing multiple files simultaneously is not supported.',
        );

        await tester.pumpWidget(createTestApp(payload));
        await tester.pumpAndSettle();

        expect(find.text('Unable to receive share'), findsOneWidget);
        expect(
          find.text('Sharing multiple files simultaneously is not supported.'),
          findsOneWidget,
        );
        expect(find.text('Dismiss'), findsOneWidget);
        expect(find.text('Use as message'), findsNothing);
        expect(find.text('Use as screenshot'), findsNothing);
      },
    );

    testWidgets('Dismiss button invokes dismissPendingShare', (tester) async {
      final payload = IncomingSharePayload.text(
        eventId: 'dismiss-click-1',
        text: 'Dismiss me',
      );
      coordinator.pendingShare.value = payload;

      await tester.pumpWidget(createTestApp(payload));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.consumedIds, contains('dismiss-click-1'));
    });

    testWidgets(
      'Draft conflict displays replacement prompt and cancels safely',
      (tester) async {
        final textController = InputTextController();
        Get.put<InputTextController>(textController);
        textController.textEditingController.text = 'Important existing draft';

        final payload = IncomingSharePayload.text(
          eventId: 'conflict-test-1',
          text: 'New shared text',
        );
        coordinator.pendingShare.value = payload;

        await tester.pumpWidget(createTestApp(payload));
        await tester.pumpAndSettle();

        // Tap 'Use as message' -> triggers conflict
        await tester.tap(find.text('Use as message'));
        await tester.pumpAndSettle();

        expect(find.text('Replace existing draft?'), findsOneWidget);
        expect(
          find.textContaining('Would you like to keep your existing draft'),
          findsOneWidget,
        );

        // Tapping 'Keep current draft' dismisses and leaves draft intact
        await tester.tap(find.text('Keep current draft'));
        await tester.pumpAndSettle();

        expect(textController.text.value, 'Important existing draft');
        expect(fakeAdapter.consumedIds, contains('conflict-test-1'));
      },
    );

    testWidgets('Draft conflict allows user to confirm replacement', (
      tester,
    ) async {
      final textController = InputTextController();
      Get.put<InputTextController>(textController);
      textController.textEditingController.text = 'Draft to overwrite';

      final payload = IncomingSharePayload.text(
        eventId: 'conflict-replace-1',
        text: 'Fresh replacement text',
      );
      coordinator.pendingShare.value = payload;

      await tester.pumpWidget(createTestApp(payload));
      await tester.pumpAndSettle();

      // Tap 'Use as message' -> triggers conflict
      await tester.tap(find.text('Use as message'));
      await tester.pumpAndSettle();

      expect(find.text('Replace existing draft?'), findsOneWidget);

      // Tapping 'Replace with shared content' overwrites the draft
      await tester.tap(find.text('Replace with shared content'));
      await tester.pumpAndSettle();

      expect(textController.text.value, 'Fresh replacement text');
      expect(fakeAdapter.consumedIds, contains('conflict-replace-1'));
    });

    testWidgets('Renders properly under 200% text scale without overflow', (
      tester,
    ) async {
      final payload = IncomingSharePayload.text(
        eventId: 'scale-test',
        text: 'Accessibility text test at 200% scale',
      );

      await tester.pumpWidget(createTestApp(payload, textScale: 2.0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Shared message received'), findsOneWidget);
      expect(find.text('Use as message'), findsOneWidget);
    });

    testWidgets('Renders properly under dark theme', (tester) async {
      final payload = IncomingSharePayload.text(
        eventId: 'dark-test',
        text: 'Dark mode share review',
      );

      await tester.pumpWidget(
        createTestApp(payload, theme: AppTheme.darkTheme),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Shared message received'), findsOneWidget);
    });
  });
}
