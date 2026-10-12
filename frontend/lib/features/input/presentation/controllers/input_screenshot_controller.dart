import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';

import '../../data/services/default_image_picker_adapter.dart';
import '../../data/services/default_screenshot_storage_service.dart';
import '../../data/services/default_text_recognition_service.dart';
import '../../domain/contracts/image_picker_adapter.dart';
import '../../domain/contracts/screenshot_storage_service.dart';
import '../../domain/contracts/text_recognition_service.dart';
import '../../domain/models/ocr_failure.dart';
import '../../domain/models/ocr_result.dart';
import '../../domain/models/review_input.dart';
import '../../domain/models/reviewed_text_result.dart';
import '../../domain/models/selected_image_descriptor.dart';
import '../../domain/validation/image_validation_policy.dart';
import '../../domain/validation/image_validator.dart';
import 'screenshot_recovery_coordinator.dart';

/// Presentation controller managing screenshot selection, validation, local preview,
/// transactional replacement, temporary file ownership, and on-device text recognition.
class InputScreenshotController extends GetxController {
  InputScreenshotController({
    ImagePickerAdapter? pickerAdapter,
    ScreenshotStorageService? storageService,
    TextRecognitionService? ocrService,
    this.recoveryCoordinator,
    String Function()? idGenerator,
    Duration? ocrTimeout,
  }) : _pickerAdapter = pickerAdapter ?? DefaultImagePickerAdapter(),
       _storageService = storageService ?? DefaultScreenshotStorageService(),
       _ocrService = ocrService ?? DefaultTextRecognitionService(),
       _idGenerator = idGenerator ?? _defaultIdGenerator,
       _ocrTimeout = ocrTimeout ?? const Duration(seconds: 30);

  final ImagePickerAdapter _pickerAdapter;
  final ScreenshotStorageService _storageService;
  final TextRecognitionService _ocrService;
  final ScreenshotRecoveryCoordinator? recoveryCoordinator;
  final String Function() _idGenerator;
  final Duration _ocrTimeout;

  final Rxn<SelectedImageDescriptor> selectedImage =
      Rxn<SelectedImageDescriptor>();
  final RxBool isProcessing = false.obs;
  final Rxn<ImageValidationError> validationError = Rxn<ImageValidationError>();
  final RxBool isNavigatingAway = false.obs;

  // Module 18: OCR state
  final RxBool isExtracting = false.obs;
  final RxBool isNativeSettling = false.obs;
  final Rxn<OcrResult> ocrResult = Rxn<OcrResult>();
  final Rxn<OcrFailure> ocrFailure = Rxn<OcrFailure>();
  final Rxn<ReviewedTextResult> reviewedResult = Rxn<ReviewedTextResult>();

  String? _currentOperationToken;
  final Set<String> _activeReadingFiles = <String>{};
  final Set<String> _pendingDeletionFiles = <String>{};
  bool _isDisposed = false;

  bool get hasImage => selectedImage.value != null;
  bool get hasExtractedText => ocrResult.value != null;

  @override
  void onInit() {
    super.onInit();
    // Claim any recovered image from coordinator if present
    final recovered = recoveryCoordinator?.consumeRecoveredImage(
      PickerPurpose.screenshot,
    );
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
    _isDisposed = true;
    if (_currentOperationToken != null) {
      _ocrService.cancelOperation(_currentOperationToken!);
    }
    _ocrService.dispose();

    // If controller is disposed and not retained, clean up owned file
    final current = selectedImage.value;
    if (current != null) {
      _safelyDeleteOwnedFile(current.filePath);
    }

    super.onClose();
  }

  /// Triggers on-device OCR extraction for the currently selected screenshot.
  Future<void> extractText() async {
    if (!hasImage ||
        isExtracting.value ||
        isNativeSettling.value ||
        _isDisposed) {
      return;
    }

    final image = selectedImage.value!;
    final token = 'ocr-${_idGenerator()}';
    _currentOperationToken = token;

    isExtracting.value = true;
    ocrFailure.value = null;
    reviewedResult.value = null;

    _activeReadingFiles.add(image.filePath);

    try {
      final result = await _ocrService.processImage(
        filePath: image.filePath,
        imageRevision: image.id,
        operationToken: token,
        timeout: _ocrTimeout,
      );

      if (_isDisposed || isClosed) return;

      // Discard results from superseded or cancelled operations
      if (_currentOperationToken != token) return;

      result.fold(
        onSuccess: (extracted) {
          ocrResult.value = extracted;
          ocrFailure.value = null;
        },
        onFailure: (failure) {
          ocrFailure.value = OcrFailure.fromAnalysisFailure(failure);
        },
      );
    } catch (_) {
      if (_isDisposed || isClosed) return;
      if (_currentOperationToken == token) {
        ocrFailure.value = const OcrFailure.internalError();
      }
    } finally {
      _activeReadingFiles.remove(image.filePath);
      _flushPendingDeletions();

      if (!_isDisposed && !isClosed) {
        if (_activeReadingFiles.isEmpty) {
          isNativeSettling.value = false;
        }
        if (_currentOperationToken == token) {
          isExtracting.value = false;
        }
      }
    }
  }

  /// Cancels an in-flight text extraction request.
  Future<void> cancelExtraction() async {
    if (!isExtracting.value || _currentOperationToken == null) return;

    final token = _currentOperationToken!;
    _currentOperationToken = null;
    isExtracting.value = false;
    isNativeSettling.value = true;
    ocrFailure.value = const OcrFailure.userCancelled();

    await _ocrService.cancelOperation(token);

    // Keep settling status truthful until active native read on file completes
    if (_activeReadingFiles.isEmpty) {
      isNativeSettling.value = false;
    }
  }

  /// Navigates to the manual message text entry screen.
  void navigateToMessageInput() {
    if (Get.currentRoute != AppRoutes.inputText) {
      Get.toNamed(AppRoutes.inputText);
    }
  }

  /// Navigates to `/input/review` with extracted OCR snapshot and screenshot path.
  Future<void> navigateToReview() async {
    final ocr = ocrResult.value;
    final img = selectedImage.value;
    if (ocr == null || img == null || isNavigatingAway.value) return;

    isNavigatingAway.value = true;
    try {
      final result = await Get.toNamed(
        AppRoutes.inputReview,
        arguments: ReviewInput(
          snapshot: ocr.snapshot,
          sourceRevision: ocr.imageRevision,
          imagePath: img.filePath,
        ),
      );
      if (result is ReviewedTextResult) {
        reviewedResult.value = result;
      }
    } finally {
      isNavigatingAway.value = false;
    }
  }

  /// Picks a new image or transactionally replaces an existing selection.
  Future<bool> chooseImage() async {
    if (isProcessing.value) return false;
    if (isExtracting.value) {
      await cancelExtraction();
    }
    isProcessing.value = true;
    validationError.value = null;

    try {
      recoveryCoordinator?.lastInitiatedPurpose = PickerPurpose.screenshot;
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

      // Transactional swap: invalidate previous OCR result, reviewed result, and swap image
      final oldImage = selectedImage.value;
      selectedImage.value = newDescriptor;
      validationError.value = null;
      ocrResult.value = null;
      ocrFailure.value = null;
      reviewedResult.value = null;
      _currentOperationToken = null;

      if (oldImage != null) {
        _safelyDeleteOwnedFile(oldImage.filePath);
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

  /// Confirms and removes the current screenshot preview and OCR state.
  Future<bool> requestRemoveImage(BuildContext context) async {
    if (!hasImage) return false;

    final shouldRemove = await confirmRemove(context);
    if (shouldRemove) {
      if (isExtracting.value) {
        await cancelExtraction();
      }

      final current = selectedImage.value;
      selectedImage.value = null;
      validationError.value = null;
      ocrResult.value = null;
      ocrFailure.value = null;
      reviewedResult.value = null;
      _currentOperationToken = null;

      if (current != null) {
        _safelyDeleteOwnedFile(current.filePath);
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
        content: Text(
          hasExtractedText
              ? 'You have a screenshot with extracted text. If you leave now, the preview and extracted text will be discarded.'
              : 'You have a screenshot selected for preview. If you leave now, the preview will be discarded.',
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

      if (isExtracting.value) {
        await cancelExtraction();
      }

      final current = selectedImage.value;
      selectedImage.value = null;
      ocrResult.value = null;
      ocrFailure.value = null;
      _currentOperationToken = null;

      if (current != null) {
        _safelyDeleteOwnedFile(current.filePath);
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

  void _safelyDeleteOwnedFile(String filePath) {
    if (_activeReadingFiles.contains(filePath)) {
      _pendingDeletionFiles.add(filePath);
    } else {
      _storageService.deleteOwnedFile(filePath);
    }
  }

  void _flushPendingDeletions() {
    final readyToDelete = _pendingDeletionFiles
        .where((p) => !_activeReadingFiles.contains(p))
        .toList();
    for (final p in readyToDelete) {
      _pendingDeletionFiles.remove(p);
      _storageService.deleteOwnedFile(p);
    }
  }

  static String _defaultIdGenerator() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = math.Random().nextInt(1000000).toString().padLeft(6, '0');
    return '$now-$random';
  }
}
