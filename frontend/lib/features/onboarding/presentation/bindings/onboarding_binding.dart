import 'package:get/get.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';
import 'package:trustcue_mobile/features/onboarding/presentation/controllers/onboarding_controller.dart';

class OnboardingBinding extends Bindings {
  OnboardingBinding(this.preferences);
  final OnboardingPreferences preferences;

  @override
  void dependencies() => Get.lazyPut(() => OnboardingController(preferences));
}
