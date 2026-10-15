import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';

class LoginController extends GetxController {
  LoginController({required this.authRepository});

  final AuthRepository authRepository;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final RxBool isPasswordVisible = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString errorMessage = RxnString();

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  Future<void> signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please enter both email and password.';
      return;
    }

    if (isSubmitting.value) return;
    isSubmitting.value = true;
    errorMessage.value = null;

    final result = await authRepository.signInWithPassword(
      email: email,
      password: password,
    );

    isSubmitting.value = false;

    result.when(
      success: (user) {
        if (Get.currentRoute == AppRoutes.authLogin) {
          Get.offNamed(AppRoutes.account);
        }
      },
      failure: (failure) {
        if (failure.code == AuthFailureCode.emailNotConfirmed) {
          Get.toNamed(AppRoutes.authVerifyEmail, arguments: {'email': email});
        } else {
          errorMessage.value = failure.message;
        }
      },
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
