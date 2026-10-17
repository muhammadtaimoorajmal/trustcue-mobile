import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';

/// Formats [ExportReportData] into a clean, human-readable UTF-8 plain text report.
///
/// Features:
/// - 100% native UTF-8 encoding supporting all Unicode characters, Urdu, and symbols.
/// - Clear ASCII boundaries and structured headings.
/// - Distinct separation of Analysis Timestamp vs. Export Generation Timestamp.
/// - Honest, prominent limitations and safety disclaimers.
/// - Clear provenance indication for on-device heuristic vs. server-assisted AI findings.
/// - Explicit privacy notation when reviewed message text is excluded or included.
class PlainTextExportFormatter {
  static const String _separator =
      '================================================================================';
  static const String _subSeparator =
      '--------------------------------------------------------------------------------';

  /// Formats the provided [data] into a complete text report.
  static String format(ExportReportData data) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(_separator);
    buffer.writeln('                        TRUSTCUE SCAM ANALYSIS REPORT');
    buffer.writeln(_separator);
    buffer.writeln('Export Generated:     ${_formatTimestamp(data.exportedAt)}');
    buffer.writeln('Analysis Executed:    ${_formatTimestamp(data.analyzedAt)}');
    buffer.writeln('Report Identifier:    ${data.reportId}');
    buffer.writeln('Input Channel:        ${data.inputSource.name.toUpperCase()}');

    final provenanceStr = data.hasAiAnalysis
        ? 'On-Device Heuristics + AI-Assisted (${data.aiProvider ?? "Remote AI"} / ${data.aiModel ?? "Unknown Model"})'
        : 'On-Device Heuristic Rules';
    buffer.writeln('Analysis Provenance:  $provenanceStr');
    buffer.writeln('Assessment Outcome:   ${_formatOutcome(data.outcomeState)}');
    buffer.writeln(_separator);
    buffer.writeln();

    // Cloud summary notice if applicable
    if (data.isCloudSummaryOnly) {
      buffer.writeln('[NOTICE: Reconstructed from cloud summary metadata.');
      buffer.writeln(' Detailed message text and evidence quotes are not stored in cloud summaries.]');
      buffer.writeln();
    }

    // High level summary
    buffer.writeln('--- SUMMARY ---');
    buffer.writeln(data.outcomeSummary);
    buffer.writeln();

    // Detected indicators
    buffer.writeln('--- DETECTED INDICATORS (${data.findingCount}) ---');
    if (data.findings.isEmpty) {
      buffer.writeln('No matching scam indicator patterns were identified during evaluation.');
      buffer.writeln('Important: This does not guarantee that the message is authentic or safe.');
    } else {
      for (int i = 0; i < data.findings.length; i++) {
        final finding = data.findings[i];
        final index = i + 1;
        final originLabel = finding.origin == FindingOrigin.remoteAi
            ? 'Server-Assisted AI'
            : 'On-Device Heuristic Rule';

        buffer.writeln('[$index] ${finding.category}');
        buffer.writeln('    Provenance: $originLabel (producer: ${finding.producerId})');
        buffer.writeln('    Explanation: ${finding.explanation}');

        if (finding.evidenceQuotes.isNotEmpty) {
          buffer.writeln('    Evidence Excerpts:');
          for (final quote in finding.evidenceQuotes) {
            buffer.writeln('      * "$quote"');
          }
        }
        buffer.writeln();
      }
    }
    buffer.writeln();

    // Suggested actions
    if (data.suggestedActions.isNotEmpty) {
      buffer.writeln('--- SUGGESTED VERIFICATION STEPS ---');
      for (int i = 0; i < data.suggestedActions.length; i++) {
        buffer.writeln('${i + 1}. ${data.suggestedActions[i]}');
      }
      buffer.writeln();
    }

    // Limitations
    buffer.writeln('--- IMPORTANT LIMITATIONS & SCOPE DISCLOSURES ---');
    for (final limitation in data.limitations) {
      buffer.writeln('* $limitation');
    }
    buffer.writeln();

    // Reviewed message text (privacy controlled)
    buffer.writeln('--- REVIEWED MESSAGE CONTENT ---');
    if (data.hasReviewedText) {
      buffer.writeln('[User-authorized communication excerpt]');
      buffer.writeln(_subSeparator);
      buffer.writeln(data.reviewedText);
      buffer.writeln(_subSeparator);
    } else {
      buffer.writeln('[Reviewed message text excluded by user for privacy]');
    }
    buffer.writeln();

    // Footer
    buffer.writeln(_separator);
    buffer.writeln('                        END OF TRUSTCUE REPORT');
    buffer.writeln(_separator);

    return buffer.toString();
  }

  static String _formatTimestamp(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')} '
        '${utc.hour.toString().padLeft(2, '0')}:'
        '${utc.minute.toString().padLeft(2, '0')}:'
        '${utc.second.toString().padLeft(2, '0')} UTC';
  }

  static String _formatOutcome(AssessmentOutcomeState state) {
    switch (state) {
      case AssessmentOutcomeState.indicatorsDetected:
        return 'WARNING INDICATORS DETECTED';
      case AssessmentOutcomeState.noIndicatorsMatched:
        return 'NO MATCHING INDICATORS IDENTIFIED';
      case AssessmentOutcomeState.limitedCoverage:
        return 'LIMITED EVALUATION COVERAGE';
    }
  }
}

