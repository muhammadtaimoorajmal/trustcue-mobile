import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';

import '../../data/services/default_image_picker_adapter.dart';
import '../../data/services/default_screenshot_storage_service.dart';
import '../../domain/contracts/image_picker_adapter.dart';
import '../../domain/contracts/screenshot_storage_service.dart';
import '../../domain/models/selected_image_descriptor.dart';
import '../../domain/validation/image_validation_policy.dart';
import '../../domain/validation/image_validator.dart';
import 'screenshot_recovery_coordinator.dart';

/// Presentation controller managing screenshot selection, validation, local preview,
/// transactional replacement, and temporary file ownership.
class InputScreenshotController extends GetxController {
  InputScreenshotController({
    ImagePickerAdapter? pickerAdapter,
    ScreenshotStorageService? storageService,
    this.recoveryCoordinator,
    String Function()? idGenerator,
  }) : _pickerAdapter = pickerAdapter ?? DefaultImagePickerAdapter(),
       _storageService = storageService ?? DefaultScreenshotStorageService(),
       _idGenerator = idGenerator ?? _defaultIdGenerator;

  final ImagePickerAdapter _pickerAdapter;
  final ScreenshotStorageService _storageService;
  final ScreenshotRecoveryCoordinator? recoveryCoordinator;
  final String Function() _idGenerator;

  final Rxn<SelectedImageDescriptor> selectedImage =
      Rxn<SelectedImageDescriptor>();
  final RxBool isProcessing = false.obs;
  final Rxn<ImageValidationError> validationError = Rxn<ImageValidationError>();
  final RxBool isNavigatingAway = false.obs;

  bool get hasImage => selectedImage.value != null;

  @override
  void onInit() {
    super.onInit();
    // Claim any recovered image from coordinator if present
    final recovered = recoveryCoordinator?.consumeRecoveredImage();
    if (recovered != null) {
      selectedImage.value = recovered;
    }

    // Clean up any stale unreferenced files in background
    _storageService.cleanupOrphanFiles(
      keepFilePaths: selectedImage.value != null
          ? {selectedImage.value!.filePath}
          : const {},
    );
  }

  @override
  void onClose() {
    // If controller is disposed and not explicitly retained, clean up owned file
    final current = selectedImage.value;
    if (current != null) {
      _storageService.deleteOwnedFile(current.filePath);
    }
    super.onClose();
  }

  /// Picks a new image or transactionally replaces an existing selection.
  Future<bool> chooseImage() async {
    if (isProcessing.value) return false;
    isProcessing.value = true;
    validationError.value = null;

    try {
      final pickedXFile = await _pickerAdapter.pickImage();
      if (pickedXFile == null) {
        // User cancelled picker: normal, no error, preserve current selection
        return false;
      }

      final sourceFile = File(pickedXFile.path);
      if (!await sourceFile.exists()) {
        validationError.value = const ImageValidationError(
          reason: ImageValidationReason.corruptOrUnreadable,
          message: 'We couldn’t open this image. Please choose another.',
        );
        return false;
      }

      // Check candidate before importing
      final validation = await ImageValidator.validateFile(sourceFile);
      if (validation.isInvalid) {
        validationError.value = validation.error;
        // Transactional: keep existing preview intact
        return false;
      }

      // Import candidate into app-owned storage
      final ext = validation.format == ImageFormat.png ? '.png' : '.jpg';
      final importedFile = await _storageService.importCandidateFile(
        pickedXFile,
        fileExtension: ext,
      );

      final newDescriptor = SelectedImageDescriptor(
        id: 'img-${_idGenerator()}',
        format: validation.format!,
        width: validation.width!,
        height: validation.height!,
        byteCount: validation.byteCount!,
        filePath: importedFile.path,
      );

      // Transactional swap: update preview and delete old owned file
      final oldImage = selectedImage.value;
      selectedImage.value = newDescriptor;
      validationError.value = null;

      if (oldImage != null) {
        await _storageService.deleteOwnedFile(oldImage.filePath);
      }

      return true;
    } catch (_) {
      validationError.value = const ImageValidationError(
        reason: ImageValidationReason.corruptOrUnreadable,
        message: 'We couldn’t open this image. Please choose another.',
      );
      return false;
    } finally {
      isProcessing.value = false;
    }
  }

  /// Confirms and removes the current screenshot preview.
  Future<bool> requestRemoveImage(BuildContext context) async {
    if (!hasImage) return false;

    final shouldRemove = await confirmRemove(context);
    if (shouldRemove) {
      final current = selectedImage.value;
      selectedImage.value = null;
      validationError.value = null;
      if (current != null) {
        await _storageService.deleteOwnedFile(current.filePath);
      }
      return true;
    }
    return false;
  }

  /// Prompts confirmation dialog before removing the preview.
  Future<bool> confirmRemove(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove screenshot?'),
        content: const Text(
          'This removes the preview from TrustCue. The original image remains safely in your gallery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Prompts confirmation dialog when leaving with a selected screenshot.
  Future<bool> confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard screenshot?'),
        content: const Text(
          'You have a screenshot selected for preview. If you leave now, the preview will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep reviewing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Handles back navigation with discard confirmation.
  Future<void> handleBack(BuildContext context) async {
    if (hasImage) {
      final shouldDiscard = await confirmDiscard(context);
      if (!shouldDiscard) return;
      final current = selectedImage.value;
      selectedImage.value = null;
      if (current != null) {
        await _storageService.deleteOwnedFile(current.filePath);
      }
    }

    if (!context.mounted) return;
    isNavigatingAway.value = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.offAllNamed(AppRoutes.home);
    }
  }

  static String _defaultIdGenerator() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = math.Random().nextInt(1000000).toString().padLeft(6, '0');
    return '$now-$random';
  }
}
