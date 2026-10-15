import 'package:get/get.dart';
import 'package:trustcue_mobile/features/reports/presentation/controllers/saved_report_detail_controller.dart';

/// Dependency injection binding for SavedReportDetailScreen.
class SavedReportDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SavedReportDetailController>(
      () => SavedReportDetailController(),
    );
  }
}
