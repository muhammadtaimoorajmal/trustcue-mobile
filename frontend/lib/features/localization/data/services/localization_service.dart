import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustcue_mobile/features/localization/domain/models/app_language.dart';

/// Contract and service managing language preference persistence.
class LocalizationService {
  static const String prefKey = 'trustcue.language.preference';

  final SharedPreferences? _injectedPrefs;

  LocalizationService({SharedPreferences? preferences})
    : _injectedPrefs = preferences;

  Future<SharedPreferences> _getPrefs() async {
    return _injectedPrefs ?? await SharedPreferences.getInstance();
  }

  /// Retrieves the saved language preference, defaulting to [AppLanguage.system].
  Future<AppLanguage> getSavedLanguage() async {
    final prefs = await _getPrefs();
    final code = prefs.getString(prefKey);
    return AppLanguage.fromCode(code);
  }

  /// Saves the user's language choice.
  Future<void> saveLanguage(AppLanguage language) async {
    final prefs = await _getPrefs();
    await prefs.setString(prefKey, language.code);
  }
}
