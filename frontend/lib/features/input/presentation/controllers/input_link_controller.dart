import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';

import '../../data/services/default_image_picker_adapter.dart';
import '../../data/services/default_qr_decoder_service.dart';
import '../../data/services/default_screenshot_storage_service.dart';
import '../../data/services/default_url_launcher_adapter.dart';
import '../../domain/contracts/image_picker_adapter.dart';
import '../../domain/contracts/qr_decoder_service.dart';
import '../../domain/contracts/screenshot_storage_service.dart';
import '../../domain/contracts/url_launcher_adapter.dart';
import '../../domain/models/input_source.dart';
import '../../domain/models/link_inspection_result.dart';
import '../../domain/models/qr_decode_result.dart';
import '../../domain/models/qr_payload.dart';
import '../../domain/models/review_input.dart';
import '../../domain/models/reviewed_text_result.dart';
import '../../domain/models/selected_image_descriptor.dart';
import '../../domain/models/text_snapshot.dart';
import '../../domain/services/url_inspection_service.dart';
import '../../domain/validation/image_validation_policy.dart';
import '../../domain/validation/image_validator.dart';
import 'screenshot_recovery_coordinator.dart';

/// Active intake tab mode for /input/link.
enum LinkIntakeMode { text, qr }

/// Controller managing web address inspection, QR image decoding, destination
/// review, explicit two-step browser opening, and editor handoff.
class InputLinkController extends GetxController {
  InputLinkController({
    UrlInspectionService? urlInspector,
    QrDecoderService? qrDecoderService,
    UrlLauncherAdapter? urlLauncher,
    ImagePickerAdapter? pickerAdapter,
    ScreenshotStorageService? storageService,
    this.recoveryCoordinator,
    String Function()? idGenerator,
  }) : _urlInspector = urlInspector ?? const UrlInspectionService(),
       _qrDecoderService = qrDecoderService ?? DefaultQrDecoderService(),
       _urlLauncher = urlLauncher ?? const DefaultUrlLauncherAdapter(),
       _pickerAdapter = pickerAdapter ?? DefaultImagePickerAdapter(),
       _storageService = storageService ?? DefaultScreenshotStorageService(),
       _idGenerator = idGenerator ?? _defaultIdGenerator;

  final UrlInspectionService _urlInspector;
  final QrDecoderService _qrDecoderService;
  final UrlLauncherAdapter _urlLauncher;
  final ImagePickerAdapter _pickerAdapter;
  final ScreenshotStorageService _storageService;
  final ScreenshotRecoveryCoordinator? recoveryCoordinator;
  final String Function() _idGenerator;

  final Rx<LinkIntakeMode> currentMode = LinkIntakeMode.text.obs;

  // Web address text mode
  final TextEditingController urlTextController = TextEditingController();
  final RxString currentInputText = ''.obs;
  final Rxn<LinkInspectionResult> textInspectionResult =
      Rxn<LinkInspectionResult>();

  // QR image mode
  final Rxn<SelectedImageDescriptor> selectedQrImage =
      Rxn<SelectedImageDescriptor>();
  final RxBool isPickingImage = false.obs;
  final RxBool isDecodingQr = false.obs;
  final Rxn<ImageValidationError> imageValidationError =
      Rxn<ImageValidationError>();
  final Rxn<QrDecodeResult> qrDecodeResult = Rxn<QrDecodeResult>();
  final Rxn<QrPayload> selectedPayload = Rxn<QrPayload>();
  final Rxn<LinkInspectionResult> qrInspectionResult =
      Rxn<LinkInspectionResult>();

  // Browser launch confirmation state
  final RxBool showOpenConfirmation = false.obs;
  final RxBool isOpeningExternal = false.obs;
  final RxnString launchErrorMessage = RxnString();

  // Review integration state
  final RxBool isNavigatingAway = false.obs;
  final Rxn<ReviewedTextResult> reviewedResult = Rxn<ReviewedTextResult>();

  bool _isDisposed = false;

  /// Currently active inspection result depending on active mode.
  LinkInspectionResult? get activeInspection {
    if (currentMode.value == LinkIntakeMode.text) {
      return textInspectionResult.value;
    }
    return qrInspectionResult.value;
  }

  /// Whether current active result is eligible to be opened externally.
  bool get canOpenExternally {
    final result = activeInspection;
    return result != null && result.isLaunchable && result.parsedUri != null;
  }

  @override
  void onInit() {
    super.onInit();

    urlTextController.addListener(_onUrlTextChanged);

    final args = Get.arguments;
    if (args is Map) {
      if (args['sharedUrl'] is String) {
        urlTextController.text = args['sharedUrl'] as String;
        currentMode.value = LinkIntakeMode.text;
      } else if (args['sharedQrImage'] is SelectedImageDescriptor) {
        selectedQrImage.value =
            args['sharedQrImage'] as SelectedImageDescriptor;
        currentMode.value = LinkIntakeMode.qr;
      }
    }

    // Consume any recovered QR image if present
    final recovered = recoveryCoordinator?.consumeRecoveredImage(
      PickerPurpose.qrCode,
    );
    if (recovered != null && selectedQrImage.value == null) {
      selectedQrImage.value = recovered;
      currentMode.value = LinkIntakeMode.qr;
    }
  }

  /// Populates shared URL text without automatically inspecting or launching it.
  void populateSharedUrl(String newUrl) {
    currentMode.value = LinkIntakeMode.text;
    urlTextController.text = newUrl;
    textInspectionResult.value = null;
    showOpenConfirmation.value = false;
    launchErrorMessage.value = null;
  }

  /// Sets a shared QR image descriptor without automatically decoding it.
  void populateSharedQrImage(SelectedImageDescriptor newImage) {
    final old = selectedQrImage.value;
    currentMode.value = LinkIntakeMode.qr;
    selectedQrImage.value = newImage;
    qrDecodeResult.value = null;
    selectedPayload.value = null;
    qrInspectionResult.value = null;
    showOpenConfirmation.value = false;
    launchErrorMessage.value = null;
    if (old != null && old.filePath != newImage.filePath) {
      _storageService.deleteOwnedFile(old.filePath);
    }
  }

  @override
  void onClose() {
    _isDisposed = true;
    urlTextController.removeListener(_onUrlTextChanged);
    urlTextController.dispose();

    // Clean up any app-owned temporary QR image
    final image = selectedQrImage.value;
    if (image != null) {
      _storageService.deleteOwnedFile(image.filePath);
    }

    super.onClose();
  }

  void switchMode(LinkIntakeMode mode) {
    if (currentMode.value == mode) return;
    currentMode.value = mode;
    showOpenConfirmation.value = false;
    launchErrorMessage.value = null;
  }

  void _onUrlTextChanged() {
    final text = urlTextController.text;
    if (currentInputText.value != text) {
      currentInputText.value = text;
      // Invalidate existing confirmation if user alters input
      showOpenConfirmation.value = false;
      launchErrorMessage.value = null;
      reviewedResult.value = null;
    }
  }

  /// Inspects the current text input locally and updates [textInspectionResult].
  void inspectTextLink() {
    showOpenConfirmation.value = false;
    launchErrorMessage.value = null;
    final result = _urlInspector.inspect(urlTextController.text);
    textInspectionResult.value = result;
  }

  /// Chooses or replaces a QR image file with transactional safety.
  Future<bool> chooseQrImage() async {
    if (isPickingImage.value || isDecodingQr.value || _isDisposed) return false;

    isPickingImage.value = true;
    imageValidationError.value = null;
    showOpenConfirmation.value = false;
    launchErrorMessage.value = null;

    try {
      recoveryCoordinator?.lastInitiatedPurpose = PickerPurpose.qrCode;
      final pickedXFile = await _pickerAdapter.pickImage();
      if (pickedXFile == null) {
        // User cancelled picker
        return false;
      }

      final sourceFile = File(pickedXFile.path);
      if (!await sourceFile.exists()) {
        imageValidationError.value = const ImageValidationError(
          reason: ImageValidationReason.corruptOrUnreadable,
          message:
              'Could not access the selected image. Please choose another.',
        );
        return false;
      }

      final validation = await ImageValidator.validateFile(sourceFile);
      if (validation.isInvalid) {
        imageValidationError.value = validation.error;
        return false;
      }

      final ext = validation.format == ImageFormat.png ? '.png' : '.jpg';
      final importedFile = await _storageService.importCandidateFile(
        pickedXFile,
        fileExtension: ext,
      );

      final newDescriptor = SelectedImageDescriptor(
        id: 'qr-${_idGenerator()}',
        format: validation.format!,
        width: validation.width!,
        height: validation.height!,
        byteCount: validation.byteCount!,
        filePath: importedFile.path,
      );

      // Clean up previous image if different
      final previous = selectedQrImage.value;
      if (previous != null && previous.filePath != importedFile.path) {
        await _storageService.deleteOwnedFile(previous.filePath);
      }

      selectedQrImage.value = newDescriptor;
      qrDecodeResult.value = null;
      selectedPayload.value = null;
      qrInspectionResult.value = null;
      reviewedResult.value = null;
      return true;
    } catch (_) {
      imageValidationError.value = const ImageValidationError(
        reason: ImageValidationReason.corruptOrUnreadable,
        message: 'Failed to process selected image. Please try again.',
      );
      return false;
    } finally {
      isPickingImage.value = false;
    }
  }

  /// Removes the currently selected QR image and deletes owned temp file.
  Future<void> removeQrImage() async {
    final current = selectedQrImage.value;
    selectedQrImage.value = null;
    qrDecodeResult.value = null;
    selectedPayload.value = null;
    qrInspectionResult.value = null;
    showOpenConfirmation.value = false;
    launchErrorMessage.value = null;
    reviewedResult.value = null;

    if (current != null) {
      await _storageService.deleteOwnedFile(current.filePath);
    }
  }

  /// Explicitly decodes QR codes from the selected image.
  Future<void> decodeQrImage() async {
    final image = selectedQrImage.value;
    if (image == null || isDecodingQr.value || _isDisposed) return;

    isDecodingQr.value = true;
    qrDecodeResult.value = null;
    selectedPayload.value = null;
    qrInspectionResult.value = null;
    showOpenConfirmation.value = false;
    launchErrorMessage.value = null;
    reviewedResult.value = null;

    try {
      final token = 'qr-decode-${_idGenerator()}';
      final result = await _qrDecoderService.decode(
        image.filePath,
        operationToken: token,
      );
      qrDecodeResult.value = result;

      if (result.hasSingle) {
        selectPayload(result.payloads.first);
      }
    } catch (e) {
      qrDecodeResult.value = QrDecodeResult.error(
        'Failed to decode QR image: $e',
      );
    } finally {
      isDecodingQr.value = false;
    }
  }

  /// Selects one of multiple decoded QR payloads for inspection.
  void selectPayload(QrPayload payload) {
    selectedPayload.value = payload;
    showOpenConfirmation.value = false;
    launchErrorMessage.value = null;

    if (payload.type == QrPayloadType.url) {
      qrInspectionResult.value =
          payload.linkInspection ?? _urlInspector.inspect(payload.rawValue);
    } else {
      qrInspectionResult.value = null;
    }
  }

  /// Initiates the two-step confirmation flow to open external destination.
  void requestOpenExternal() {
    if (!canOpenExternally) return;
    launchErrorMessage.value = null;
    showOpenConfirmation.value = true;
  }

  /// Dismisses the external opening confirmation without navigating.
  void cancelOpenExternal() {
    showOpenConfirmation.value = false;
  }

  /// Executes external browser launch after explicit confirmation.
  Future<bool> confirmOpenExternal() async {
    final uri = activeInspection?.parsedUri;
    if (uri == null || isOpeningExternal.value) return false;

    showOpenConfirmation.value = false;
    isOpeningExternal.value = true;
    launchErrorMessage.value = null;

    try {
      final canLaunch = await _urlLauncher.canLaunch(uri);
      if (!canLaunch) {
        launchErrorMessage.value =
            'No external browser app was found to open this destination.';
        return false;
      }

      final launched = await _urlLauncher.launch(uri);
      if (!launched) {
        launchErrorMessage.value =
            'External browser could not open this link. Please try again.';
        return false;
      }

      return true;
    } catch (e) {
      launchErrorMessage.value = 'Failed to open destination: $e';
      return false;
    } finally {
      isOpeningExternal.value = false;
    }
  }

  /// Navigates to `/input/review` for user review and sensitive-data inspection.
  Future<void> reviewText() async {
    if (isNavigatingAway.value) return;

    final String textToReview;
    final InputSource source;
    final String? imagePath;

    if (currentMode.value == LinkIntakeMode.text) {
      if (textInspectionResult.value?.isValid != true) return;
      textToReview = urlTextController.text;
      source = InputSource.link;
      imagePath = null;
    } else {
      final payload = selectedPayload.value;
      if (payload == null || payload.isOversized) return;
      textToReview = payload.rawValue;
      source = InputSource.qrCode;
      imagePath = selectedQrImage.value?.filePath;
    }

    if (textToReview.trim().isEmpty) return;
    if (utf8.encode(textToReview).length > UrlInspectionService.maxUtf8Bytes) {
      return;
    }

    isNavigatingAway.value = true;
    try {
      final snapshot = TextSnapshot(
        id: 'rev-${_idGenerator()}',
        source: source,
        text: textToReview,
        createdAt: DateTime.now().toUtc(),
      );

      final result = await Get.toNamed(
        AppRoutes.inputReview,
        arguments: ReviewInput(
          snapshot: snapshot,
          sourceRevision: snapshot.id,
          imagePath: imagePath,
        ),
      );

      if (result is ReviewedTextResult) {
        reviewedResult.value = result;
      }
    } finally {
      isNavigatingAway.value = false;
    }
  }

  static String _defaultIdGenerator() {
    return DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  }
}
