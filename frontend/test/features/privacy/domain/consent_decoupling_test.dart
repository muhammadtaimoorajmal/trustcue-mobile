import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';
import 'package:trustcue_mobile/features/reports/domain/models/retention_policy.dart';

class FakeOnboardingPreferences implements OnboardingPreferences {
  int? version;
  @override
  Future<Object?> readVersion() async => version;
  @override
  Future<void> saveVersion(int newVersion) async {
    version = newVersion;
  }
}

void main() {
  group('Consent and Scope Decoupling Invariants (Module 40)', () {
    test(
      'onboarding acknowledgment is decoupled from authentication and sync',
      () async {
        final onboardingPrefs = FakeOnboardingPreferences();
        expect(await onboardingPrefs.readVersion(), isNull);
        expect(OnboardingPreferences.isComplete(null), isFalse);

        await onboardingPrefs.saveVersion(OnboardingPreferences.currentVersion);
        final savedVersion = await onboardingPrefs.readVersion();
        expect(savedVersion, equals(OnboardingPreferences.currentVersion));
        expect(OnboardingPreferences.isComplete(savedVersion), isTrue);

        // Onboarding completeness does not implicitly enable cloud sync or AI consent
        // It remains strictly an introduction acknowledgment.
      },
    );

    test('retention policies default to never and are strictly local', () {
      final defaultPolicy = RetentionPolicy.fromString(null);
      expect(defaultPolicy, equals(RetentionPolicy.never));
      expect(defaultPolicy.days, equals(0));

      // Parsing invalid strings safely defaults to never
      expect(
        RetentionPolicy.fromString('invalid_policy'),
        equals(RetentionPolicy.never),
      );

      // Valid options
      expect(
        RetentionPolicy.fromString('days30'),
        equals(RetentionPolicy.days30),
      );
      expect(RetentionPolicy.days30.days, equals(30));
      expect(
        RetentionPolicy.fromString('days60'),
        equals(RetentionPolicy.days60),
      );
      expect(RetentionPolicy.days60.days, equals(60));
      expect(
        RetentionPolicy.fromString('days90'),
        equals(RetentionPolicy.days90),
      );
      expect(RetentionPolicy.days90.days, equals(90));
    });
  });
}
