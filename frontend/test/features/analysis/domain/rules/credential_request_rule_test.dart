import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/credential_request_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/rule_matcher_utils.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late CredentialRequestRule rule;

  setUp(() {
    rule = CredentialRequestRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-cred-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('CredentialRequestRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.credential.disclosure_request');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.requestsForCredentials);
      expect(rule.supportedLanguages, contains('en'));
      expect(rule.limitations, isNotEmpty);
    });
  });

  group('CredentialRequestRule positive cases', () {
    final positiveCases = <String, String>{
      'reply with your password':
          'Please reply with your password to restore access.',
      'Send your ATM PIN': 'Send your ATM PIN to confirm your transaction.',
      'Share your login credentials':
          'Share your login credentials with our support team.',
      'Provide your security answer':
          'Provide your security answer to proceed with recovery.',
      'Enter your password at the link':
          'Enter your password at the link below to verify identity.',
      'Confirm your password':
          'Confirm your password to prevent suspension of your profile.',
    };

    positiveCases.forEach((expectedSnippet, input) {
      test('detects credential request in: "$input"', () {
        final snapshot = createSnapshot(input);
        final findings = rule.evaluate(snapshot);

        expect(findings, isNotEmpty);
        final finding = findings.first;
        expect(finding.category, 'requests_for_credentials');
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

  group('CredentialRequestRule negated safety advice handling', () {
    final safetyAdvicePhrases = [
      'Never share your password with anyone.',
      'Do not send your PIN via email.',
      'Our bank will never ask for your password.',
      'Don\x27t share your login credentials.',
      'We never ask for your password or secret answer.',
      'Security tip: Never disclose your password to callers.',
    ];

    for (final phrase in safetyAdvicePhrases) {
      test('does not flag negated safety advice: "$phrase"', () {
        final snapshot = createSnapshot(phrase);
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      });
    }

    test('flags separate actual request even when preceded by safety advice', () {
      final text =
          'Security notice: Never share your password with strangers. However, please send your password to our official agent.';
      final snapshot = createSnapshot(text);
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(1));
      final evidence = findings.first.evidence.first;
      expect(evidence.exactExcerpt, contains('send your password'));
      expect(
        snapshot.text.substring(evidence.startOffset, evidence.endOffset),
        evidence.exactExcerpt,
      );
    });
  });

  group('CredentialRequestRule ordinary sign-in and benign messages', () {
    final benignPhrases = [
      'Please sign in to your account through the official mobile app.',
      'Log in to view your monthly checking account statement.',
      'Your password was changed successfully on Monday.',
      'Your temporary session will expire in 15 minutes.',
      'Click here to reset your forgotten password.',
    ];

    for (final phrase in benignPhrases) {
      test('does not flag benign sign-in instruction: "$phrase"', () {
        final snapshot = createSnapshot(phrase);
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      });
    }
  });

  group('CredentialRequestRule multilingual and emoji offsets', () {
    test(
      'accurately calculates UTF-16 code-unit offsets after emojis and Urdu',
      () {
        final text =
            '🔒 پاس ورڈ کا تحفظ: Please send your password to restore access.';
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);

        expect(findings, hasLength(1));
        final ref = findings.first.evidence.first;
        expect(ref.exactExcerpt, contains('send your password'));
        expect(
          snapshot.text.substring(ref.startOffset, ref.endOffset),
          ref.exactExcerpt,
        );

        EvidenceValidator.validateFinding(
          findings.first,
          snapshot,
          expectedProducerId: rule.id,
        );
      },
    );
  });

  group('CredentialRequestRule repeated occurrences and bounds', () {
    test('detects multiple distinct occurrences', () {
      final text =
          'Send your password now. In addition, submit your ATM PIN immediately.';
      final snapshot = createSnapshot(text);
      final findings = rule.evaluate(snapshot);

      expect(findings.length, 2);
      expect(findings[0].evidence.first.exactExcerpt, contains('password'));
      expect(findings[1].evidence.first.exactExcerpt, contains('PIN'));
    });

    test('bounds findings and throws RuleLimitExceededException on adversarial repeated text', () {
      final repetitive = 'Send your password now! ' * 180;
      final snapshot = createSnapshot(repetitive);
      expect(
        () => rule.evaluate(snapshot),
        throwsA(isA<RuleLimitExceededException>()),
      );
    });
  });
}
