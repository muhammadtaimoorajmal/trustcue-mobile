import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';

class ResetPasswordController extends GetxController {
  ResetPasswordController({required this.authRepository});

  final AuthRepository authRepository;

  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final RxBool isPasswordVisible = false.obs;
  final RxBool isConfirmVisible = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isSuccess = false.obs;
  final RxnString errorMessage = RxnString();

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmVisibility() {
    isConfirmVisible.value = !isConfirmVisible.value;
  }

  Future<void> updatePassword() async {
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (newPassword.length < 6) {
      errorMessage.value = 'Password must be at least 6 characters.';
      return;
    }

    if (newPassword != confirmPassword) {
      errorMessage.value = 'Passwords do not match.';
      return;
    }

    if (isSubmitting.value) return;
    isSubmitting.value = true;
    errorMessage.value = null;

    final result = await authRepository.updatePassword(
      newPassword: newPassword,
    );

    isSubmitting.value = false;

    result.when(
      success: (_) {
        isSuccess.value = true;
      },
      failure: (failure) {
        errorMessage.value = failure.message;
      },
    );
  }

  @override
  void onClose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
