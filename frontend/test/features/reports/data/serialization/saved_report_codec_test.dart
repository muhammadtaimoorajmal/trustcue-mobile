import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/data/serialization/saved_report_codec.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

void main() {
  group('SavedReportCodec Tests', () {
    const codec = SavedReportCodec();
    late TextSnapshot snapshot;
    late AnalysisFinding finding;
    late AnalysisReport localReport;

    setUp(() {
      snapshot = TextSnapshot(
        id: 'snap-codec-001',
        text:
            'Warning 🛡️: Immediate action required. Call 1-800-555-FAKE now.',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 10, 0, 0),
      );

      const localExcerpt = 'Immediate action required.';
      final localStart = snapshot.text.indexOf(localExcerpt);
      final localEnd = localStart + localExcerpt.length;

      finding = AnalysisFinding(
        id: 'finding-codec-1',
        category: 'urgency',
        explanation: 'Pressures the recipient to act immediately.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.urgency',
        evidence: [
          EvidenceReference(
            snapshotId: snapshot.id,
            startOffset: localStart,
            endOffset: localEnd,
            exactExcerpt: localExcerpt,
          ),
        ],
      );

      localReport = AnalysisReport(
        id: 'rep-codec-001',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 15, 10, 0, 2),
        findings: [finding],
        limitations: const ['Evaluated standard urgency patterns.'],
        suggestedActions: const ['Do not call unknown phone numbers.'],
      );
    });

    test('round-trips SavedReport with local analysis only', () {
      final savedReport = SavedReport(
        id: 'saved-codec-001',
        snapshot: snapshot,
        accountId: null,
        analyzedAt: localReport.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 10, 1, 0),
        localReport: localReport,
      );

      final encodedMap = codec.encode(savedReport);
      expect(encodedMap['formatVersion'], equals(1));
      expect(encodedMap['id'], equals('saved-codec-001'));
      expect(encodedMap['snapshotId'], equals('snap-codec-001'));
      expect(encodedMap['accountId'], isNull);
      expect(encodedMap['aiReport'], isNull);

      final jsonStr = codec.encodeJson(savedReport);
      final decoded = codec.decodeJson(jsonStr, snapshot);

      expect(decoded.id, equals(savedReport.id));
      expect(decoded.schemaVersion, equals(savedReport.schemaVersion));
      expect(decoded.snapshot.id, equals(snapshot.id));
      expect(decoded.snapshot.text, equals(snapshot.text));
      expect(decoded.accountId, isNull);
      expect(decoded.hasAiAnalysis, isFalse);
      expect(decoded.localReport.id, equals(localReport.id));
      expect(decoded.localReport.findings.length, equals(1));
      expect(
        decoded.localReport.findings.first.evidence.first.exactExcerpt,
        equals('Immediate action required.'),
      );
    });

    test('round-trips SavedReport with cloud AI report included', () {
      const aiExcerpt = '1-800-555-FAKE';
      final aiStart = snapshot.text.indexOf(aiExcerpt);
      final aiEnd = aiStart + aiExcerpt.length;

      final aiFinding = AnalysisFinding(
        id: 'ai-finding-codec-1',
        category: 'phone',
        explanation: 'Suspicious toll-free number identified.',
        origin: FindingOrigin.remoteAi,
        producerId: 'groq-cloud',
        evidence: [
          EvidenceReference(
            snapshotId: snapshot.id,
            startOffset: aiStart,
            endOffset: aiEnd,
            exactExcerpt: aiExcerpt,
          ),
        ],
      );

      final aiReport = AiAnalysisReport(
        reportId: 'ai-codec-001',
        snapshotId: snapshot.id,
        provider: 'groq-cloud',
        model: 'qwen/qwen3.8-27b',
        analyzedAt: DateTime.utc(2026, 10, 15, 10, 0, 5),
        factualSummary: 'AI identified urgency combined with suspicious call-back destination.',
        findings: [aiFinding],
        uncertaintyNotes: const [
          'Phone verification requires official carrier checks.',
        ],
        suggestedActions: [
          AssessmentAction(
            id: 'act-codec-1',
            title: 'Verify official contact',
            description: 'Look up the organization phone number on their verified website.',
            priority: AssessmentActionPriority.immediate,
            supportingFindingIds: const ['ai-finding-codec-1'],
            supportingCategoryIds: const ['phone'],
          ),
        ],
      );

      final savedReport = SavedReport(
        id: 'saved-codec-002',
        snapshot: snapshot,
        accountId: 'account-uuid-999',
        analyzedAt: localReport.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 10, 1, 0),
        localReport: localReport,
        aiReport: aiReport,
      );

      final jsonStr = codec.encodeJson(savedReport);
      final decoded = codec.decodeJson(jsonStr, snapshot);

      expect(decoded.hasAiAnalysis, isTrue);
      expect(decoded.accountId, equals('account-uuid-999'));
      expect(decoded.aiReport, isNotNull);
      expect(decoded.aiReport!.reportId, equals('ai-codec-001'));
      expect(decoded.aiReport!.provider, equals('groq-cloud'));
      expect(decoded.aiReport!.model, equals('qwen/qwen3.8-27b'));
      expect(
        decoded.aiReport!.findings.first.evidence.first.exactExcerpt,
        equals('1-800-555-FAKE'),
      );
      expect(
        decoded.aiReport!.suggestedActions.first.title,
        equals('Verify official contact'),
      );
    });

    test('rejects payload with unsupported formatVersion', () {
      final savedReport = SavedReport(
        id: 'saved-codec-003',
        snapshot: snapshot,
        accountId: null,
        analyzedAt: localReport.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 10, 1, 0),
        localReport: localReport,
      );

      final map = codec.encode(savedReport);
      map['formatVersion'] = 99;

      expect(() => codec.decode(map, snapshot), throwsFormatException);
    });

    test(
      'rejects payload when snapshotId does not match provided snapshot',
      () {
        final savedReport = SavedReport(
          id: 'saved-codec-004',
          snapshot: snapshot,
          accountId: null,
          analyzedAt: localReport.analyzedAt,
          savedAt: DateTime.utc(2026, 10, 15, 10, 1, 0),
          localReport: localReport,
        );

        final differentSnapshot = TextSnapshot(
          id: 'snap-different-id',
          text: snapshot.text,
          source: snapshot.source,
          createdAt: snapshot.createdAt,
        );

        final map = codec.encode(savedReport);

        expect(
          () => codec.decode(map, differentSnapshot),
          throwsFormatException,
        );
      },
    );

    test('rejects malformed or corrupt payload structures', () {
      expect(
        () => codec.decodeJson('not-json', snapshot),
        throwsFormatException,
      );

      expect(
        () => codec.decodeJson('{"formatVersion": 1}', snapshot),
        throwsFormatException,
      );

      expect(
        () => codec.decodeJson(
          '{"formatVersion": 1, "id": "rep", "schemaVersion": 1, "snapshotId": "${snapshot.id}", "analyzedAt": "invalid-date", "savedAt": "invalid-date", "localReport": {}}',
          snapshot,
        ),
        throwsFormatException,
      );
    });
  });
}
