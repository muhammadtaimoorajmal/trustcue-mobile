import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Contract governing the dedicated, app-private temporary storage for screenshots.
///
/// Ensures positive ownership: TrustCue deletes only files it created within its
/// dedicated directory and never deletes or alters user gallery files.
abstract class ScreenshotStorageService {
  /// Returns the dedicated directory for storing imported screenshots.
  Future<Directory> getScreenshotDirectory();

  /// Imports a candidate [sourceFile] into an app-owned temporary file with bounded
  /// streaming. Cleans up partial files if the copy fails or exceeds size limits.
  Future<File> importCandidateFile(XFile sourceFile, {String? fileExtension});

  /// Deletes an app-owned file at [filePath].
  ///
  /// Strictly verifies that [filePath] resides within the dedicated screenshot
  /// directory before attempting deletion. Refuses to delete any file outside.
  Future<bool> deleteOwnedFile(String filePath);

  /// Deletes unreferenced files within the dedicated screenshot directory.
  ///
  /// Any file path contained in [keepFilePaths] is preserved.
  Future<int> cleanupOrphanFiles({Set<String> keepFilePaths = const {}});
}
