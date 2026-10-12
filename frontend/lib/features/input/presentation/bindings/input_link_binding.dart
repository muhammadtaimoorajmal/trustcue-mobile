import 'package:get/get.dart';

import '../controllers/input_link_controller.dart';
import '../controllers/screenshot_recovery_coordinator.dart';

/// Bindings for `/input/link` route.
class InputLinkBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InputLinkController>(
      () => InputLinkController(
        recoveryCoordinator: Get.isRegistered<ScreenshotRecoveryCoordinator>()
            ? Get.find<ScreenshotRecoveryCoordinator>()
            : null,
      ),
    );
  }
}
