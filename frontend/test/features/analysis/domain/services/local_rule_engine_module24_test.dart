import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/features/analysis/data/serialization/analysis_report_codec.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late LocalRuleEngine engine;

  setUp(() {
    engine = LocalRuleEngine(registry: LocalRuleCatalog.createRegistry());
  });

  TextSnapshot createSnapshot(String text, [String id = 'snap-m24-test']) {
    return TextSnapshot(
      id: id,
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('Targeted Module 23 contract checks & regression coverage', () {
    test('exceeding finding limit propagates typed failure without silent truncation', () async {
      // Create text with 105 distinct non-overlapping urgency occurrences
      final repetitiveUrgency = List.generate(
        105,
        (i) => 'Act immediately now $i!',
      ).join(' ');

      final snapshot = createSnapshot(repetitiveUrgency);
      final result = await engine.analyze(snapshot);

      expect(result.isFailure, isTrue);
      final failure = result.failureOrNull!;
      expect(failure.code, AnalysisFailureCode.unsupportedInput);
      expect(failure.safeDetails, 'max_findings_exceeded');
    });

    test('overlapping matches deduplicate cleanly without triggering false overflow', () async {
      // 10 occurrences where multiple regexes might overlap
      final text = List.generate(
        10,
        (i) => 'Send your password now $i.',
      ).join(' ');

      final snapshot = createSnapshot(text);
      final result = await engine.analyze(snapshot);

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;
      expect(report.findings, hasLength(10));
    });

    test(
      'supports decimal amounts without punctuation clause fragmentation',
      () async {
        final snapshot = createSnapshot(
          'Please wire \$10.50 via Western Union to settle the balance.',
        );
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(report.findings, isNotEmpty);
        expect(
          report.findings.any(
            (f) => f.category == IndicatorCategory.requestsForPayment.id,
          ),
          isTrue,
        );
        final paymentFinding = report.findings.firstWhere(
          (f) => f.category == IndicatorCategory.requestsForPayment.id,
        );
        final excerpt = snapshot.text.substring(
          paymentFinding.evidence.first.startOffset,
          paymentFinding.evidence.first.endOffset,
        );
        expect(excerpt.toLowerCase(), contains('10.50'));
      },
    );

    test(
      'evaluates colon-separated credential requests without clause loss',
      () async {
        final snapshot = createSnapshot('Send the following: your password.');
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(
          report.findings.any(
            (f) => f.category == IndicatorCategory.requestsForCredentials.id,
          ),
          isTrue,
        );
      },
    );

    test('broad exclusions: invoices do not suppress unrelated actionable requests', () async {
      final snapshot = createSnapshot(
        'Invoice attached. Send your password to release the payment.',
      );
      final result = await engine.analyze(snapshot);

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;
      expect(
        report.findings.any(
          (f) => f.category == IndicatorCategory.requestsForCredentials.id,
        ),
        isTrue,
      );
    });

    test(
      'unpaid invoice with explicit payment demand produces payment finding',
      () async {
        final snapshot = createSnapshot(
          'Invoice #1234: Please wire \$500 via Western Union.',
        );
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(
          report.findings.any(
            (f) => f.category == IndicatorCategory.requestsForPayment.id,
          ),
          isTrue,
        );
      },
    );

    test(
      'paid invoice receipt is excluded and produces zero payment findings',
      () async {
        final snapshot = createSnapshot(
          'Thank you for your payment. Invoice has been paid in full. Receipt attached.',
        );
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(
          report.findings.any(
            (f) => f.category == IndicatorCategory.requestsForPayment.id,
          ),
          isFalse,
        );
      },
    );

    test(
      'detects narrow antecedent pronoun pattern with documented limitations',
      () async {
        final snapshot = createSnapshot(
          'Never share your password, but send it to our agent.',
        );
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(
          report.findings.any(
            (f) => f.category == IndicatorCategory.requestsForCredentials.id,
          ),
          isTrue,
        );
      },
    );
  });

  group('Combined 10-rule catalog engine evaluation (Module 24)', () {
    test('evaluates multi-category message and produces sorted, validated findings', () async {
      final message =
          'This is the fraud department, please verify your account. '
          'Act immediately within 24 hours! '
          'Send your password to our support team. '
          'New job: earn \$500 daily for 15 minutes of work. '
          'Congratulations, you won \$1,000,000! Click here to claim your prize. '
          'Invest today for guaranteed returns on your funds. '
          'Visit http://192.168.1.1/login to resolve.';

      final snapshot = createSnapshot(message);
      final result = await engine.analyze(snapshot);

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;
      expect(report.findings.length, greaterThanOrEqualTo(5));

      // Validate every finding with EvidenceValidator
      for (final finding in report.findings) {
        expect(
          () => EvidenceValidator.validateFinding(finding, snapshot),
          returnsNormally,
        );
      }

      // Verify deterministic sorting: start offset ascending
      for (var i = 0; i < report.findings.length - 1; i++) {
        final a = report.findings[i];
        final b = report.findings[i + 1];
        expect(
          a.evidence.first.startOffset <= b.evidence.first.startOffset,
          isTrue,
        );
      }

      // Verify report codec roundtrip
      const codec = AnalysisReportCodec();
      final jsonMap = codec.encode(report);
      final decodedReport = codec.decode(jsonMap);
      expect(decodedReport.findings.length, report.findings.length);
      expect(decodedReport.id, report.id);
    });

    test(
      'empty findings report is never presented as a guarantee of safety',
      () async {
        final benignSnapshot = createSnapshot(
          'Hello friend, hope you are having a wonderful afternoon. See you tomorrow!',
        );
        final result = await engine.analyze(benignSnapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(report.findings, isEmpty);

        // Limitations must explicitly state that zero findings does not guarantee safety
        expect(
          report.limitations.any(
            (l) => l.contains('never a guarantee of safety or legitimacy'),
          ),
          isTrue,
        );
      },
    );
  });
}
