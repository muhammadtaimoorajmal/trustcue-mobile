import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

class OnboardingController extends GetxController {
  OnboardingController(this.preferences);
  final OnboardingPreferences preferences;
  final acknowledged = false.obs;
  final saving = false.obs;
  final error = RxnString();
  bool _completed = false;

  Future<void> complete() async {
    if (!acknowledged.value || saving.value || _completed) return;
    saving.value = true;
    error.value = null;
    try {
      await preferences
          .saveVersion(OnboardingPreferences.currentVersion)
          .timeout(const Duration(seconds: 10));
      _completed = true;
      if (!isClosed) Get.offNamed(AppRoutes.home);
    } catch (_) {
      if (!isClosed) {
        error.value =
            'We couldn’t save your introduction preference. Please try again.';
      }
    } finally {
      if (!isClosed) saving.value = false;
    }
  }
}
