import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/incoming_share/data/services/default_incoming_share_adapter.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/contracts/incoming_share_adapter.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/models/incoming_share_payload.dart';
import 'package:trustcue_mobile/features/incoming_share/presentation/widgets/incoming_share_dialog.dart';
import 'package:trustcue_mobile/features/input/data/services/default_screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/selected_image_descriptor.dart';
import 'package:trustcue_mobile/features/input/domain/services/url_inspection_service.dart';
import 'package:trustcue_mobile/features/input/domain/validation/image_validator.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_link_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_screenshot_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

/// The category of conflict detected when an incoming share targets an active draft.
enum DraftConflictType { message, link, screenshot, qrImage }

/// Outcome descriptor for draft conflict check.
class DraftConflict {
  DraftConflict({
    required this.type,
    required this.existingDescription,
    this.importedDescriptor,
  });

  final DraftConflictType type;
  final String existingDescription;
  final SelectedImageDescriptor? importedDescriptor;
}

/// Application coordinator managing incoming Android shares across app lifecycle.
class IncomingShareCoordinator extends GetxController {
  IncomingShareCoordinator({
    IncomingShareAdapter? adapter,
    OnboardingPreferences? preferences,
    ScreenshotStorageService? storageService,
    UrlInspectionService? urlInspector,
    String Function()? idGenerator,
    this.imageBuilder,
    this.onShareRejected,
  }) : _adapter = adapter ?? DefaultIncomingShareAdapter(),
       _preferences = preferences ?? LocalOnboardingPreferences(),
       _storageService = storageService ?? DefaultScreenshotStorageService(),
       _urlInspector = urlInspector ?? UrlInspectionService(),
       _idGenerator = idGenerator ?? _defaultIdGenerator;

  final IncomingShareAdapter _adapter;
  final OnboardingPreferences _preferences;
  final ScreenshotStorageService _storageService;
  final UrlInspectionService _urlInspector;
  final String Function() _idGenerator;
  final Widget Function(BuildContext context, String path)? imageBuilder;
  final void Function(String message)? onShareRejected;

  final Rxn<IncomingSharePayload> pendingShare = Rxn<IncomingSharePayload>();
  final RxBool isDialogVisible = false.obs;
  final Set<String> _consumedEventIds = <String>{};
  StreamSubscription<IncomingSharePayload>? _shareSubscription;
  bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();
    init();
  }

  /// Initializes the coordinator and registers platform channel listeners.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _shareSubscription = _adapter.shareStream.listen(_handleIncomingShare);

    // Check for cold-start initial share delivered with activity creation
    final initial = await _adapter.getInitialShare();
    if (initial != null) {
      await _handleIncomingShare(initial);
    }
  }

  @override
  void onClose() {
    _shareSubscription?.cancel();
    _adapter.dispose();
    super.onClose();
  }

  /// Handles incoming share payload from cold start or onNewIntent.
  Future<void> _handleIncomingShare(IncomingSharePayload payload) async {
    // Suppress duplicate events already consumed or currently pending
    if (_consumedEventIds.contains(payload.eventId)) return;
    if (pendingShare.value?.eventId == payload.eventId) return;

    // Bounded pending share policy: preserve existing pending item and reject additional share
    final existing = pendingShare.value;
    if (existing != null) {
      // Clean up only the rejected item's app-owned temporary file
      if (payload.stagedImagePath != null) {
        await _adapter.cleanStagedFile(payload.stagedImagePath!);
      }
      _consumedEventIds.add(payload.eventId);
      await _adapter.consumeShare(payload.eventId);

      _notifyShareRejected(
        'Another shared item is currently awaiting review. Please complete or dismiss it first.',
      );
      return;
    }

    pendingShare.value = payload;

    // Check onboarding status: onboarding is authoritative; do not show prompt until complete
    final version = await _preferences.readVersion();
    if (OnboardingPreferences.isComplete(version)) {
      presentPendingShare();
    }
  }

  void _notifyShareRejected(String message) {
    onShareRejected?.call(message);
    if (Get.context != null && Get.overlayContext != null) {
      Get.rawSnackbar(
        title: 'Share not processed',
        message: message,
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Invoked when the user completes onboarding, allowing any deferred share to be presented.
  void onOnboardingCompleted() {
    if (pendingShare.value != null &&
        !_consumedEventIds.contains(pendingShare.value!.eventId)) {
      presentPendingShare();
    }
  }

  /// Presents the incoming share review dialog to the user if a pending share exists.
  void presentPendingShare() {
    final payload = pendingShare.value;
    if (payload == null || isDialogVisible.value) return;

    // Only present if Get navigation context is mounted and not on onboarding
    final currentRoute = Get.currentRoute;
    if (currentRoute == AppRoutes.onboarding ||
        currentRoute == AppRoutes.startup) {
      return;
    }

    if (Get.context == null || Get.overlayContext == null) {
      return;
    }

    isDialogVisible.value = true;
    Get.dialog<void>(
      IncomingShareDialog(
        coordinator: this,
        payload: payload,
        imageBuilder: imageBuilder,
      ),
      barrierDismissible: false,
    ).then((_) {
      isDialogVisible.value = false;
    });
  }

  /// Checks if the full text strictly represents a valid single web address.
  bool isSingleWebAddress(String text) {
    final result = _urlInspector.inspect(text);
    return result.isValid;
  }

  /// Dismisses the active pending share and cleans up staged files and native state.
  Future<void> dismissPendingShare({String? expectedEventId}) async {
    final current = pendingShare.value;
    if (current == null) return;
    if (expectedEventId != null && current.eventId != expectedEventId) {
      return;
    }
    pendingShare.value = null;

    _consumedEventIds.add(current.eventId);
    await _adapter.consumeShare(current.eventId);
    if (current.stagedImagePath != null) {
      await _adapter.cleanStagedFile(current.stagedImagePath!);
    }

    if (isDialogVisible.value && Get.isDialogOpen == true) {
      Get.back<void>();
    }
  }

  /// Checks for conflict with an active message text draft.
  DraftConflict? checkMessageDraftConflict() {
    if (Get.isRegistered<InputTextController>()) {
      final controller = Get.find<InputTextController>();
      if (controller.hasDraft) {
        return DraftConflict(
          type: DraftConflictType.message,
          existingDescription:
              'existing message draft (${controller.codePointCount.value} characters)',
        );
      }
    }
    return null;
  }

  /// Applies shared text as message text input.
  Future<void> applySharedMessage(String text, {String? expectedEventId}) async {
    final current = pendingShare.value;
    if (current == null) return;
    if (expectedEventId != null && current.eventId != expectedEventId) {
      return;
    }
    pendingShare.value = null;

    _consumedEventIds.add(current.eventId);
    await _adapter.consumeShare(current.eventId);
    if (current.stagedImagePath != null) {
      await _adapter.cleanStagedFile(current.stagedImagePath!);
    }

    if (isDialogVisible.value && Get.isDialogOpen == true) {
      Get.back<void>();
    }

    if (Get.isRegistered<InputTextController>()) {
      final controller = Get.find<InputTextController>();
      controller.populateSharedText(text);
      if (Get.context != null && Get.currentRoute != AppRoutes.inputText) {
        Get.toNamed(AppRoutes.inputText);
      }
    } else if (Get.context != null) {
      Get.toNamed(AppRoutes.inputText, arguments: {'sharedText': text});
    }
  }

  /// Checks for conflict with an active link input draft.
  DraftConflict? checkLinkDraftConflict() {
    if (Get.isRegistered<InputLinkController>()) {
      final controller = Get.find<InputLinkController>();
      if (controller.urlTextController.text.isNotEmpty) {
        return DraftConflict(
          type: DraftConflictType.link,
          existingDescription:
              'existing web address draft (${controller.urlTextController.text})',
        );
      }
    }
    return null;
  }

  /// Applies shared text as inspected link input.
  Future<void> applySharedLink(String url, {String? expectedEventId}) async {
    final current = pendingShare.value;
    if (current == null) return;
    if (expectedEventId != null && current.eventId != expectedEventId) {
      return;
    }
    pendingShare.value = null;

    _consumedEventIds.add(current.eventId);
    await _adapter.consumeShare(current.eventId);
    if (current.stagedImagePath != null) {
      await _adapter.cleanStagedFile(current.stagedImagePath!);
    }

    if (isDialogVisible.value && Get.isDialogOpen == true) {
      Get.back<void>();
    }

    if (Get.isRegistered<InputLinkController>()) {
      final controller = Get.find<InputLinkController>();
      controller.populateSharedUrl(url);
      if (Get.context != null && Get.currentRoute != AppRoutes.inputLink) {
        Get.toNamed(AppRoutes.inputLink);
      }
    } else if (Get.context != null) {
      Get.toNamed(AppRoutes.inputLink, arguments: {'sharedUrl': url});
    }
  }

  /// Imports and validates a staged image into app-owned storage.
  Future<SelectedImageDescriptor?> importStagedImage(String stagedPath) async {
    final file = File(stagedPath);
    if (!await file.exists()) return null;

    final validation = await ImageValidator.validateFile(file);
    if (validation.isInvalid) return null;

    final imported = await _storageService.importCandidateFile(
      XFile(stagedPath),
      fileExtension: validation.format == ImageFormat.png ? '.png' : '.jpg',
    );

    // Clean up staged copy after importing into dedicated app storage
    await _adapter.cleanStagedFile(stagedPath);

    return SelectedImageDescriptor(
      id: 'share-${_idGenerator()}',
      format: validation.format!,
      width: validation.width!,
      height: validation.height!,
      byteCount: validation.byteCount!,
      filePath: imported.path,
    );
  }

  /// Deletes an imported candidate file from app-owned storage.
  Future<bool> deleteImportedFile(String filePath) async {
    return _storageService.deleteOwnedFile(filePath);
  }

  /// Checks for conflict with an active screenshot draft.
  DraftConflict? checkScreenshotDraftConflict(
    SelectedImageDescriptor imported,
  ) {
    if (Get.isRegistered<InputScreenshotController>()) {
      final controller = Get.find<InputScreenshotController>();
      if (controller.hasImage) {
        return DraftConflict(
          type: DraftConflictType.screenshot,
          existingDescription: 'existing screenshot preview',
          importedDescriptor: imported,
        );
      }
    }
    return null;
  }

  /// Applies imported image as screenshot preview.
  Future<void> applySharedScreenshot(
    SelectedImageDescriptor image, {
    String? expectedEventId,
  }) async {
    final current = pendingShare.value;
    if (current == null) return;
    if (expectedEventId != null && current.eventId != expectedEventId) {
      return;
    }
    pendingShare.value = null;

    _consumedEventIds.add(current.eventId);
    await _adapter.consumeShare(current.eventId);

    if (isDialogVisible.value && Get.isDialogOpen == true) {
      Get.back<void>();
    }

    if (Get.isRegistered<InputScreenshotController>()) {
      final controller = Get.find<InputScreenshotController>();
      controller.populateSharedImage(image);
      if (Get.context != null &&
          Get.currentRoute != AppRoutes.inputScreenshot) {
        Get.toNamed(AppRoutes.inputScreenshot);
      }
    } else if (Get.context != null) {
      Get.toNamed(AppRoutes.inputScreenshot, arguments: {'sharedImage': image});
    }
  }

  /// Checks for conflict with an active QR image draft.
  DraftConflict? checkQrImageDraftConflict(SelectedImageDescriptor imported) {
    if (Get.isRegistered<InputLinkController>()) {
      final controller = Get.find<InputLinkController>();
      if (controller.selectedQrImage.value != null) {
        return DraftConflict(
          type: DraftConflictType.qrImage,
          existingDescription: 'existing QR image draft',
          importedDescriptor: imported,
        );
      }
    }
    return null;
  }

  /// Applies imported image as QR image draft.
  Future<void> applySharedQrImage(
    SelectedImageDescriptor image, {
    String? expectedEventId,
  }) async {
    final current = pendingShare.value;
    if (current == null) return;
    if (expectedEventId != null && current.eventId != expectedEventId) {
      return;
    }
    pendingShare.value = null;

    _consumedEventIds.add(current.eventId);
    await _adapter.consumeShare(current.eventId);

    if (isDialogVisible.value && Get.isDialogOpen == true) {
      Get.back<void>();
    }

    if (Get.isRegistered<InputLinkController>()) {
      final controller = Get.find<InputLinkController>();
      controller.populateSharedQrImage(image);
      if (Get.context != null && Get.currentRoute != AppRoutes.inputLink) {
        Get.toNamed(AppRoutes.inputLink);
      }
    } else if (Get.context != null) {
      Get.toNamed(AppRoutes.inputLink, arguments: {'sharedQrImage': image});
    }
  }

  static String _defaultIdGenerator() {
    return DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  }
}
