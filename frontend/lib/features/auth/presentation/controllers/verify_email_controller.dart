import 'dart:async';

import 'package:get/get.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';

class VerifyEmailController extends GetxController {
  VerifyEmailController({required this.authRepository, this.initialEmail});

  final AuthRepository authRepository;
  final String? initialEmail;

  late final String email;
  final RxInt cooldownSeconds = 0.obs;
  final RxBool isResending = false.obs;
  final RxnString statusMessage = RxnString();
  final RxnString errorMessage = RxnString();

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['email'] is String) {
      email = args['email'] as String;
    } else {
      email = initialEmail ?? '';
    }
  }

  Future<void> resendVerification() async {
    if (cooldownSeconds.value > 0 || isResending.value) return;
    if (email.isEmpty) {
      errorMessage.value = 'Missing email address for verification.';
      return;
    }

    isResending.value = true;
    errorMessage.value = null;
    statusMessage.value = null;

    final result = await authRepository.resendVerificationEmail(email: email);
    isResending.value = false;

    result.when(
      success: (_) {
        statusMessage.value = 'Verification request sent. Please check your inbox or spam folder.';
        _startCooldown(60);
      },
      failure: (failure) {
        if (failure.code == AuthFailureCode.rateLimitExceeded) {
          errorMessage.value =
              'Too many requests sent. Please wait before trying again.';
          _startCooldown(failure.retryAfterSeconds ?? 60);
        } else {
          errorMessage.value = failure.message;
        }
      },
    );
  }

  void _startCooldown(int seconds) {
    cooldownSeconds.value = seconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (cooldownSeconds.value > 1) {
        cooldownSeconds.value--;
      } else {
        cooldownSeconds.value = 0;
        timer.cancel();
      }
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
