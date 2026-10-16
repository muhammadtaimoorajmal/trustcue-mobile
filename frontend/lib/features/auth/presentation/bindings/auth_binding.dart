import 'package:get/get.dart';
import 'package:trustcue_mobile/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/login_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/register_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/reset_password_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/verify_email_controller.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';

import 'package:trustcue_mobile/features/auth/data/services/account_api_client.dart';
import 'package:trustcue_mobile/features/reports/data/database/app_database.dart';
import 'package:trustcue_mobile/features/reports/data/services/report_sync_service.dart';
import 'package:trustcue_mobile/features/reports/data/services/sync_api_client.dart';

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

    if (!Get.isRegistered<LocalReportRepository>()) {
      Get.lazyPut<LocalReportRepository>(
        () => AppDatabase.getInstance(),
        fenix: true,
      );
    }

    if (!Get.isRegistered<AccountApiClient>()) {
      Get.lazyPut<AccountApiClient>(
        () => AccountApiClient(
          tokenProvider: () => Get.find<AuthRepository>().getAccessToken(),
        ),
        fenix: true,
      );
    }

    if (!Get.isRegistered<SyncApiClient>()) {
      Get.lazyPut<SyncApiClient>(
        () => SyncApiClient(
          tokenProvider: () => Get.find<AuthRepository>().getAccessToken(),
        ),
        fenix: true,
      );
    }

    if (!Get.isRegistered<ReportSyncService>()) {
      Get.lazyPut<ReportSyncService>(
        () => ReportSyncService(
          repository: Get.find<LocalReportRepository>(),
          syncApiClient: Get.find<SyncApiClient>(),
          accountApiClient: Get.find<AccountApiClient>(),
        ),
        fenix: true,
      );
    }

    if (!Get.isRegistered<AuthController>()) {
      Get.lazyPut<AuthController>(
        () => AuthController(
          authRepository: Get.find<AuthRepository>(),
          accountApiClient: Get.isRegistered<AccountApiClient>()
              ? Get.find<AccountApiClient>()
              : null,
          reportRepository: Get.isRegistered<LocalReportRepository>()
              ? Get.find<LocalReportRepository>()
              : null,
          syncService: Get.isRegistered<ReportSyncService>()
              ? Get.find<ReportSyncService>()
              : null,
        ),
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
