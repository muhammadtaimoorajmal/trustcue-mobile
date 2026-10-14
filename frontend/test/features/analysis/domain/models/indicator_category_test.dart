import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';

void main() {
  group('IndicatorCategory Taxonomy Tests', () {
    test(
      'Defines all 10 planned indicator category families with unique IDs',
      () {
        expect(IndicatorCategory.values.length, 10);

        final ids = IndicatorCategory.values.map((c) => c.id).toSet();
        expect(
          ids.length,
          10,
          reason: 'Every indicator category must have a distinct stable ID',
        );

        expect(IndicatorCategory.urgencyOrPressure.id, 'urgency_or_pressure');
        expect(
          IndicatorCategory.requestsForCredentials.id,
          'requests_for_credentials',
        );
        expect(
          IndicatorCategory.requestsForVerificationCodes.id,
          'requests_for_verification_codes',
        );
        expect(IndicatorCategory.requestsForPayment.id, 'requests_for_payment');
        expect(
          IndicatorCategory.accountSuspensionOrThreats.id,
          'account_suspension_or_threats',
        );
        expect(
          IndicatorCategory.claimedIdentityOrImpersonation.id,
          'claimed_identity_or_impersonation',
        );
        expect(IndicatorCategory.rewardsOrPrizes.id, 'rewards_or_prizes');
        expect(
          IndicatorCategory.jobOrRecruitmentOffers.id,
          'job_or_recruitment_offers',
        );
        expect(
          IndicatorCategory.investmentOrReturnPromises.id,
          'investment_or_return_promises',
        );
        expect(
          IndicatorCategory.linkStructuralIndicators.id,
          'link_structural_indicators',
        );
      },
    );

    test('Each category possesses non-empty human-readable label and plain-language description', () {
      for (final category in IndicatorCategory.values) {
        expect(category.label.trim().isNotEmpty, isTrue);
        expect(category.description.trim().isNotEmpty, isTrue);
        expect(category.id.trim().isNotEmpty, isTrue);
        // IDs are snake_case and lowercase
        expect(category.id, matches(r'^[a-z_]+$'));
      }
    });

    test('Resolves category by stable ID correctly', () {
      expect(
        IndicatorCategory.fromId('urgency_or_pressure'),
        IndicatorCategory.urgencyOrPressure,
      );
      expect(
        IndicatorCategory.fromId('requests_for_payment'),
        IndicatorCategory.requestsForPayment,
      );
      expect(
        IndicatorCategory.fromId('link_structural_indicators'),
        IndicatorCategory.linkStructuralIndicators,
      );
    });

    test('Returns null for unknown or invalid category ID', () {
      expect(IndicatorCategory.fromId('unknown_category'), isNull);
      expect(IndicatorCategory.fromId(''), isNull);
      expect(IndicatorCategory.fromId('URGENCY_OR_PRESSURE'), isNull);
    });
  });
}
