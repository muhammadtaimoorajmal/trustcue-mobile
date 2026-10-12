import 'dart:io';

import 'package:get/get.dart';

import '../../data/services/default_image_picker_adapter.dart';
import '../../data/services/default_screenshot_storage_service.dart';
import '../../domain/contracts/image_picker_adapter.dart';
import '../../domain/contracts/screenshot_storage_service.dart';
import '../../domain/models/selected_image_descriptor.dart';
import '../../domain/validation/image_validator.dart';

/// The workflow purpose for which the image picker was opened.
enum PickerPurpose { screenshot, qrCode }

/// Lightweight coordinator that checks for Android picker results interrupted
/// by process death once per application startup.
class ScreenshotRecoveryCoordinator extends GetxController {
  ScreenshotRecoveryCoordinator({
    ImagePickerAdapter? pickerAdapter,
    ScreenshotStorageService? storageService,
    String Function()? idGenerator,
  }) : _pickerAdapter = pickerAdapter ?? DefaultImagePickerAdapter(),
       _storageService = storageService ?? DefaultScreenshotStorageService(),
       _idGenerator = idGenerator ?? _defaultIdGenerator;

  final ImagePickerAdapter _pickerAdapter;
  final ScreenshotStorageService _storageService;
  final String Function() _idGenerator;

  final Rxn<SelectedImageDescriptor> pendingRecoveredImage =
      Rxn<SelectedImageDescriptor>();
  final RxBool hasChecked = false.obs;
  PickerPurpose? lastInitiatedPurpose;

  /// Checks for lost picker results exactly once per startup.
  Future<void> checkForLostData() async {
    if (hasChecked.value) return;
    hasChecked.value = true;

    try {
      final lostData = await _pickerAdapter.retrieveLostData();
      if (lostData == null || lostData.isEmpty || lostData.file == null) {
        return;
      }

      final sourceXFile = lostData.file!;
      final sourceFile = File(sourceXFile.path);
      if (!await sourceFile.exists()) return;

      // Validate image before importing
      final validation = await ImageValidator.validateFile(sourceFile);
      if (validation.isInvalid) return;

      // Import candidate into bounded app-owned storage
      final importedFile = await _storageService.importCandidateFile(
        sourceXFile,
        fileExtension: validation.format == ImageFormat.png ? '.png' : '.jpg',
      );

      final descriptor = SelectedImageDescriptor(
        id: 'rec-${_idGenerator()}',
        format: validation.format!,
        width: validation.width!,
        height: validation.height!,
        byteCount: validation.byteCount!,
        filePath: importedFile.path,
      );

      pendingRecoveredImage.value = descriptor;
    } catch (_) {
      // Ignored: failures during recovery must not crash startup
    }
  }

  /// Consumes and claims the recovered image descriptor for the active screen.
  SelectedImageDescriptor? consumeRecoveredImage([PickerPurpose? purpose]) {
    if (purpose != null &&
        lastInitiatedPurpose != null &&
        lastInitiatedPurpose != purpose) {
      return null;
    }
    final image = pendingRecoveredImage.value;
    pendingRecoveredImage.value = null;
    lastInitiatedPurpose = null;
    return image;
  }

  /// Dismisses and cleans up any unconsumed recovered image copy.
  Future<void> dismissRecovery() async {
    final image = pendingRecoveredImage.value;
    pendingRecoveredImage.value = null;
    if (image != null) {
      await _storageService.deleteOwnedFile(image.filePath);
    }
  }

  static String _defaultIdGenerator() {
    return DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  }
}
