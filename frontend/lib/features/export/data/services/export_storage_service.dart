import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_format.dart';

/// Contract for managing temporary export file storage and lifecycle.
abstract class ExportStorageService {
  /// Writes plain text report to a temporary export file.
  Future<File> writePlainTextReport(String content, {DateTime? timestamp});

  /// Writes binary PDF report to a temporary export file.
  Future<File> writePdfReport(Uint8List bytes, {DateTime? timestamp});

  /// Deletes export files older than [maxAge].
  Future<int> pruneOldExports({Duration maxAge = const Duration(hours: 2)});

  /// Deletes all temporary export files.
  Future<int> cleanupAllExports();
}

/// Production implementation storing export files in `<cacheDir>/exports/`.
class DefaultExportStorageService implements ExportStorageService {
  final Directory? overrideDirectory;

  DefaultExportStorageService({this.overrideDirectory});

  Future<Directory> _getExportDirectory() async {
    if (overrideDirectory != null) {
      if (!await overrideDirectory!.exists()) {
        await overrideDirectory!.create(recursive: true);
      }
      return overrideDirectory!;
    }

    final cacheDir = await getTemporaryDirectory();
    final exportsDir = Directory(p.join(cacheDir.path, 'exports'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    return exportsDir;
  }

  @override
  Future<File> writePlainTextReport(
    String content, {
    DateTime? timestamp,
  }) async {
    // Proactively prune older exports
    await pruneOldExports();

    final dir = await _getExportDirectory();
    final fileName = _generateFileName(ExportFormat.plainText, timestamp: timestamp);
    final file = File(p.join(dir.path, fileName));
    return file.writeAsString(content, flush: true);
  }

  @override
  Future<File> writePdfReport(
    Uint8List bytes, {
    DateTime? timestamp,
  }) async {
    // Proactively prune older exports
    await pruneOldExports();

    final dir = await _getExportDirectory();
    final fileName = _generateFileName(ExportFormat.pdf, timestamp: timestamp);
    final file = File(p.join(dir.path, fileName));
    return file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<int> pruneOldExports({Duration maxAge = const Duration(hours: 2)}) async {
    try {
      final dir = await _getExportDirectory();
      if (!await dir.exists()) return 0;

      final now = DateTime.now();
      int deletedCount = 0;

      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final stat = entity.statSync();
          final age = now.difference(stat.modified);
          if (age > maxAge) {
            try {
              entity.deleteSync();
              deletedCount++;
            } catch (_) {}
          }
        }
      }
      return deletedCount;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<int> cleanupAllExports() async {
    try {
      final dir = await _getExportDirectory();
      if (!await dir.exists()) return 0;

      int deletedCount = 0;
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          try {
            entity.deleteSync();
            deletedCount++;
          } catch (_) {}
        }
      }
      return deletedCount;
    } catch (_) {
      return 0;
    }
  }

  String _generateFileName(ExportFormat format, {DateTime? timestamp}) {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');

    return 'trustcue_report_$yyyy$mm${dd}_$hh$min$ss${format.fileExtension}';
  }
}
