import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';

class ForgotPasswordController extends GetxController {
  ForgotPasswordController({required this.authRepository});

  final AuthRepository authRepository;

  final emailController = TextEditingController();
  final RxBool isSubmitting = false.obs;
  final RxBool requestSent = false.obs;
  final RxnString errorMessage = RxnString();

  Future<void> sendResetEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      errorMessage.value = 'Please enter a valid email address.';
      return;
    }

    if (isSubmitting.value) return;
    isSubmitting.value = true;
    errorMessage.value = null;

    final result = await authRepository.sendPasswordResetEmail(email: email);
    isSubmitting.value = false;

    result.when(
      success: (_) {
        requestSent.value = true;
      },
      failure: (failure) {
        if (failure.code == AuthFailureCode.rateLimitExceeded) {
          errorMessage.value = 'Too many requests sent. Please wait before requesting another reset.';
        } else {
          errorMessage.value = failure.message;
        }
      },
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}
