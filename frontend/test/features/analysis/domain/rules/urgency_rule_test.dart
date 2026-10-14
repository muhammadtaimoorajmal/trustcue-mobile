import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/rule_matcher_utils.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/urgency_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late UrgencyRule rule;

  setUp(() {
    rule = UrgencyRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-urgency-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('UrgencyRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.urgency.immediate_action');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.urgencyOrPressure);
      expect(rule.supportedLanguages, contains('en'));
      expect(rule.limitations, isNotEmpty);
    });
  });

  group('UrgencyRule positive cases', () {
    final positiveCases = <String, String>{
      'respond immediately':
          'Please respond immediately to keep your account active.',
      'act right now': 'You must act right now to prevent data loss.',
      'Action required immediately':
          'Action required immediately on your profile.',
      'Immediate attention required':
          'Immediate attention required for security.',
      'verify your account within 24 hours':
          'Please verify your account within 24 hours to avoid suspension.',
      'Final notice before': 'Final notice before your membership expires.',
      'Time is running out': 'Time is running out to confirm your ticket.',
    };

    positiveCases.forEach((expectedSnippet, input) {
      test('detects urgency in: "$input"', () {
        final snapshot = createSnapshot(input);
        final findings = rule.evaluate(snapshot);

        expect(findings, isNotEmpty);
        final finding = findings.first;
        expect(finding.category, 'urgency_or_pressure');
        expect(finding.origin, FindingOrigin.localRule);
        expect(finding.producerId, rule.id);
        expect(finding.evidence, isNotEmpty);

        final evidence = finding.evidence.first;
        expect(evidence.snapshotId, snapshot.id);
        expect(
          snapshot.text.substring(evidence.startOffset, evidence.endOffset),
          evidence.exactExcerpt,
        );
        expect(evidence.exactExcerpt, contains(expectedSnippet));

        // Enforce evidence validation passes
        EvidenceValidator.validateFinding(
          finding,
          snapshot,
          expectedProducerId: rule.id,
          expectedCategoryId: rule.category.id,
        );
      });
    });
  });

  group('UrgencyRule multiple distinct and deduplicated occurrences', () {
    test('detects multiple distinct non-overlapping occurrences', () {
      final input =
          'Please act right now! Also, update your info within 24 hours to avoid issues.';
      final snapshot = createSnapshot(input);
      final findings = rule.evaluate(snapshot);

      expect(findings.length, 2);
      expect(
        findings[0].evidence.first.endOffset,
        lessThanOrEqualTo(findings[1].evidence.first.startOffset),
      );
    });

    test('deduplicates overlapping match candidates cleanly', () {
      final input =
          'Immediate action required immediately to prevent termination.';
      final snapshot = createSnapshot(input);
      final findings = rule.evaluate(snapshot);

      // Should deduplicate overlapping candidates within the single clause
      expect(findings.length, 1);
      final ref = findings.first.evidence.first;
      expect(
        snapshot.text.substring(ref.startOffset, ref.endOffset),
        ref.exactExcerpt,
      );
    });
  });

  group('UrgencyRule negative cases (no false alarms)', () {
    final negativeCases = [
      'I am busy today with homework.',
      'The grocery store is open now.',
      'Let us meet tomorrow afternoon for coffee.',
      'We received your routine package today.',
      'Please submit your weekly timesheet by Friday at 5 PM.',
      'Call me whenever you have free time.',
    ];

    for (final text in negativeCases) {
      test('does not flag benign sentence: "$text"', () {
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      });
    }
  });

  group('UrgencyRule multilingual and emoji offsets', () {
    test(
      'accurately calculates UTF-16 code-unit offsets after emojis and Urdu',
      () {
        final text =
            '⚠️ ضروری خبر: Please respond immediately to update your profile.';
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);

        expect(findings, hasLength(1));
        final ref = findings.first.evidence.first;
        expect(ref.exactExcerpt, 'respond immediately');
        expect(
          snapshot.text.substring(ref.startOffset, ref.endOffset),
          'respond immediately',
        );

        EvidenceValidator.validateFinding(
          findings.first,
          snapshot,
          expectedProducerId: rule.id,
        );
      },
    );
  });

  group('UrgencyRule large inputs and repeated patterns', () {
    test('finds match at the end of large text near maximum length', () {
      final padding = 'This is an ordinary safe message sentence. ' * 150;
      final text = '$padding Please act right now!';
      final snapshot = createSnapshot(text);
      final findings = rule.evaluate(snapshot);

      expect(findings, isNotEmpty);
      final ref = findings.last.evidence.first;
      expect(ref.exactExcerpt, 'act right now');
      expect(
        snapshot.text.substring(ref.startOffset, ref.endOffset),
        'act right now',
      );
    });

    test('bounds match allocations and throws RuleLimitExceededException on adversarial overflow', () {
      final repetitive = 'Please act right now! ' * 200;
      final snapshot = createSnapshot(repetitive);
      expect(
        () => rule.evaluate(snapshot),
        throwsA(isA<RuleLimitExceededException>()),
      );
    });
  });
}
