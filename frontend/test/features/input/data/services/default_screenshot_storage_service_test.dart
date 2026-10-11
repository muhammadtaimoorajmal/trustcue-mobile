import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/input/data/services/default_screenshot_storage_service.dart';

void main() {
  late Directory tempBaseDir;
  late DefaultScreenshotStorageService storageService;
  var idCounter = 0;

  setUp(() async {
    tempBaseDir = await Directory.systemTemp.createTemp('trustcue_test_');
    idCounter = 0;
    storageService = DefaultScreenshotStorageService(
      tempDirProvider: () async => tempBaseDir,
      idGenerator: () => '${++idCounter}',
    );
  });

  tearDown(() async {
    if (await tempBaseDir.exists()) {
      await tempBaseDir.delete(recursive: true);
    }
  });

  test(
    'Creates dedicated trustcue_screenshots directory under temp root',
    () async {
      final dedicatedDir = await storageService.getScreenshotDirectory();

      expect(await dedicatedDir.exists(), isTrue);
      expect(dedicatedDir.path, contains('trustcue_screenshots'));
    },
  );

  test(
    'Imports candidate file into app-owned copy with generated name',
    () async {
      final sourceFile = File('${tempBaseDir.path}/user_gallery_image.png');
      await sourceFile.writeAsBytes([1, 2, 3, 4, 5]);

      final imported = await storageService.importCandidateFile(
        XFile(sourceFile.path),
        fileExtension: '.png',
      );

      expect(await imported.exists(), isTrue);
      expect(imported.path, contains('tc-ss-1.png'));
      expect(await imported.readAsBytes(), [1, 2, 3, 4, 5]);

      // Original file remains untouched!
      expect(await sourceFile.exists(), isTrue);
    },
  );

  test(
    'Refuses to delete files outside dedicated directory (positive ownership)',
    () async {
      final externalFile = File(
        '${tempBaseDir.path}/external_gallery_photo.jpg',
      );
      await externalFile.writeAsBytes([9, 9, 9]);

      final deleted = await storageService.deleteOwnedFile(externalFile.path);

      expect(deleted, isFalse);
      expect(await externalFile.exists(), isTrue); // Protected!
    },
  );

  test('Deletes owned file within dedicated directory', () async {
    final dedicatedDir = await storageService.getScreenshotDirectory();
    final ownedFile = File('${dedicatedDir.path}/tc-ss-test.png');
    await ownedFile.writeAsBytes([1, 2, 3]);

    final deleted = await storageService.deleteOwnedFile(ownedFile.path);

    expect(deleted, isTrue);
    expect(await ownedFile.exists(), isFalse);
  });

  test(
    'Cleans up orphan files while preserving specified keep files',
    () async {
      final dedicatedDir = await storageService.getScreenshotDirectory();
      final fileKeep = File('${dedicatedDir.path}/tc-ss-keep.png');
      final fileOrphan1 = File('${dedicatedDir.path}/tc-ss-orphan1.png');
      final fileOrphan2 = File('${dedicatedDir.path}/tc-ss-orphan2.png');

      await fileKeep.writeAsBytes([1]);
      await fileOrphan1.writeAsBytes([2]);
      await fileOrphan2.writeAsBytes([3]);

      final cleanedCount = await storageService.cleanupOrphanFiles(
        keepFilePaths: {fileKeep.path},
      );

      expect(cleanedCount, 2);
      expect(await fileKeep.exists(), isTrue);
      expect(await fileOrphan1.exists(), isFalse);
      expect(await fileOrphan2.exists(), isFalse);
    },
  );

  test(
    'Aborts import and cleans up partial file if source exceeds 10 MiB limit',
    () async {
      // Large byte stream > 10 MiB
      final largeBytes = Uint8List(10 * 1024 * 1024 + 1024);
      final largeXFile = XFile.fromData(largeBytes, name: 'large.png');

      await expectLater(
        storageService.importCandidateFile(largeXFile),
        throwsA(isA<FileSystemException>()),
      );

      final dedicatedDir = await storageService.getScreenshotDirectory();
      final files = dedicatedDir.listSync();
      expect(files, isEmpty); // No partial file remains!
    },
  );
}
