import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingPreferences {
  static const key = 'trustcue.onboarding.completed_version';
  static const currentVersion = 1;

  Future<Object?> readVersion();
  Future<void> saveVersion(int version);

  static bool isComplete(Object? value) =>
      value is int && value >= currentVersion;
}

class LocalOnboardingPreferences implements OnboardingPreferences {
  LocalOnboardingPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<Object?> readVersion() async {
    // Read only this key and preserve invalid types for explicit validation.
    final values = await _preferences.getAll(
      allowList: {OnboardingPreferences.key},
    );
    return values[OnboardingPreferences.key];
  }

  @override
  Future<void> saveVersion(int version) =>
      _preferences.setInt(OnboardingPreferences.key, version);
}
