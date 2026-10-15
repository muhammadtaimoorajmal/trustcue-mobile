import 'package:get/get.dart';
import 'package:trustcue_mobile/features/reports/presentation/controllers/history_controller.dart';

/// Dependency injection binding for the HistoryScreen.
class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoryController>(() => HistoryController());
  }
}
