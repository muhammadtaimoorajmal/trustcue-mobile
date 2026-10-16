import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustcue_mobile/features/reports/domain/models/retention_policy.dart';

abstract class RetentionPreferences {
  static const key = 'trustcue.retention.policy';

  Future<RetentionPolicy> getRetentionPolicy();
  Future<void> setRetentionPolicy(RetentionPolicy policy);
}

class LocalRetentionPreferences implements RetentionPreferences {
  LocalRetentionPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<RetentionPolicy> getRetentionPolicy() async {
    final values = await _preferences.getAll(
      allowList: {RetentionPreferences.key},
    );
    final raw = values[RetentionPreferences.key] as String?;
    return RetentionPolicy.fromString(raw);
  }

  @override
  Future<void> setRetentionPolicy(RetentionPolicy policy) =>
      _preferences.setString(RetentionPreferences.key, policy.name);
}
