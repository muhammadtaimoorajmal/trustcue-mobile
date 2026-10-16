import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/data/serialization/cloud_report_summary_codec.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

void main() {
  const codec = CloudReportSummaryCodec();

  group('CloudReportSummaryCodec Privacy & Encoding Tests', () {
    test('encodeReport strictly omits raw text, excerpts, and quotes', () {
      final snapshot = TextSnapshot(
        id: 'snap-1',
        text: 'Urgent: Verify your banking credentials at fake.com now!',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 16),
      );

      final localReport = AnalysisReport(
        id: 'rep-001',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 16),
        findings: [
          AnalysisFinding(
            id: 'f-1',
            category: 'urgency',
            explanation: 'Immediate action required',
            origin: FindingOrigin.localRule,
            producerId: 'rule.urgency',
            evidence: [
              EvidenceReference(
                snapshotId: 'snap-1',
                startOffset: 0,
                endOffset: 6,
                exactExcerpt: 'Urgent',
              ),
            ],
          ),
          AnalysisFinding(
            id: 'f-2',
            category: 'credential_harvesting',
            explanation: 'Asks for credentials',
            origin: FindingOrigin.remoteAi,
            producerId: 'ai.credentials',
            evidence: [
              EvidenceReference(
                snapshotId: 'snap-1',
                startOffset: 8,
                endOffset: 14,
                exactExcerpt: 'Verify',
              ),
            ],
          ),
        ],
        limitations: const [],
        suggestedActions: const [],
      );

      final report = SavedReport(
        id: 'rep-001',
        schemaVersion: 1,
        snapshot: snapshot,
        accountId: 'usr-123',
        analyzedAt: DateTime.utc(2026, 10, 16),
        savedAt: DateTime.utc(2026, 10, 16),
        localReport: localReport,
      );

      final encoded = codec.encodeReport(report);

      expect(encoded['formatVersion'], equals(1));
      expect(encoded['outcomeState'], equals('indicatorsDetected'));
      expect(encoded['hasAiAnalysis'], isFalse);
      expect(encoded['indicatorCount'], equals(2));
      expect(
        encoded['categories'],
        equals(['credential_harvesting', 'urgency']),
      );
      expect(encoded['source'], equals('messageText'));

      // Ensure no raw text, passwords, or excerpt keys exist
      expect(encoded.containsKey('text'), isFalse);
      expect(encoded.containsKey('rawText'), isFalse);
      expect(encoded.containsKey('snapshot'), isFalse);
      expect(encoded.containsKey('findings'), isFalse);
      expect(encoded.toString().contains('banking credentials'), isFalse);
    });

    test('encodeSummary produces valid sanitized summary', () {
      final summary = SavedReportSummary(
        id: 'rep-002',
        schemaVersion: 1,
        snapshotId: 'snap-2',
        accountId: 'usr-123',
        inputSource: InputSource.screenshot,
        analyzedAt: DateTime.utc(2026, 10, 16),
        savedAt: DateTime.utc(2026, 10, 16),
        hasAiAnalysis: true,
        findingsCount: 3,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        previewText: 'This preview text is not included in cloud payload',
      );

      final encoded = codec.encodeSummary(summary);

      expect(encoded['formatVersion'], equals(1));
      expect(encoded['outcomeState'], equals('indicatorsDetected'));
      expect(encoded['hasAiAnalysis'], isTrue);
      expect(encoded['indicatorCount'], equals(3));
      expect(encoded['source'], equals('screenshot'));
      expect(encoded.containsKey('previewText'), isFalse);
      expect(
        encoded.toString().contains('preview text is not included'),
        isFalse,
      );
    });

    test('assertPrivacySanitized rejects forbidden keys', () {
      expect(
        () => codec.assertPrivacySanitized({'text': 'hello'}),
        throwsA(isA<StateError>()),
      );
      expect(
        () => codec.assertPrivacySanitized({'raw_text': 'hello'}),
        throwsA(isA<StateError>()),
      );
      expect(
        () => codec.assertPrivacySanitized({
          'evidence': ['quote'],
        }),
        throwsA(isA<StateError>()),
      );
      expect(
        () => codec.assertPrivacySanitized({'screenshot': 'data:image/png'}),
        throwsA(isA<StateError>()),
      );
      expect(
        () => codec.assertPrivacySanitized({'hash': 'abc123sha'}),
        throwsA(isA<StateError>()),
      );
      expect(
        () => codec.assertPrivacySanitized({'ocr_text': 'scanned text'}),
        throwsA(isA<StateError>()),
      );
      expect(
        () => codec.assertPrivacySanitized({
          'nested': {
            'deep': {'rawText': 'secret'},
          },
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('toJsonString serializes safely and enforces bounded size', () {
      final valid = {
        'formatVersion': 1,
        'outcomeState': 'safe',
        'indicatorCount': 0,
      };
      final jsonStr = codec.toJsonString(valid);
      expect(jsonStr, isNotEmpty);
      expect(jsonStr.contains('formatVersion'), isTrue);

      final huge = {
        'hugeData': List.generate(50000, (i) => 'test-data-padding-$i'),
      };
      expect(() => codec.toJsonString(huge), throwsArgumentError);
    });
  });
}
