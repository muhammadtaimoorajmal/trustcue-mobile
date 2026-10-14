import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/payment_request_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/rule_matcher_utils.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late PaymentRequestRule rule;

  setUp(() {
    rule = PaymentRequestRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-payment-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('PaymentRequestRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.payment.solicitation');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.requestsForPayment);
      expect(rule.supportedLanguages, contains('en'));
      expect(rule.limitations, isNotEmpty);
    });
  });

  group('PaymentRequestRule positive cases', () {
    final positiveCases = <String, String>{
      'wire money via Western Union':
          'Please wire money via Western Union to complete the transaction.',
      'Send payment through Bitcoin':
          'Send payment through Bitcoin to confirm the reservation.',
      'pay the clearance fee':
          'You must pay the clearance fee before delivery can proceed.',
      'Purchase an Apple gift card':
          'Purchase an Apple gift card to pay your outstanding balance.',
      'Pay \$150 to claim': 'Pay \$150 to claim your allocated parcel.',
      'wire \$500 via MoneyGram':
          'Please wire \$500 via MoneyGram to our office.',
    };

    positiveCases.forEach((expectedSnippet, input) {
      test('detects payment solicitation in: "$input"', () {
        final snapshot = createSnapshot(input);
        final findings = rule.evaluate(snapshot);

        expect(findings, isNotEmpty);
        final finding = findings.first;
        expect(finding.category, 'requests_for_payment');
        expect(finding.origin, FindingOrigin.localRule);
        expect(finding.producerId, rule.id);

        final evidence = finding.evidence.first;
        expect(evidence.snapshotId, snapshot.id);
        expect(
          snapshot.text.substring(evidence.startOffset, evidence.endOffset),
          evidence.exactExcerpt,
        );
        expect(evidence.exactExcerpt, contains(expectedSnippet));

        EvidenceValidator.validateFinding(
          finding,
          snapshot,
          expectedProducerId: rule.id,
          expectedCategoryId: rule.category.id,
        );
      });
    });
  });

  group('PaymentRequestRule receipts, invoices, and completed payments', () {
    final receiptsAndInvoices = [
      'Payment received: \$50.00. Thank you!',
      'Your receipt for \$25.99 from App Store.',
      'A refund of \$100 has been processed to your account.',
      'Invoice #123 has been paid in full.',
      'We received your wire transfer today.',
      'Total cost for the 3 items is \$45.',
      'Thank you for your payment of \$20.',
    ];

    for (final phrase in receiptsAndInvoices) {
      test('does not flag receipt or benign notification: "$phrase"', () {
        final snapshot = createSnapshot(phrase);
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      });
    }
  });

  group('PaymentRequestRule multilingual and emoji offsets', () {
    test(
      'accurately calculates UTF-16 code-unit offsets after emojis and Urdu',
      () {
        final text =
            '💸 ادائیگی: Please wire money via Western Union immediately.';
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);

        expect(findings, hasLength(1));
        final ref = findings.first.evidence.first;
        expect(ref.exactExcerpt, 'wire money via Western Union');
        expect(
          snapshot.text.substring(ref.startOffset, ref.endOffset),
          'wire money via Western Union',
        );

        EvidenceValidator.validateFinding(
          findings.first,
          snapshot,
          expectedProducerId: rule.id,
        );
      },
    );
  });

  group('PaymentRequestRule multiple distinct and bounding', () {
    test('detects multiple distinct payment requests in single text', () {
      final text =
          'Please wire money via Western Union. Next, pay the clearance fee.';
      final snapshot = createSnapshot(text);
      final findings = rule.evaluate(snapshot);

      expect(findings.length, 2);
    });

    test('bounds findings and throws RuleLimitExceededException on adversarial repeated text', () {
      final repetitive = 'Please wire money via Western Union! ' * 180;
      final snapshot = createSnapshot(repetitive);
      expect(
        () => rule.evaluate(snapshot),
        throwsA(isA<RuleLimitExceededException>()),
      );
    });
  });
}
