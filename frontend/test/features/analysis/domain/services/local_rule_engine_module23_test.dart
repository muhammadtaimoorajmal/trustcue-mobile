import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/data/serialization/analysis_report_codec.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/core_warning_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late LocalRuleEngine engine;

  setUp(() {
    engine = LocalRuleEngine(
      registry: CoreWarningRuleCatalog.createRegistry(),
      clock: () => DateTime.utc(2026, 10, 14, 15, 30),
      idGenerator: () => 'fixed-engine-test-id',
    );
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-full-engine-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 15, 0),
    );
  }

  group('LocalRuleEngine with CoreWarningRuleCatalog', () {
    test(
      'analyzes combined synthetic message and detects all 5 categories',
      () async {
        final message =
            'URGENT NOTICE: Your account has been suspended! '
            'Please act right now to prevent termination. '
            'Reply with your password, send me the OTP, '
            'and wire money via Western Union to pay the clearance fee.';

        final snapshot = createSnapshot(message);
        final result = await engine.analyze(snapshot);

        expect(result, isA<Success<AnalysisReport>>());
        final report = (result as Success<AnalysisReport>).value;

        expect(report.id, 'report-fixed-engine-test-id');
        expect(report.analyzedAt, DateTime.utc(2026, 10, 14, 15, 30));
        expect(report.snapshot, snapshot);

        // Verify all 5 categories are represented
        final detectedCategories = report.findings
            .map((f) => f.category)
            .toSet();
        expect(
          detectedCategories,
          containsAll([
            'account_suspension_or_threats',
            'urgency_or_pressure',
            'requests_for_credentials',
            'requests_for_verification_codes',
            'requests_for_payment',
          ]),
        );

        // Every single finding must pass strict EvidenceValidator
        for (final finding in report.findings) {
          expect(finding.origin, FindingOrigin.localRule);
          expect(finding.evidence, isNotEmpty);
          expect(finding.producerId, startsWith('rule.'));

          EvidenceValidator.validateFinding(
            finding,
            snapshot,
            expectedProducerId: finding.producerId,
            expectedCategoryId: finding.category,
          );
        }
      },
    );

    test(
      'deterministic evaluation across runs with injected clock and ID',
      () async {
        final message =
            'Please act right now! Send your password and send me the OTP.';
        final snapshot = createSnapshot(message);

        final result1 = await engine.analyze(snapshot);
        final result2 = await engine.analyze(snapshot);

        expect(result1, isA<Success<AnalysisReport>>());
        expect(result2, isA<Success<AnalysisReport>>());

        final report1 = (result1 as Success<AnalysisReport>).value;
        final report2 = (result2 as Success<AnalysisReport>).value;

        expect(report1.id, report2.id);
        expect(report1.analyzedAt, report2.analyzedAt);
        expect(report1.findings.length, report2.findings.length);
        for (var i = 0; i < report1.findings.length; i++) {
          expect(report1.findings[i].id, report2.findings[i].id);
          expect(report1.findings[i].category, report2.findings[i].category);
          expect(
            report1.findings[i].producerId,
            report2.findings[i].producerId,
          );
          expect(
            report1.findings[i].evidence.first.startOffset,
            report2.findings[i].evidence.first.startOffset,
          );
          expect(
            report1.findings[i].evidence.first.endOffset,
            report2.findings[i].evidence.first.endOffset,
          );
        }
      },
    );

    test(
      'empty matches retain honest limitations without claiming safe verdict',
      () async {
        final benignMessage =
            'Hello team, here is the weekly status update for the project.';
        final snapshot = createSnapshot(benignMessage);
        final result = await engine.analyze(snapshot);

        expect(result, isA<Success<AnalysisReport>>());
        final report = (result as Success<AnalysisReport>).value;

        expect(report.findings, isEmpty);
        expect(report.limitations, isNotEmpty);
        expect(
          report.limitations,
          contains(
            'An empty findings report indicates only that no configured local rules matched. It is never a guarantee of safety or legitimacy.',
          ),
        );
      },
    );

    test('report serialization codec round-trip works with core rules findings', () async {
      final message =
          'Your account has been suspended! Please act right now and reply with your password.';
      final snapshot = createSnapshot(message);
      final result = await engine.analyze(snapshot);

      expect(result, isA<Success<AnalysisReport>>());
      final report = (result as Success<AnalysisReport>).value;
      expect(report.findings, isNotEmpty);

      // Serialize and deserialize using AnalysisReportCodec
      const codec = AnalysisReportCodec();
      final encoded = codec.encode(report);
      expect(encoded, isA<Map<String, dynamic>>());

      final decoded = codec.decode(encoded);
      expect(decoded.id, report.id);
      expect(decoded.analyzedAt, report.analyzedAt);

      expect(decoded.findings.length, report.findings.length);
      for (var i = 0; i < report.findings.length; i++) {
        expect(decoded.findings[i].id, report.findings[i].id);
        expect(decoded.findings[i].category, report.findings[i].category);
        expect(
          decoded.findings[i].evidence.first.exactExcerpt,
          report.findings[i].evidence.first.exactExcerpt,
        );
      }
    });
  });
}
