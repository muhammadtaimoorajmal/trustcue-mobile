import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_execution_context.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_options.dart';
import 'package:trustcue_mobile/features/export/domain/services/export_data_extractor.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

void main() {
  group('ExportDataExtractor Tests', () {
    late TextSnapshot snapshot;
    late AnalysisFinding localFinding;
    late AnalysisReport localReport;
    late AiAnalysisReport aiReport;
    late SavedReport savedReport;

    setUp(() {
      snapshot = TextSnapshot(
        id: 'snap-export-1',
        text: 'Urgent: Wire \$5000 immediately to avoid account suspension!',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      localFinding = AnalysisFinding(
        id: 'finding-local-1',
        category: 'urgency',
        explanation: 'Creates artificial urgency to demand immediate action.',
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
        id: 'rep-export-1',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 1),
        findings: [localFinding],
        limitations: const ['Evaluated deterministic on-device rules.'],
        suggestedActions: const [
          'Contact your bank directly via official phone number.',
        ],
      );

      aiReport = AiAnalysisReport(
        reportId: 'ai-rep-1',
        snapshotId: snapshot.id,
        provider: 'Groq',
        model: 'llama-3.3-70b-versatile',
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 1, 0),
        factualSummary: 'AI identified coercive pressure patterns.',
        findings: [
          AnalysisFinding(
            id: 'finding-ai-1',
            category: 'paymentRequest',
            explanation: 'Demands an irreversible wire transfer under threat.',
            origin: FindingOrigin.remoteAi,
            producerId: 'groq.analysis',
            evidence: [
              EvidenceReference(
                snapshotId: snapshot.id,
                startOffset: 8,
                endOffset: 18,
                exactExcerpt: 'Wire \$5000',
              ),
            ],
          ),
        ],
        uncertaintyNotes: const ['AI evaluation is assistive only.'],
        suggestedActions: [
          AssessmentAction(
            id: 'action.verify_payment',
            title: 'Verify transfer request with trusted party',
            description: 'Check official contact channels.',
            priority: AssessmentActionPriority.immediate,
            supportingFindingIds: const ['finding-ai-1'],
            supportingCategoryIds: const ['paymentRequest'],
          ),
        ],
      );

      savedReport = SavedReport(
        id: 'saved-rep-1',
        snapshot: snapshot,
        accountId: 'user-uuid-12345',
        analyzedAt: localReport.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 12, 5, 0),
        localReport: localReport,
        aiReport: aiReport,
      );
    });

    test(
      'extracts from SavedReport with default privacy options (summaries only)',
      () {
        final exportData = ExportDataExtractor.fromSavedReport(
          report: savedReport,
          options: const ExportOptions(),
          exportedAt: DateTime.utc(2026, 10, 17, 10, 0, 0),
        );

        expect(exportData.reportId, 'saved-rep-1');
        expect(exportData.analyzedAt, DateTime.utc(2026, 10, 15, 12, 0, 1));
        expect(exportData.exportedAt, DateTime.utc(2026, 10, 17, 10, 0, 0));
        expect(exportData.inputSource, InputSource.messageText);
        expect(exportData.hasAiAnalysis, isTrue);

        // Default privacy bounds:
        // Reviewed text MUST be null by default
        expect(exportData.reviewedText, isNull);
        expect(exportData.hasReviewedText, isFalse);

        // AI findings are excluded by default
        expect(exportData.findingCount, 1);
        expect(exportData.findings.first.category, 'urgency');

        // Evidence quotes MUST be empty by default
        expect(exportData.findings.first.evidenceQuotes, isEmpty);

        // Limitations include canonical disclaimer
        expect(
          exportData.limitations,
          contains(ExportDataExtractor.canonicalDisclaimer),
        );
        expect(exportData.isCloudSummaryOnly, isFalse);
      },
    );

    test('extracts from SavedReport with all opt-in options enabled', () {
      const options = ExportOptions(
        includeReviewedText: true,
        includeEvidenceQuotes: true,
        includeAiExplanations: true,
      );

      final exportData = ExportDataExtractor.fromSavedReport(
        report: savedReport,
        options: options,
      );

      // Reviewed text is present
      expect(exportData.reviewedText, snapshot.text);
      expect(exportData.hasReviewedText, isTrue);

      // Both local and AI findings are included
      expect(exportData.findingCount, 2);

      // Evidence quotes are populated
      expect(exportData.findings[0].evidenceQuotes, contains('Urgent:'));
      expect(exportData.findings[1].evidenceQuotes, contains('Wire \$5000'));

      // AI uncertainty notes merged into limitations
      expect(
        exportData.limitations,
        contains('AI evaluation is assistive only.'),
      );
    });

    test('extracts from in-memory LocalAssessment seamlessly', () {
      final synthesizer = LocalAssessmentSynthesizer(
        clock: () => DateTime.utc(2026, 10, 16, 14, 0, 0),
      );
      final execContext = AnalysisExecutionContext(
        executedRuleIds: const ['rule.urgency'],
        evaluatedCategories: const [IndicatorCategory.urgencyOrPressure],
      );
      final synthResult = synthesizer.synthesize(
        report: localReport,
        executionContext: execContext,
      );
      final assessment = synthResult.valueOrNull!;

      final exportData = ExportDataExtractor.fromAssessment(
        assessment: assessment,
        snapshot: snapshot,
        aiReport: aiReport,
        options: const ExportOptions(includeReviewedText: true),
      );

      expect(exportData.reportId, 'rep-export-1');
      expect(
        exportData.outcomeState,
        AssessmentOutcomeState.indicatorsDetected,
      );
      expect(exportData.reviewedText, snapshot.text);
      expect(exportData.suggestedActions.isNotEmpty, isTrue);
    });

    test('extracts from high-level SavedReportSummary without leaking missing data', () {
      final summary = SavedReportSummary(
        id: 'summary-001',
        schemaVersion: 1,
        snapshotId: 'snap-001',
        accountId: 'user-1',
        inputSource: InputSource.screenshot,
        analyzedAt: DateTime.utc(2026, 10, 14, 10, 0, 0),
        savedAt: DateTime.utc(2026, 10, 14, 10, 2, 0),
        hasAiAnalysis: false,
        findingsCount: 3,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        previewText: 'Payment required...',
      );

      final exportData = ExportDataExtractor.fromSummary(
        summary: summary,
        options: const ExportOptions(
          includeReviewedText: true,
        ), // Requested, but summary has no snapshot
      );

      expect(exportData.reportId, 'summary-001');
      expect(exportData.isCloudSummaryOnly, isTrue);
      expect(exportData.reviewedText, isNull); // Must remain null for summary
      expect(exportData.findings, isEmpty);
      expect(
        exportData.limitations.any(
          (l) => l.contains('high-level summary record'),
        ),
        isTrue,
      );
    });
  });
}
