import 'package:get/get.dart';
import 'package:trustcue_mobile/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/login_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/register_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/reset_password_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/verify_email_controller.dart';

class AuthBinding extends Bindings {
  AuthBinding({this.authRepository});

  final AuthRepository? authRepository;

  @override
  void dependencies() {
    ensureInitialized(authRepository: authRepository);
  }

  static void ensureInitialized({AuthRepository? authRepository}) {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(
        () => authRepository ?? SupabaseAuthRepository(),
        fenix: true,
      );
    }

    if (!Get.isRegistered<AuthController>()) {
      Get.lazyPut<AuthController>(
        () => AuthController(authRepository: Get.find<AuthRepository>()),
        fenix: true,
      );
    }
  }
}

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding.ensureInitialized();
    Get.lazyPut<LoginController>(
      () => LoginController(authRepository: Get.find<AuthRepository>()),
    );
  }
}

class RegisterBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding.ensureInitialized();
    Get.lazyPut<RegisterController>(
      () => RegisterController(authRepository: Get.find<AuthRepository>()),
    );
  }
}

class VerifyEmailBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding.ensureInitialized();
    Get.lazyPut<VerifyEmailController>(
      () => VerifyEmailController(authRepository: Get.find<AuthRepository>()),
    );
  }
}

class ForgotPasswordBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding.ensureInitialized();
    Get.lazyPut<ForgotPasswordController>(
      () =>
          ForgotPasswordController(authRepository: Get.find<AuthRepository>()),
    );
  }
}

class ResetPasswordBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding.ensureInitialized();
    Get.lazyPut<ResetPasswordController>(
      () => ResetPasswordController(authRepository: Get.find<AuthRepository>()),
    );
  }
}
