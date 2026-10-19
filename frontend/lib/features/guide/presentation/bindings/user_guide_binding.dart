import 'package:get/get.dart';
import 'package:trustcue_mobile/features/guide/presentation/controllers/user_guide_controller.dart';

/// Dependency binding for the offline User Guide screen (`/guide`).
class UserGuideBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserGuideController>(() => UserGuideController());
  }
}
