import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';

class RegisterController extends GetxController {
  RegisterController({required this.authRepository});

  final AuthRepository authRepository;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final RxBool isPasswordVisible = false.obs;
  final RxBool isConfirmVisible = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString errorMessage = RxnString();

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmVisibility() {
    isConfirmVisible.value = !isConfirmVisible.value;
  }

  Future<void> signUp() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      errorMessage.value = 'Please enter a valid email address.';
      return;
    }

    if (password.length < 6) {
      errorMessage.value = 'Password must be at least 6 characters.';
      return;
    }

    if (password != confirmPassword) {
      errorMessage.value = 'Passwords do not match.';
      return;
    }

    if (isSubmitting.value) return;
    isSubmitting.value = true;
    errorMessage.value = null;

    final result = await authRepository.signUp(
      email: email,
      password: password,
    );

    isSubmitting.value = false;

    result.when(
      success: (user) {
        if (!user.emailVerified) {
          Get.offNamed(AppRoutes.authVerifyEmail, arguments: {'email': email});
        } else {
          Get.offNamed(AppRoutes.account);
        }
      },
      failure: (failure) {
        errorMessage.value = failure.message;
      },
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
