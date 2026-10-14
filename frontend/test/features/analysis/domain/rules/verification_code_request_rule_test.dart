import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/verification_code_request_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late VerificationCodeRequestRule rule;

  setUp(() {
    rule = VerificationCodeRequestRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-vcode-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('VerificationCodeRequestRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.verification_code.disclosure_request');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.requestsForVerificationCodes);
      expect(rule.supportedLanguages, contains('en'));
      expect(rule.limitations, isNotEmpty);
    });
  });

  group('VerificationCodeRequestRule positive cases', () {
    final positiveCases = <String, String>{
      'send me the OTP': 'Please send me the OTP you just received.',
      'Reply with the verification code':
          'Reply with the verification code to proceed.',
      'Share your [VERIFICATION CODE]':
          'Share your [VERIFICATION CODE] to authenticate your profile.',
      'Forward the 6-digit code':
          'Forward the 6-digit code to complete the verification.',
      'Text back the one-time passcode':
          'Text back the one-time passcode immediately.',
      'read out the 2fa code':
          'Please read out the 2fa code sent to your phone.',
    };

    positiveCases.forEach((expectedSnippet, input) {
      test('detects code disclosure request in: "$input"', () {
        final snapshot = createSnapshot(input);
        final findings = rule.evaluate(snapshot);

        expect(findings, isNotEmpty);
        final finding = findings.first;
        expect(finding.category, 'requests_for_verification_codes');
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

  group('VerificationCodeRequestRule delivery message exclusions', () {
    final deliveryMessages = [
      'Your verification code is 482910.',
      'Use code 123456 to verify your phone number.',
      'Your one-time passcode is 998877. It expires in 10 minutes.',
      'Your verification code is [VERIFICATION CODE].',
      'Code: 981245. Valid for 10 mins.',
      'Standard Bank: Your login OTP is 334211 for payment of \$15.00.',
    ];

    for (final message in deliveryMessages) {
      test('does not flag delivery message: "$message"', () {
        final snapshot = createSnapshot(message);
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      });
    }
  });

  group('VerificationCodeRequestRule negated safety advice', () {
    final safetyPhrases = [
      'Never share your verification code with anyone, including bank employees.',
      'Do not give this code to anyone.',
      'TrustCue will never ask for your verification code.',
      'Security alert: Don\x27t share your OTP with third parties.',
      'We will never ask you to disclose your two-factor code.',
    ];

    for (final phrase in safetyPhrases) {
      test('does not flag safety advice: "$phrase"', () {
        final snapshot = createSnapshot(phrase);
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      });
    }

    test('flags separate request following safety advice in same message', () {
      final text =
          'Bank notice: Never share your code with strangers. But please reply with the code to verify your phone.';
      final snapshot = createSnapshot(text);
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(1));
      final evidence = findings.first.evidence.first;
      expect(evidence.exactExcerpt, contains('reply with the code'));
      expect(
        snapshot.text.substring(evidence.startOffset, evidence.endOffset),
        evidence.exactExcerpt,
      );
    });
  });

  group('VerificationCodeRequestRule multilingual and emoji offsets', () {
    test(
      'accurately calculates UTF-16 code-unit offsets after emojis and Urdu',
      () {
        final text =
            '🔐 تصدیقی کوڈ: Please share your verification code immediately.';
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);

        expect(findings, hasLength(1));
        final ref = findings.first.evidence.first;
        expect(ref.exactExcerpt, 'share your verification code');
        expect(
          snapshot.text.substring(ref.startOffset, ref.endOffset),
          'share your verification code',
        );

        EvidenceValidator.validateFinding(
          findings.first,
          snapshot,
          expectedProducerId: rule.id,
        );
      },
    );
  });

  group('VerificationCodeRequestRule multiple distinct and bounding', () {
    test('detects multiple distinct requests in message', () {
      final text =
          'Send me the OTP right now. Also, reply with the code immediately.';
      final snapshot = createSnapshot(text);
      final findings = rule.evaluate(snapshot);

      expect(findings.length, 2);
    });

    test('bounds findings on adversarial repeated text', () {
      final repetitive = 'Send me the OTP now! ' * 180;
      final snapshot = createSnapshot(repetitive);
      final findings = rule.evaluate(snapshot);

      expect(findings.length, lessThanOrEqualTo(105));
    });
  });
}
