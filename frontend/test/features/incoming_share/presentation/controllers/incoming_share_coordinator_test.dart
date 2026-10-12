import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/contracts/incoming_share_adapter.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/models/incoming_share_payload.dart';
import 'package:trustcue_mobile/features/incoming_share/presentation/controllers/incoming_share_coordinator.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_link_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_screenshot_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

class _FakeIncomingShareAdapter implements IncomingShareAdapter {
  final _controller = StreamController<IncomingSharePayload>.broadcast();
  IncomingSharePayload? initialShareToReturn;
  final List<String> consumedIds = [];
  final List<String> cleanedFiles = [];

  void emitShare(IncomingSharePayload payload) {
    _controller.add(payload);
  }

  @override
  Stream<IncomingSharePayload> get shareStream => _controller.stream;

  @override
  Future<IncomingSharePayload?> getInitialShare() async => initialShareToReturn;

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
  int? version = OnboardingPreferences.currentVersion;

  @override
  Future<int?> readVersion() async => version;

  @override
  Future<void> saveVersion(int newVersion) async {
    version = newVersion;
  }
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
  group('IncomingShareCoordinator Tests', () {
    late _FakeIncomingShareAdapter fakeAdapter;
    late _FakeOnboardingPreferences fakePreferences;
    late Directory tempDir;
    late _FakeScreenshotStorageService fakeStorageService;
    late IncomingShareCoordinator coordinator;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Get.testMode = true;
      tempDir = await Directory.systemTemp.createTemp('trustcue_share_test_');
      fakeAdapter = _FakeIncomingShareAdapter();
      fakePreferences = _FakeOnboardingPreferences();
      fakeStorageService = _FakeScreenshotStorageService(tempDir);

      coordinator = IncomingShareCoordinator(
        adapter: fakeAdapter,
        preferences: fakePreferences,
        storageService: fakeStorageService,
        idGenerator: () => 'fixed-id-1',
      );
    });

    tearDown(() async {
      coordinator.onClose();
      fakeAdapter.dispose();
      Get.reset();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'Cold start retrieves initial share when onboarding complete',
      () async {
        fakeAdapter.initialShareToReturn = IncomingSharePayload.text(
          eventId: 'cold-1',
          text: 'Shared cold text',
        );

        await coordinator.init();

        expect(coordinator.pendingShare.value, isNotNull);
        expect(coordinator.pendingShare.value?.eventId, 'cold-1');
        expect(coordinator.pendingShare.value?.text, 'Shared cold text');
      },
    );

    test(
      'Cold start holds pending share without presenting during onboarding',
      () async {
        fakePreferences.version = null; // Incomplete onboarding
        fakeAdapter.initialShareToReturn = IncomingSharePayload.text(
          eventId: 'cold-unboarded',
          text: 'Shared before onboarding',
        );

        await coordinator.init();

        // Holds pending share
        expect(coordinator.pendingShare.value, isNotNull);
        expect(coordinator.pendingShare.value?.eventId, 'cold-unboarded');
        // Dialog should not be visible
        expect(coordinator.isDialogVisible.value, isFalse);

        // User finishes onboarding
        fakePreferences.version = OnboardingPreferences.currentVersion;
        coordinator.onOnboardingCompleted();

        // Coordinator recognizes onboarding completion
        expect(coordinator.pendingShare.value?.eventId, 'cold-unboarded');
      },
    );

    test('Warm arrival streams new share into pendingShare', () async {
      await coordinator.init();
      expect(coordinator.pendingShare.value, isNull);

      fakeAdapter.emitShare(
        IncomingSharePayload.text(eventId: 'warm-1', text: 'Shared warm text'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(coordinator.pendingShare.value, isNotNull);
      expect(coordinator.pendingShare.value?.eventId, 'warm-1');
      expect(coordinator.pendingShare.value?.text, 'Shared warm text');
    });

    test('Duplicate event arrival is suppressed', () async {
      await coordinator.init();

      fakeAdapter.emitShare(
        IncomingSharePayload.text(eventId: 'dup-1', text: 'First arrival'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(coordinator.pendingShare.value?.eventId, 'dup-1');

      // Dismiss first arrival
      await coordinator.dismissPendingShare();
      expect(coordinator.pendingShare.value, isNull);
      expect(fakeAdapter.consumedIds, contains('dup-1'));

      // Emitting same eventId again should be ignored
      fakeAdapter.emitShare(
        IncomingSharePayload.text(
          eventId: 'dup-1',
          text: 'First arrival duplicate',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(coordinator.pendingShare.value, isNull);
    });

    test(
      'Bounded pending share preserves existing item and rejects additional share with cleanup',
      () async {
        String? rejectionMessage;
        coordinator = IncomingShareCoordinator(
          adapter: fakeAdapter,
          preferences: fakePreferences,
          storageService: fakeStorageService,
          idGenerator: () => 'fixed-id-1',
          onShareRejected: (msg) => rejectionMessage = msg,
        );

        await coordinator.init();

        fakeAdapter.emitShare(
          IncomingSharePayload.image(
            eventId: 'img-1',
            stagedImagePath: '/cache/image1.png',
            mimeType: 'image/png',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(coordinator.pendingShare.value?.eventId, 'img-1');
        expect(fakeAdapter.cleanedFiles, isEmpty);

        // Second share arrives while first is pending
        fakeAdapter.emitShare(
          IncomingSharePayload.image(
            eventId: 'img-2',
            stagedImagePath: '/cache/image2.png',
            mimeType: 'image/png',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Existing item is preserved
        expect(coordinator.pendingShare.value?.eventId, 'img-1');
        // Only the rejected item's staged file is cleaned up
        expect(fakeAdapter.cleanedFiles, contains('/cache/image2.png'));
        expect(fakeAdapter.cleanedFiles, isNot(contains('/cache/image1.png')));
        // Rejected item is consumed natively
        expect(fakeAdapter.consumedIds, contains('img-2'));
        // Rejection notification was delivered
        expect(rejectionMessage, contains('Another shared item'));
      },
    );

    test(
      'Re-delivery of same event does not delete retained item staged file',
      () async {
        await coordinator.init();

        fakeAdapter.emitShare(
          IncomingSharePayload.image(
            eventId: 'img-retained',
            stagedImagePath: '/cache/retained.png',
            mimeType: 'image/png',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(coordinator.pendingShare.value?.eventId, 'img-retained');
        expect(fakeAdapter.cleanedFiles, isEmpty);

        // Same event re-delivered
        fakeAdapter.emitShare(
          IncomingSharePayload.image(
            eventId: 'img-retained',
            stagedImagePath: '/cache/retained.png',
            mimeType: 'image/png',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(coordinator.pendingShare.value?.eventId, 'img-retained');
        expect(fakeAdapter.cleanedFiles, isEmpty);
      },
    );

    test(
      'Late callback with stale expectedEventId does not dismiss newer pending share',
      () async {
        await coordinator.init();

        fakeAdapter.emitShare(
          IncomingSharePayload.text(
            eventId: 'newer-event',
            text: 'Newer pending text',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(coordinator.pendingShare.value?.eventId, 'newer-event');

        // Late dismiss callback arrives from an older, already consumed event
        await coordinator.dismissPendingShare(expectedEventId: 'stale-event');

        // Newer pending share is untouched
        expect(coordinator.pendingShare.value?.eventId, 'newer-event');
        expect(coordinator.pendingShare.value?.text, 'Newer pending text');
      },
    );

    test(
      'Dismiss pending share cleans staged file and marks consumed',
      () async {
        await coordinator.init();

        fakeAdapter.emitShare(
          IncomingSharePayload.image(
            eventId: 'dismiss-img',
            stagedImagePath: '/cache/dismiss.png',
            mimeType: 'image/png',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await coordinator.dismissPendingShare();

        expect(coordinator.pendingShare.value, isNull);
        expect(fakeAdapter.consumedIds, contains('dismiss-img'));
        expect(fakeAdapter.cleanedFiles, contains('/cache/dismiss.png'));
      },
    );

    test('isSingleWebAddress validates web links strictly', () {
      expect(
        coordinator.isSingleWebAddress('https://example.com/login'),
        isTrue,
      );
      expect(
        coordinator.isSingleWebAddress('http://sub.domain.org/path?q=1'),
        isTrue,
      );
      expect(
        coordinator.isSingleWebAddress('Check this out: https://example.com'),
        isFalse,
      );
      expect(coordinator.isSingleWebAddress('not a web address'), isFalse);
      expect(coordinator.isSingleWebAddress('ftp://example.com'), isFalse);
    });

    test(
      'applySharedMessage routes and populates InputTextController',
      () async {
        await coordinator.init();

        final textController = InputTextController();
        Get.put<InputTextController>(textController);

        fakeAdapter.emitShare(
          IncomingSharePayload.text(
            eventId: 'msg-share',
            text: 'Hello bank team',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await coordinator.applySharedMessage('Hello bank team');

        expect(textController.text.value, 'Hello bank team');
        expect(fakeAdapter.consumedIds, contains('msg-share'));
      },
    );

    test('Draft conflict detection identifies active text draft', () async {
      await coordinator.init();

      final textController = InputTextController();
      Get.put<InputTextController>(textController);
      textController.textEditingController.text = 'Unsaved draft text';

      final conflict = coordinator.checkMessageDraftConflict();
      expect(conflict, isNotNull);
      expect(conflict?.type, DraftConflictType.message);
      expect(conflict?.existingDescription, contains('18 characters'));
    });

    test('applySharedLink routes and populates InputLinkController', () async {
      await coordinator.init();

      final linkController = InputLinkController();
      Get.put<InputLinkController>(linkController);

      fakeAdapter.emitShare(
        IncomingSharePayload.text(
          eventId: 'link-share',
          text: 'https://trustcue.security/verify',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await coordinator.applySharedLink('https://trustcue.security/verify');

      expect(
        linkController.urlTextController.text,
        'https://trustcue.security/verify',
      );
      expect(fakeAdapter.consumedIds, contains('link-share'));
    });

    test('Draft conflict detection identifies active link draft', () async {
      await coordinator.init();

      final linkController = InputLinkController();
      Get.put<InputLinkController>(linkController);
      linkController.urlTextController.text = 'https://existing-draft.com';

      final conflict = coordinator.checkLinkDraftConflict();
      expect(conflict, isNotNull);
      expect(conflict?.type, DraftConflictType.link);
      expect(
        conflict?.existingDescription,
        contains('https://existing-draft.com'),
      );
    });

    test(
      'importStagedImage validates, copies to storage, and cleans staged file',
      () async {
        await coordinator.init();

        final stagedFile = File('${tempDir.path}/staged.png');
        await stagedFile.writeAsBytes(_validPngBytes);

        final imported = await coordinator.importStagedImage(stagedFile.path);

        expect(imported, isNotNull);
        expect(imported?.width, 1080);
        expect(imported?.height, 2400);
        expect(imported?.byteCount, _validPngBytes.length);
        expect(fakeAdapter.cleanedFiles, contains(stagedFile.path));
      },
    );

    test('importStagedImage rejects invalid or non-existent file', () async {
      await coordinator.init();

      final importedMissing = await coordinator.importStagedImage(
        '${tempDir.path}/nonexistent.png',
      );
      expect(importedMissing, isNull);

      final corruptFile = File('${tempDir.path}/corrupt.png');
      await corruptFile.writeAsBytes([0x01, 0x02, 0x03]); // invalid bytes
      final importedCorrupt = await coordinator.importStagedImage(
        corruptFile.path,
      );
      expect(importedCorrupt, isNull);
    });

    test(
      'applySharedScreenshot routes and populates InputScreenshotController',
      () async {
        await coordinator.init();

        final stagedFile = File('${tempDir.path}/staged_screen.png');
        await stagedFile.writeAsBytes(_validPngBytes);

        fakeAdapter.emitShare(
          IncomingSharePayload.image(
            eventId: 'screen-share',
            stagedImagePath: stagedFile.path,
            mimeType: 'image/png',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final screenshotController = InputScreenshotController();
        Get.put<InputScreenshotController>(screenshotController);

        final imported = await coordinator.importStagedImage(stagedFile.path);
        expect(imported, isNotNull);

        await coordinator.applySharedScreenshot(imported!);

        expect(screenshotController.hasImage, isTrue);
        expect(
          screenshotController.selectedImage.value?.filePath,
          imported.filePath,
        );
        expect(fakeAdapter.consumedIds, contains('screen-share'));
      },
    );

    test('applySharedQrImage routes and populates InputLinkController selectedQrImage', () async {
      await coordinator.init();

      final stagedFile = File('${tempDir.path}/staged_qr.png');
      await stagedFile.writeAsBytes(_validPngBytes);

      fakeAdapter.emitShare(
        IncomingSharePayload.image(
          eventId: 'qr-share',
          stagedImagePath: stagedFile.path,
          mimeType: 'image/png',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final linkController = InputLinkController();
      Get.put<InputLinkController>(linkController);

      final imported = await coordinator.importStagedImage(stagedFile.path);
      expect(imported, isNotNull);

      await coordinator.applySharedQrImage(imported!);

      expect(linkController.selectedQrImage.value, isNotNull);
      expect(linkController.selectedQrImage.value?.filePath, imported.filePath);
      expect(fakeAdapter.consumedIds, contains('qr-share'));
    });
  });
}
