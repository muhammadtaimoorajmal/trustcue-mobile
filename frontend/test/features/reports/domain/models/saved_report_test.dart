import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

void main() {
  group('SavedReport Domain Model Tests', () {
    late TextSnapshot snapshot;
    late AnalysisFinding localFinding;
    late AnalysisReport localReport;

    setUp(() {
      snapshot = TextSnapshot(
        id: 'snap-100',
        text: 'Urgent: Wire \$5000 immediately to avoid account suspension!',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      localFinding = AnalysisFinding(
        id: 'finding-1',
        category: 'urgency',
        explanation: 'Creates artificial urgency to coerce immediate payment.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.urgency',
        evidence: [
          EvidenceReference(
            snapshotId: snapshot.id,
            startOffset: 0,
            endOffset: 7,
            exactExcerpt: 'Urgent:',
          ),
        ],
      );

      localReport = AnalysisReport(
        id: 'rep-100',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 1),
        findings: [localFinding],
        limitations: const ['Evaluated only English rules.'],
        suggestedActions: const ['Contact your bank directly.'],
      );
    });

    test('instantiates valid SavedReport with local report only', () {
      final savedReport = SavedReport(
        id: 'saved-001',
        snapshot: snapshot,
        accountId: null,
        analyzedAt: localReport.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 12, 5, 0),
        localReport: localReport,
      );

      expect(savedReport.id, equals('saved-001'));
      expect(savedReport.schemaVersion, equals(1));
      expect(savedReport.snapshot.id, equals('snap-100'));
      expect(savedReport.accountId, isNull);
      expect(savedReport.hasAiAnalysis, isFalse);
      expect(savedReport.totalFindingsCount, equals(1));
      expect(
        savedReport.outcomeState,
        equals(AssessmentOutcomeState.indicatorsDetected),
      );
      expect(savedReport.previewText, contains('Urgent: Wire \$5000'));
    });

    test('instantiates valid SavedReport with AI analysis', () {
      const aiExcerpt = 'Wire \$5000';
      final aiStart = snapshot.text.indexOf(aiExcerpt);
      final aiEnd = aiStart + aiExcerpt.length;

      final aiFinding = AnalysisFinding(
        id: 'ai-finding-1',
        category: 'payment',
        explanation: 'Requests untraceable wire transfer under pressure.',
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
        reportId: 'ai-rep-001',
        snapshotId: snapshot.id,
        provider: 'groq-cloud',
        model: 'qwen/qwen3.8-27b',
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 1, 0),
        factualSummary: 'AI identified wire payment demand under urgency.',
        findings: [aiFinding],
        uncertaintyNotes: const [
          'Model findings explain potential indicators.',
        ],
        suggestedActions: [
          AssessmentAction(
            id: 'act-1',
            title: 'Do not wire funds',
            description: 'Legitimate institutions never demand immediate wire transfers.',
            priority: AssessmentActionPriority.immediate,
            supportingFindingIds: const ['ai-finding-1'],
            supportingCategoryIds: const ['payment'],
          ),
        ],
      );

      final savedReport = SavedReport(
        id: 'saved-002',
        snapshot: snapshot,
        accountId: 'user-uuid-123',
        analyzedAt: localReport.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 12, 5, 0),
        localReport: localReport,
        aiReport: aiReport,
      );

      expect(savedReport.hasAiAnalysis, isTrue);
      expect(savedReport.accountId, equals('user-uuid-123'));
      expect(savedReport.totalFindingsCount, equals(2));
      expect(
        savedReport.outcomeState,
        equals(AssessmentOutcomeState.indicatorsDetected),
      );
    });

    test('rejects empty ID or unsupported schema version', () {
      expect(
        () => SavedReport(
          id: '   ',
          snapshot: snapshot,
          analyzedAt: localReport.analyzedAt,
          savedAt: DateTime.utc(2026, 10, 15, 12, 5, 0),
          localReport: localReport,
        ),
        throwsArgumentError,
      );

      expect(
        () => SavedReport(
          id: 'saved-003',
          schemaVersion: 999,
          snapshot: snapshot,
          analyzedAt: localReport.analyzedAt,
          savedAt: DateTime.utc(2026, 10, 15, 12, 5, 0),
          localReport: localReport,
        ),
        throwsArgumentError,
      );
    });

    test('rejects report when finding does not validate against snapshot', () {
      final invalidSnapshot = TextSnapshot(
        id: 'snap-different',
        text: 'Completely different text without the word u-r-g-e-n-t.',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      expect(
        () => SavedReport(
          id: 'saved-004',
          snapshot: invalidSnapshot,
          analyzedAt: localReport.analyzedAt,
          savedAt: DateTime.utc(2026, 10, 15, 12, 5, 0),
          localReport: localReport, // localReport is bound to snapshot, not invalidSnapshot
        ),
        throwsArgumentError,
      );
    });

    test(
      'outcomeState is noIndicatorsMatched when 0 findings are detected',
      () {
        final cleanReport = AnalysisReport(
          id: 'rep-clean',
          snapshot: snapshot,
          analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 1),
          findings: const [],
          limitations: const ['No matches observed for evaluated rules.'],
          suggestedActions: const [],
        );

        final savedReport = SavedReport(
          id: 'saved-clean',
          snapshot: snapshot,
          analyzedAt: cleanReport.analyzedAt,
          savedAt: DateTime.utc(2026, 10, 15, 12, 5, 0),
          localReport: cleanReport,
        );

        expect(savedReport.totalFindingsCount, equals(0));
        expect(
          savedReport.outcomeState,
          equals(AssessmentOutcomeState.noIndicatorsMatched),
        );
      },
    );

    test('preserves complex Unicode, Emojis, Urdu script, and multiline text', () {
      const complexText =
          'Security Alert 🛡️: برائے مہربانی فوری تصدیق کریں۔\nNext line verification.';
      final complexSnapshot = TextSnapshot(
        id: 'snap-complex',
        text: complexText,
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      const colonExcerpt = ':';
      final colonStart = complexText.indexOf(colonExcerpt);
      final colonEnd = colonStart + colonExcerpt.length;

      final complexFinding = AnalysisFinding(
        id: 'f-complex',
        category: 'urgency',
        explanation: 'Urdu urgency phrase detected.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.urdu',
        evidence: [
          EvidenceReference(
            snapshotId: complexSnapshot.id,
            startOffset: colonStart,
            endOffset: colonEnd,
            exactExcerpt: colonExcerpt,
          ),
        ],
      );

      final complexReport = AnalysisReport(
        id: 'rep-complex',
        snapshot: complexSnapshot,
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 1),
        findings: [complexFinding],
        limitations: const ['Multilingual check.'],
        suggestedActions: const ['Verify safely.'],
      );

      final savedReport = SavedReport(
        id: 'saved-complex',
        snapshot: complexSnapshot,
        analyzedAt: complexReport.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 12, 5, 0),
        localReport: complexReport,
      );

      expect(savedReport.snapshot.text, equals(complexText));
      expect(savedReport.previewText, contains('Security Alert 🛡️:'));
    });
  });
}
