import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';

class ProfileSetupController extends GetxController {
  ProfileSetupController({this.authController});

  final AuthController? authController;

  AuthController get _effectiveAuthController =>
      authController ?? Get.find<AuthController>();

  final displayNameController = TextEditingController();
  final RxBool isSubmitting = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    final currentName = _effectiveAuthController.profile.value?.displayName;
    if (currentName != null && currentName.isNotEmpty) {
      displayNameController.text = currentName;
    }
  }

  Future<void> saveProfile() async {
    final rawName = displayNameController.text;
    final trimmed = rawName.trim();

    if (trimmed.length > 64) {
      errorMessage.value = 'Display name cannot exceed 64 characters.';
      return;
    }

    if (trimmed.isEmpty) {
      errorMessage.value =
          'Please enter a display name or choose "Skip for now".';
      return;
    }

    if (isSubmitting.value) return;
    isSubmitting.value = true;
    errorMessage.value = null;

    final success = await _effectiveAuthController.updateDisplayName(trimmed);
    isSubmitting.value = false;

    if (success) {
      Get.offAllNamed(AppRoutes.account);
    } else {
      errorMessage.value =
          _effectiveAuthController.profileError.value ??
          'Failed to save display name.';
    }
  }

  void skip() {
    Get.offAllNamed(AppRoutes.account);
  }

  @override
  void onClose() {
    displayNameController.dispose();
    super.onClose();
  }
}
