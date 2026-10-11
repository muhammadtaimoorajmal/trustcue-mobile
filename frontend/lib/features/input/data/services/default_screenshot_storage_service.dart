import 'dart:io';
import 'dart:math' as math;

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/contracts/screenshot_storage_service.dart';
import '../../domain/validation/image_validation_policy.dart';

/// Default implementation of [ScreenshotStorageService].
///
/// Manages files inside a dedicated `trustcue_screenshots` subfolder under the
/// platform-provided temporary directory. Enforces bounded copying and positive
/// file ownership.
class DefaultScreenshotStorageService implements ScreenshotStorageService {
  DefaultScreenshotStorageService({
    Future<Directory> Function()? tempDirProvider,
    String Function()? idGenerator,
  }) : _tempDirProvider = tempDirProvider ?? getTemporaryDirectory,
       _idGenerator = idGenerator ?? _defaultIdGenerator;

  final Future<Directory> Function() _tempDirProvider;
  final String Function() _idGenerator;

  static const String directoryName = 'trustcue_screenshots';

  @override
  Future<Directory> getScreenshotDirectory() async {
    final baseTemp = await _tempDirProvider();
    final dedicatedDir = Directory(p.join(baseTemp.path, directoryName));
    if (!await dedicatedDir.exists()) {
      await dedicatedDir.create(recursive: true);
    }
    return dedicatedDir;
  }

  @override
  Future<File> importCandidateFile(
    XFile sourceFile, {
    String? fileExtension,
  }) async {
    final targetDir = await getScreenshotDirectory();
    final ext = (fileExtension ?? p.extension(sourceFile.path)).toLowerCase();
    final safeExt = (ext == '.jpg' || ext == '.jpeg' || ext == '.png')
        ? ext
        : '.img';
    final targetName = 'tc-ss-${_idGenerator()}$safeExt';
    final targetFile = File(p.join(targetDir.path, targetName));

    final sink = targetFile.openWrite();
    var bytesCopied = 0;

    try {
      final stream = sourceFile.openRead();
      await for (final chunk in stream) {
        bytesCopied += chunk.length;
        if (bytesCopied > ImageValidationPolicy.maxByteCount) {
          throw const FileSystemException(
            'Candidate file exceeds maximum allowed size.',
          );
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      return targetFile;
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      for (var attempt = 0; attempt < 5; attempt++) {
        if (await targetFile.exists()) {
          try {
            await targetFile.delete();
            break;
          } catch (_) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        } else {
          break;
        }
      }
      rethrow;
    }
  }

  @override
  Future<bool> deleteOwnedFile(String filePath) async {
    try {
      final targetDir = await getScreenshotDirectory();
      final targetCanonical = p.canonicalize(targetDir.path);
      final fileCanonical = p.canonicalize(filePath);

      // Positive ownership: ensure file is strictly inside dedicated directory
      if (!p.isWithin(targetCanonical, fileCanonical)) {
        return false;
      }

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> cleanupOrphanFiles({Set<String> keepFilePaths = const {}}) async {
    try {
      final targetDir = await getScreenshotDirectory();
      if (!await targetDir.exists()) return 0;

      final normalizedKeep = keepFilePaths.map(p.canonicalize).toSet();
      var deletedCount = 0;

      final entities = targetDir.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final canonical = p.canonicalize(entity.path);
          if (!normalizedKeep.contains(canonical)) {
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

  static String _defaultIdGenerator() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = math.Random().nextInt(1000000).toString().padLeft(6, '0');
    return '$now-$random';
  }
}
