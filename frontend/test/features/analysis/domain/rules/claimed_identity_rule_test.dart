import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/claimed_identity_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late ClaimedIdentityRule rule;

  setUp(() {
    rule = ClaimedIdentityRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-identity-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('ClaimedIdentityRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.impersonation.claimed_authority');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.claimedIdentityOrImpersonation);
      expect(rule.supportedLanguages, contains('en'));
      expect(rule.limitations, isNotEmpty);
      expect(rule.limitations.any((l) => l.contains('heuristic')), isTrue);
    });
  });

  group('ClaimedIdentityRule positive matches', () {
    final positiveCases = [
      'We are the security team, please verify your account.',
      'This is the fraud department calling regarding urgent activity, please call back.',
      'Official alert from your bank: action required to restore service.',
      'Message from IT department: must update your credentials.',
      'I am an agent from the fraud department, please confirm your activity.',
      'Notice from support team: verify your profile immediately.',
    ];

    for (final text in positiveCases) {
      test('matches positive example: "$text"', () {
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);

        expect(findings, isNotEmpty);
        for (final finding in findings) {
          expect(
            finding.category,
            IndicatorCategory.claimedIdentityOrImpersonation.id,
          );
          expect(finding.producerId, rule.id);
          expect(finding.origin, FindingOrigin.localRule);
          expect(finding.evidence, isNotEmpty);

          // Must validate with EvidenceValidator
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

  group('ClaimedIdentityRule negative / near-miss exclusions', () {
    final negativeCases = [
      'The bank opens at 9 AM tomorrow.',
      'According to a news report, the bank raised interest rates yesterday.',
      'I sent an email to the support team earlier today.',
      'IRS announced that the tax filing deadline is April 15th.',
      'Sent from my iPhone. Best regards, IT Department.',
      'Thanks for visiting our bank branch today.',
    ];

    for (final text in negativeCases) {
      test('does not match benign text: "$text"', () {
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      });
    }
  });

  group('ClaimedIdentityRule unicode and formatting integrity', () {
    test('accurately extracts offsets when prefixed with emojis and Urdu', () {
      final snapshot = createSnapshot(
        '🛡️ اہم اطلاع: We are the security team, please verify your details.',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, isNotEmpty);
      final evidence = findings.first.evidence.first;
      final excerpt = snapshot.text.substring(
        evidence.startOffset,
        evidence.endOffset,
      );
      expect(excerpt.toLowerCase(), contains('security team'));
      expect(excerpt.toLowerCase(), contains('verify'));
      expect(
        () => EvidenceValidator.validateFinding(findings.first, snapshot),
        returnsNormally,
      );
    });

    test('deduplicates overlapping phrases into a single finding', () {
      final snapshot = createSnapshot(
        'This is the fraud department from your bank, please call back.',
      );
      final findings = rule.evaluate(snapshot);
      expect(findings.length, 1);
    });
  });
}
