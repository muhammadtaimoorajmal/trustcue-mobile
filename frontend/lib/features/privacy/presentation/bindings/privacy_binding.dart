import 'package:get/get.dart';
import 'package:trustcue_mobile/features/input/data/services/default_screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/privacy/presentation/controllers/privacy_controller.dart';
import 'package:trustcue_mobile/features/reports/data/database/app_database.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_preferences.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_service.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';

/// Dependency injection binding for Privacy Center.
class PrivacyBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<RetentionPreferences>()) {
      Get.lazyPut<RetentionPreferences>(() => LocalRetentionPreferences());
    }

    if (!Get.isRegistered<RetentionService>()) {
      Get.lazyPut<RetentionService>(
        () => RetentionService(
          preferences: Get.find<RetentionPreferences>(),
          repository: Get.isRegistered<LocalReportRepository>()
              ? Get.find<LocalReportRepository>()
              : AppDatabase.getInstance(),
        ),
      );
    }

    Get.lazyPut<PrivacyController>(
      () => PrivacyController(
        repository: Get.isRegistered<LocalReportRepository>()
            ? Get.find<LocalReportRepository>()
            : AppDatabase.getInstance(),
        retentionService: Get.find<RetentionService>(),
        screenshotStorageService: DefaultScreenshotStorageService(),
      ),
    );
  }
}
