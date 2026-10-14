import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/investment_return_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late InvestmentReturnRule rule;

  setUp(() {
    rule = InvestmentReturnRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-invest-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('InvestmentReturnRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.investment.guaranteed_return');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.investmentOrReturnPromises);
      expect(rule.supportedLanguages, contains('en'));
      expect(rule.limitations, isNotEmpty);
    });
  });

  group('InvestmentReturnRule positive matches', () {
    final positiveCases = [
      'Join our crypto pool for guaranteed returns on your deposit.',
      'A risk-free investment opportunity with daily profits.',
      'Double your money in 24 hours with our platform.',
      'Turn \$100 into \$1000 in 48 hours guaranteed.',
      'Earn 5% daily on your investment with our trading bot.',
      'Invest with guaranteed profit and zero risk.',
    ];

    for (final text in positiveCases) {
      test('matches unrealistic investment promise: "$text"', () {
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);

        expect(findings, isNotEmpty);
        for (final finding in findings) {
          expect(
            finding.category,
            IndicatorCategory.investmentOrReturnPromises.id,
          );
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

  group('InvestmentReturnRule negative / legitimate finance examples', () {
    final negativeCases = [
      'Investments are subject to market risks. Capital at risk.',
      'Past performance is not a guarantee of future returns.',
      'Our savings account offers 4.5% APY annual percentage yield.',
      'Bitcoin price moved up by 3% this afternoon.',
      'Learn about index fund investing and long-term asset allocation.',
      'Stock prices may fluctuate based on corporate earnings reports.',
    ];

    for (final text in negativeCases) {
      test(
        'does not match standard financial discussion, rate disclosures, or risk warnings: "$text"',
        () {
          final snapshot = createSnapshot(text);
          final findings = rule.evaluate(snapshot);
          expect(findings, isEmpty);
        },
      );
    }

    test('presence of the word "regulated" does not suppress guaranteed-return match', () {
      final snapshot = createSnapshot(
        'Invest in our regulated fund with guaranteed returns of 50% weekly.',
      );
      final findings = rule.evaluate(snapshot);
      expect(findings, hasLength(1));
      expect(
        () => EvidenceValidator.validateFinding(
          findings.first,
          snapshot,
          expectedProducerId: rule.id,
          expectedCategoryId: rule.category.id,
        ),
        returnsNormally,
      );
    });
  });

  group('InvestmentReturnRule unicode and offset integrity', () {
    test('extracts accurate offsets with emoji and Urdu prefix', () {
      final snapshot = createSnapshot(
        '📈 منافع: Invest today for guaranteed returns on your crypto funds.',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, isNotEmpty);
      final evidence = findings.first.evidence.first;
      final excerpt = snapshot.text.substring(
        evidence.startOffset,
        evidence.endOffset,
      );
      expect(excerpt.toLowerCase(), contains('guaranteed returns'));
      expect(
        () => EvidenceValidator.validateFinding(findings.first, snapshot),
        returnsNormally,
      );
    });
  });
}
