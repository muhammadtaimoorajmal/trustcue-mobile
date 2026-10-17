import 'package:get/get.dart';
import 'package:trustcue_mobile/features/education/presentation/controllers/education_controller.dart';
import 'package:trustcue_mobile/features/feedback/data/repositories/sqlite_feedback_repository.dart';
import 'package:trustcue_mobile/features/feedback/domain/contracts/feedback_repository.dart';

/// GetX dependency binding for Education Center features.
class EducationBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<FeedbackRepository>()) {
      Get.lazyPut<FeedbackRepository>(() => SqliteFeedbackRepository());
    }
    if (!Get.isRegistered<EducationController>()) {
      Get.lazyPut<EducationController>(() => EducationController());
    }
  }
}
