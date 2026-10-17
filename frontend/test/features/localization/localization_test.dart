import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustcue_mobile/features/localization/data/services/localization_service.dart';
import 'package:trustcue_mobile/features/localization/domain/models/app_language.dart';
import 'package:trustcue_mobile/features/localization/presentation/translations/app_translations.dart';

void main() {
  group('Localization Infrastructure Tests', () {
    test('AppLanguage maps codes and RTL properties accurately', () {
      expect(AppLanguage.english.code, equals('en'));
      expect(AppLanguage.english.isRtl, isFalse);
      expect(AppLanguage.english.toLocale(), equals(const Locale('en', 'US')));

      expect(AppLanguage.urdu.code, equals('ur'));
      expect(AppLanguage.urdu.isRtl, isTrue);
      expect(AppLanguage.urdu.toLocale(), equals(const Locale('ur', 'PK')));

      expect(AppLanguage.system.code, equals('system'));
      expect(AppLanguage.system.isRtl, isFalse);
      expect(
        AppLanguage.system.toLocale(systemLocale: const Locale('ur', 'PK')),
        equals(const Locale('ur', 'PK')),
      );
      expect(
        AppLanguage.system.toLocale(systemLocale: const Locale('en', 'US')),
        equals(const Locale('en', 'US')),
      );
    });

    test(
      'LocalizationService persists and retrieves language preference',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = LocalizationService();

        expect(await service.getSavedLanguage(), equals(AppLanguage.system));

        await service.saveLanguage(AppLanguage.urdu);
        expect(await service.getSavedLanguage(), equals(AppLanguage.urdu));

        await service.saveLanguage(AppLanguage.english);
        expect(await service.getSavedLanguage(), equals(AppLanguage.english));
      },
    );

    test('AppTranslations dictionary consistency across en_US and ur_PK', () {
      final translations = AppTranslations();
      final keys = translations.keys;

      expect(keys.containsKey('en_US'), isTrue);
      expect(keys.containsKey('ur_PK'), isTrue);

      final enKeys = keys['en_US']!.keys.toSet();
      final urKeys = keys['ur_PK']!.keys.toSet();

      // Check key parity
      final missingInUrdu = enKeys.difference(urKeys);
      expect(
        missingInUrdu,
        isEmpty,
        reason: 'Keys missing in ur_PK: $missingInUrdu',
      );

      final extraInUrdu = urKeys.difference(enKeys);
      expect(extraInUrdu, isEmpty, reason: 'Extra keys in ur_PK: $extraInUrdu');

      // Ensure critical keys are populated
      expect(keys['en_US']!['education_title'], isNotEmpty);
      expect(keys['ur_PK']!['education_title'], isNotEmpty);
      expect(keys['en_US']!['feedback_disclaimer'], isNotEmpty);
      expect(keys['ur_PK']!['feedback_disclaimer'], isNotEmpty);
    });
  });
}
