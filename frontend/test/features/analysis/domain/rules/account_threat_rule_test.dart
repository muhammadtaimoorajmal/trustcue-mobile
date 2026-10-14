import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/account_threat_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late AccountThreatRule rule;

  setUp(() {
    rule = AccountThreatRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-threat-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('AccountThreatRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.account.threat_or_suspension');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.accountSuspensionOrThreats);
      expect(rule.supportedLanguages, contains('en'));
      expect(rule.limitations, isNotEmpty);
    });
  });

  group('AccountThreatRule positive cases', () {
    final positiveCases = <String, String>{
      'account has been suspended':
          'Your account has been suspended due to suspicious activity.',
      'account will be restricted':
          'Warning: your account will be restricted within 24 hours.',
      'to avoid account suspension':
          'Verify your billing details to avoid account suspension.',
      'suspend your account':
          'Failure to reply will cause us to suspend your account.',
      'account suspension notice':
          'Official account suspension notice: action required.',
      'legal action will be taken':
          'A legal action will be taken against you if you fail to respond.',
      'arrest warrant will be issued':
          'An arrest warrant will be issued for unpaid taxes.',
    };

    positiveCases.forEach((expectedSnippet, input) {
      test('detects account threat in: "$input"', () {
        final snapshot = createSnapshot(input);
        final findings = rule.evaluate(snapshot);

        expect(findings, isNotEmpty);
        final finding = findings.first;
        expect(finding.category, 'account_suspension_or_threats');
        expect(finding.origin, FindingOrigin.localRule);
        expect(finding.producerId, rule.id);

        final evidence = finding.evidence.first;
        expect(evidence.snapshotId, snapshot.id);
        expect(
          snapshot.text.substring(evidence.startOffset, evidence.endOffset),
          evidence.exactExcerpt,
        );
        expect(
          evidence.exactExcerpt.toLowerCase(),
          contains(expectedSnippet.toLowerCase()),
        );

        EvidenceValidator.validateFinding(
          finding,
          snapshot,
          expectedProducerId: rule.id,
          expectedCategoryId: rule.category.id,
        );
      });
    });
  });

  group('AccountThreatRule benign and unrelated phrases', () {
    final benignPhrases = [
      'Please suspend the download for now.',
      'Click here to close this window.',
      'The business meeting was suspended until Monday.',
      'Your account settings have been saved successfully.',
      'You have successfully logged out of your account.',
      'The theater performance was closed early today.',
    ];

    for (final phrase in benignPhrases) {
      test('does not flag benign sentence: "$phrase"', () {
        final snapshot = createSnapshot(phrase);
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      });
    }
  });

  group('AccountThreatRule multilingual and emoji offsets', () {
    test('accurately calculates UTF-16 code-unit offsets after emojis and Urdu', () {
      final text =
          '🚨 انتباہ: Your account has been suspended due to suspicious login.';
      final snapshot = createSnapshot(text);
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(1));
      final ref = findings.first.evidence.first;
      expect(ref.exactExcerpt, contains('account has been suspended'));
      expect(
        snapshot.text.substring(ref.startOffset, ref.endOffset),
        ref.exactExcerpt,
      );

      EvidenceValidator.validateFinding(
        findings.first,
        snapshot,
        expectedProducerId: rule.id,
      );
    });
  });

  group('AccountThreatRule multiple distinct and bounding', () {
    test('detects multiple distinct threats in single message', () {
      final text =
          'Your account has been suspended! Also, legal action will be taken.';
      final snapshot = createSnapshot(text);
      final findings = rule.evaluate(snapshot);

      expect(findings.length, 2);
    });

    test('bounds findings on adversarial repeated text', () {
      final repetitive = 'Your account has been suspended! ' * 180;
      final snapshot = createSnapshot(repetitive);
      final findings = rule.evaluate(snapshot);

      expect(findings.length, lessThanOrEqualTo(105));
    });
  });
}
