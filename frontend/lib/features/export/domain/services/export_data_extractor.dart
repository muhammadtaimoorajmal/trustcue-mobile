import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_options.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

/// Pure-Dart service that extracts and transforms domain reports into
/// sanitized, privacy-bounded [ExportReportData].
class ExportDataExtractor {
  static const String canonicalDisclaimer =
      'TrustCue analysis evaluates observable patterns against known scam indicators. '
      'It cannot guarantee safety, determine absolute truth, or verify the authentic identity of the sender.';

  /// Extracts export data from a fully realized [SavedReport].
  static ExportReportData fromSavedReport({
    required SavedReport report,
    required ExportOptions options,
    DateTime? exportedAt,
  }) {
    final now = exportedAt ?? DateTime.now();

    final allFindings = <ExportFindingItem>[];

    // Local findings
    for (final finding in report.localReport.findings) {
      allFindings.add(_mapFinding(finding, options));
    }

    // AI findings (included only if options.includeAiExplanations is true)
    if (report.hasAiAnalysis && options.includeAiExplanations) {
      for (final finding in report.aiReport!.findings) {
        allFindings.add(_mapFinding(finding, options));
      }
    }

    final limitations = <String>{
      ...report.localReport.limitations,
      if (report.aiReport != null && options.includeAiExplanations)
        ...report.aiReport!.uncertaintyNotes,
      canonicalDisclaimer,
    }.toList();

    final suggestedActions = <String>{
      ...report.localReport.suggestedActions,
      if (report.aiReport != null)
        ...report.aiReport!.suggestedActions.map((a) => a.title),
    }.toList();

    final outcomeState = report.localReport.findings.isNotEmpty
        ? AssessmentOutcomeState.indicatorsDetected
        : AssessmentOutcomeState.noIndicatorsMatched;

    final outcomeSummary =
        outcomeState == AssessmentOutcomeState.indicatorsDetected
        ? 'Analysis identified ${report.totalFindingsCount} potential scam warning indicator(s).'
        : 'Analysis did not identify matching scam patterns among evaluated checks.';

    return ExportReportData(
      reportId: report.id,
      analyzedAt: report.analyzedAt,
      exportedAt: now,
      inputSource: report.inputSource,
      hasAiAnalysis: report.hasAiAnalysis,
      aiProvider: report.aiReport?.provider,
      aiModel: report.aiReport?.model,
      outcomeState: outcomeState,
      outcomeSummary: outcomeSummary,
      findings: allFindings,
      limitations: limitations,
      suggestedActions: suggestedActions,
      reviewedText: options.includeReviewedText ? report.snapshot.text : null,
      isCloudSummaryOnly: false,
    );
  }

  /// Extracts export data from an active in-memory [LocalAssessment]
  /// and optional [AiAnalysisReport].
  static ExportReportData fromAssessment({
    required LocalAssessment assessment,
    required TextSnapshot snapshot,
    AiAnalysisReport? aiReport,
    required ExportOptions options,
    DateTime? exportedAt,
  }) {
    final now = exportedAt ?? DateTime.now();

    final allFindings = <ExportFindingItem>[];

    // Local findings from assessment groups
    for (final group in assessment.groupedIndicators) {
      for (final finding in group.findings) {
        allFindings.add(_mapFinding(finding, options));
      }
    }

    // AI findings if present and opted-in
    if (aiReport != null && options.includeAiExplanations) {
      for (final finding in aiReport.findings) {
        allFindings.add(_mapFinding(finding, options));
      }
    }

    final limitations = <String>{
      assessment.coverageInfo.coverageDescription,
      ...assessment.uncertaintyNotes,
      if (aiReport != null && options.includeAiExplanations)
        ...aiReport.uncertaintyNotes,
      canonicalDisclaimer,
    }.toList();

    final suggestedActions = <String>{
      ...assessment.actionableSteps.map((a) => a.title),
      if (aiReport != null) ...aiReport.suggestedActions.map((a) => a.title),
    }.toList();

    return ExportReportData(
      reportId: assessment.reportId,
      analyzedAt: assessment.createdAt,
      exportedAt: now,
      inputSource: snapshot.source,
      hasAiAnalysis: aiReport != null,
      aiProvider: aiReport?.provider,
      aiModel: aiReport?.model,
      outcomeState: assessment.outcomeState,
      outcomeSummary: assessment.factualSummary,
      findings: allFindings,
      limitations: limitations,
      suggestedActions: suggestedActions,
      reviewedText: options.includeReviewedText ? snapshot.text : null,
      isCloudSummaryOnly: false,
    );
  }

  /// Extracts export data from a high-level [SavedReportSummary].
  ///
  /// Guarantees:
  /// - Acknowledges that detailed text snapshot and individual findings
  ///   are not stored in summary records.
  /// - Sets [isCloudSummaryOnly] to true.
  /// - Excludes reviewed text and evidence quotations entirely.
  static ExportReportData fromSummary({
    required SavedReportSummary summary,
    required ExportOptions options,
    DateTime? exportedAt,
  }) {
    final now = exportedAt ?? DateTime.now();

    final limitations = [
      'This export was generated from a high-level summary record. '
          'Detailed message text and individual evidence quotes are not available.',
      canonicalDisclaimer,
    ];

    final outcomeSummary =
        summary.outcomeState == AssessmentOutcomeState.indicatorsDetected
        ? 'Summary record: ${summary.findingsCount} indicator pattern(s) previously detected.'
        : 'Summary record: No indicator patterns matched during prior evaluation.';

    return ExportReportData(
      reportId: summary.id,
      analyzedAt: summary.analyzedAt,
      exportedAt: now,
      inputSource: summary.inputSource,
      hasAiAnalysis: summary.hasAiAnalysis,
      aiProvider: summary.aiProvider,
      aiModel: summary.aiModel,
      outcomeState: summary.outcomeState,
      outcomeSummary: outcomeSummary,
      findings: const [],
      limitations: limitations,
      suggestedActions: const [
        'Review original messages independently using official, verified contact channels.',
      ],
      reviewedText: null, // Never available in summary
      isCloudSummaryOnly: true,
    );
  }

  static ExportFindingItem _mapFinding(
    AnalysisFinding finding,
    ExportOptions options,
  ) {
    final quotes = options.includeEvidenceQuotes
        ? finding.evidence.map((e) => e.exactExcerpt).toList()
        : const <String>[];

    return ExportFindingItem(
      category: finding.category,
      origin: finding.origin,
      producerId: finding.producerId,
      explanation: finding.explanation,
      evidenceQuotes: quotes,
    );
  }
}
