import 'package:get/get.dart';

import '../controllers/input_screenshot_controller.dart';

class InputScreenshotBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InputScreenshotController>(() => InputScreenshotController());
  }
}
