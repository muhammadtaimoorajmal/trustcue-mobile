import 'package:get/get.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_review_controller.dart';

/// Route binding for the text review and redaction screen (`/input/review`).
class InputReviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InputReviewController>(() => InputReviewController());
  }
}
