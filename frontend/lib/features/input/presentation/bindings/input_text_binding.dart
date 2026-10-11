import 'package:get/get.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';

/// Bindings for the message text input route.
class InputTextBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InputTextController>(() => InputTextController());
  }
}
