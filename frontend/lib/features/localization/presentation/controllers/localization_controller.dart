import 'package:get/get.dart';
import 'package:trustcue_mobile/features/localization/data/services/localization_service.dart';
import 'package:trustcue_mobile/features/localization/domain/models/app_language.dart';

/// Presentation controller managing application language, locale switching, and RTL direction.
class LocalizationController extends GetxController {
  final LocalizationService _service;

  LocalizationController({LocalizationService? service})
    : _service = service ?? LocalizationService();

  final Rx<AppLanguage> currentLanguage = AppLanguage.system.obs;
  final RxBool isRtl = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final saved = await _service.getSavedLanguage();
    currentLanguage.value = saved;
    isRtl.value = saved.isRtl;
  }

  /// Changes the application language and updates the global GetX locale.
  Future<void> changeLanguage(AppLanguage language) async {
    currentLanguage.value = language;
    isRtl.value = language.isRtl;
    await _service.saveLanguage(language);
    final targetLocale = language.toLocale(systemLocale: Get.deviceLocale);
    await Get.updateLocale(targetLocale);
  }
}
