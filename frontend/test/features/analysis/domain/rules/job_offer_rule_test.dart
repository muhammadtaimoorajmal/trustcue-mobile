import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/job_offer_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late JobOfferRule rule;

  setUp(() {
    rule = JobOfferRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-job-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('JobOfferRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.job.advance_fee_or_guarantee');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.jobOrRecruitmentOffers);
      expect(rule.supportedLanguages, contains('en'));
      expect(rule.limitations, isNotEmpty);
    });
  });

  group('JobOfferRule positive matches', () {
    final positiveCases = [
      'New job opportunity: pay \$50 registration fee to start.',
      'Deposit required to unlock tasks and begin earning.',
      'Online tasks: recharge balance to start job today.',
      'Part-time work: earn \$500 daily for 15 minutes of work.',
      'Work from home and make \$400 a day in 20 mins with no experience.',
      'Please deposit \$100 to release your commission earnings.',
    ];

    for (final text in positiveCases) {
      test('matches suspicious job offer: "$text"', () {
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);

        expect(findings, isNotEmpty);
        for (final finding in findings) {
          expect(finding.category, IndicatorCategory.jobOrRecruitmentOffers.id);
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

  group('JobOfferRule negative / legitimate recruitment examples', () {
    final negativeCases = [
      'Your job interview is scheduled for tomorrow at 2 PM.',
      'We are hiring a Flutter developer. Please submit your resume at our careers page.',
      'Full-time position available. Salary: \$85,000 per year with health insurance.',
      'Offer letter attached for the Senior Engineer position.',
      'This job requires 3 years of software engineering experience.',
      'Remote work is permitted two days per week.',
    ];

    for (final text in negativeCases) {
      test('does not match legitimate job notice: "$text"', () {
        final snapshot = createSnapshot(text);
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      });
    }
  });

  group('JobOfferRule unicode and formatting integrity', () {
    test('extracts accurate offsets with emoji and Urdu prefix', () {
      final snapshot = createSnapshot(
        '💼 ملازمت: Part-time work from home, earn \$500 daily for 15 minutes of work.',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, isNotEmpty);
      final evidence = findings.first.evidence.first;
      final excerpt = snapshot.text.substring(
        evidence.startOffset,
        evidence.endOffset,
      );
      expect(excerpt.toLowerCase(), contains('earn'));
      expect(excerpt.toLowerCase(), contains('minutes'));
      expect(
        () => EvidenceValidator.validateFinding(findings.first, snapshot),
        returnsNormally,
      );
    });
  });
}
