import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/export/data/services/export_storage_service.dart';

void main() {
  group('DefaultExportStorageService Tests', () {
    late Directory tempDir;
    late DefaultExportStorageService storageService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('trustcue_export_test_');
      storageService = DefaultExportStorageService(overrideDirectory: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes plain text report with correct filename and content', () async {
      final timestamp = DateTime.utc(2026, 10, 17, 14, 30, 45);
      final content = 'TRUSTCUE EXPORT CONTENT';

      final file = await storageService.writePlainTextReport(
        content,
        timestamp: timestamp,
      );

      expect(file.existsSync(), isTrue);
      expect(
        file.path.endsWith('trustcue_report_20261017_143045.txt'),
        isTrue,
      );
      final read = await file.readAsString();
      expect(read, content);
    });

    test('writes binary PDF report with correct filename and bytes', () async {
      final timestamp = DateTime.utc(2026, 10, 17, 15, 0, 0);
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final file = await storageService.writePdfReport(
        bytes,
        timestamp: timestamp,
      );

      expect(file.existsSync(), isTrue);
      expect(
        file.path.endsWith('trustcue_report_20261017_150000.pdf'),
        isTrue,
      );
      final read = await file.readAsBytes();
      expect(read, bytes);
    });

    test('prunes files older than maxAge while preserving newer ones', () async {
      final now = DateTime.now();

      // Write an old file directly
      final oldFile = File('${tempDir.path}/trustcue_report_old.txt');
      await oldFile.writeAsString('old');
      await oldFile.setLastModified(now.subtract(const Duration(hours: 3)));

      // Write a recent file
      final newFile = File('${tempDir.path}/trustcue_report_new.txt');
      await newFile.writeAsString('new');
      await newFile.setLastModified(now.subtract(const Duration(minutes: 10)));

      final deletedCount = await storageService.pruneOldExports(
        maxAge: const Duration(hours: 2),
      );

      expect(deletedCount, 1);
      expect(oldFile.existsSync(), isFalse);
      expect(newFile.existsSync(), isTrue);
    });

    test('cleans up all export files in directory', () async {
      final f1 = File('${tempDir.path}/report1.txt');
      final f2 = File('${tempDir.path}/report2.pdf');
      await f1.writeAsString('1');
      await f2.writeAsString('2');

      final deletedCount = await storageService.cleanupAllExports();

      expect(deletedCount, 2);
      expect(f1.existsSync(), isFalse);
      expect(f2.existsSync(), isFalse);
    });
  });
}

