import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/reward_claim_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late RewardClaimRule rule;

  setUp(() {
    rule = RewardClaimRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-reward-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('RewardClaimRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.reward.prize_claim');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.rewardsOrPrizes);
      expect(rule.supportedLanguages, contains('en'));
      expect(rule.limitations, isNotEmpty);
    });
  });

  group('RewardClaimRule positive matches', () {
    final positiveCases = [
      'Congratulations, you won \$1,000,000! Click here to claim your prize.',
      'You are our lucky winner, reply with details to claim your reward.',
      'Selected to receive a free \$500 gift card, claim immediately.',
      'Chosen as the winner of the holiday sweepstakes, reply to collect.',
      'Please pay \$15 shipping fee to claim your prize package.',
      'Wire clearance fee to release your lottery winnings.',
    ];

    for (final text in positiveCases) {
      test('matches reward claim: "$text"', () {
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);

        expect(findings, isNotEmpty);
        for (final finding in findings) {
          expect(finding.category, IndicatorCategory.rewardsOrPrizes.id);
          expect(finding.producerId, rule.id);
          expect(finding.origin, FindingOrigin.localRule);
          expect(finding.evidence, isNotEmpty);

          expect(
            () => EvidenceValidator.validateFinding(
              finding,
              snapshot,
              expectedProducerId: rule.id,
              expectedCategoryId: rule.category.id,
            ),
            returnsNormally,
          );
        }
      });
    }
  });

  group('RewardClaimRule negative / benign competition rules', () {
    final negativeCases = [
      'Official contest rules and terms and conditions apply.',
      'No purchase necessary. Void where prohibited.',
      'Enter for a chance to win a trip to Hawaii.',
      'You earned 100 points on your grocery order. Current points balance: 350.',
      'Redeem points for discount on your next visit.',
      'The Powerball jackpot reached \$500 million this week.',
    ];

    for (final text in negativeCases) {
      test(
        'does not match general contest rules or loyalty points: "$text"',
        () {
          final snapshot = createSnapshot(text);
          final findings = rule.evaluate(snapshot);
          expect(findings, isEmpty);
        },
      );
    }
  });

  group('RewardClaimRule unicode and offset integrity', () {
    test('extracts accurate offsets with emoji and Urdu prefix', () {
      final snapshot = createSnapshot(
        '🎁 مبارک ہو: Congratulations, you won! Click here to claim your reward.',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, isNotEmpty);
      final evidence = findings.first.evidence.first;
      final excerpt = snapshot.text.substring(
        evidence.startOffset,
        evidence.endOffset,
      );
      expect(excerpt.toLowerCase(), contains('congratulations'));
      expect(excerpt.toLowerCase(), contains('claim your reward'));
      expect(
        () => EvidenceValidator.validateFinding(findings.first, snapshot),
        returnsNormally,
      );
    });
  });
}
