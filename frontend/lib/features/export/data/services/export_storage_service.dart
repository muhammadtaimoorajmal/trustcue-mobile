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

  /// Deletes all temporary export files that do not have active leases,
  /// preserving files created within [activeGraceDuration] unless [force] is true.
  Future<int> cleanupAllExports({
    bool force = false,
    Duration activeGraceDuration = Duration.zero,
  });

  /// Acquires an active lease on [filePath], protecting it from deletion during active generation or sharing.
  void acquireLease(String filePath) {}

  /// Releases an active lease on [filePath].
  void releaseLease(String filePath) {}

  /// Checks whether [filePath] currently has an active in-memory lease.
  bool isLeased(String filePath) => false;
}

/// Production implementation storing export files in `<cacheDir>/exports/`.
class DefaultExportStorageService implements ExportStorageService {
  final Directory? overrideDirectory;
  final Set<String> _activeLeases = <String>{};

  DefaultExportStorageService({this.overrideDirectory});

  @override
  void acquireLease(String filePath) {
    _activeLeases.add(p.canonicalize(filePath));
  }

  @override
  void releaseLease(String filePath) {
    _activeLeases.remove(p.canonicalize(filePath));
  }

  @override
  bool isLeased(String filePath) {
    return _activeLeases.contains(p.canonicalize(filePath));
  }

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
    final fileName = _generateFileName(
      ExportFormat.plainText,
      timestamp: timestamp,
    );
    final file = File(p.join(dir.path, fileName));
    return file.writeAsString(content, flush: true);
  }

  @override
  Future<File> writePdfReport(Uint8List bytes, {DateTime? timestamp}) async {
    // Proactively prune older exports
    await pruneOldExports();

    final dir = await _getExportDirectory();
    final fileName = _generateFileName(ExportFormat.pdf, timestamp: timestamp);
    final file = File(p.join(dir.path, fileName));
    return file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<int> pruneOldExports({
    Duration maxAge = const Duration(hours: 2),
  }) async {
    try {
      final dir = await _getExportDirectory();
      if (!await dir.exists()) return 0;

      final now = DateTime.now();
      int deletedCount = 0;

      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final canonical = p.canonicalize(entity.path);
          if (_activeLeases.contains(canonical)) continue;

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
  Future<int> cleanupAllExports({
    bool force = false,
    Duration activeGraceDuration = Duration.zero,
  }) async {
    try {
      final dir = await _getExportDirectory();
      if (!await dir.exists()) return 0;

      final now = DateTime.now();
      int deletedCount = 0;
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final canonical = p.canonicalize(entity.path);
          if (!force) {
            // Protected if actively leased during export generation or sharing
            if (_activeLeases.contains(canonical)) continue;
            // Protected if created or modified recently within activeGraceDuration
            if (activeGraceDuration > Duration.zero) {
              final stat = entity.statSync();
              if (now.difference(stat.modified) < activeGraceDuration) continue;
            }
          }
          try {
            entity.deleteSync();
            _activeLeases.remove(canonical);
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
