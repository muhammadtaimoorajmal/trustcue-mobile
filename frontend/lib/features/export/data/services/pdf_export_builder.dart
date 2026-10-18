import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';

/// Exception thrown when report content contains scripts or characters that cannot
/// be faithfully rendered by the PDF typography engine without content loss.
class UnsupportedPdfScriptException implements Exception {
  final String message;
  const UnsupportedPdfScriptException(this.message);

  @override
  String toString() => message;
}

/// Service responsible for building clean, paginated PDF reports from [ExportReportData].
///
/// Principles & Guarantees:
/// - Generates standard PDF documents fully offline without network or cloud rendering.
/// - Dark-on-light theme optimized for printing and screen reading.
/// - Multi-page support with structured headers, footers, and page numbers.
/// - Faithful content fidelity: Never silently drops or replaces user text.
///   If a report contains non-Latin scripts (such as Urdu Nastaliq or emojis)
///   that standard PDF Type-1 fonts cannot faithfully shape and render, PDF export is
///   blocked with an understandable explanation, directing users to lossless Plain Text (.txt) export.
class PdfExportBuilder {
  static const String urduNotice =
      'Notice: PDF formatting requires standard Latin typography. '
      'For unredacted Urdu or non-Latin script fidelity, export using Plain Text (.txt).';

  /// Verifies whether all text sections in [data] can be rendered faithfully in PDF.
  static bool canRenderFaithfully(ExportReportData data) {
    return checkUnsupportedScript(data) == null;
  }

  /// Checks whether a single string contains any characters that cannot be faithfully rendered
  /// in Type-1 PDF fonts.
  static bool isStringSupported(String text) {
    for (final rune in text.runes) {
      if (rune <= 255) continue;
      // Allow common typographical punctuation with standard ASCII mappings
      switch (rune) {
        case 0x2018: // ‘
        case 0x2019: // ’
        case 0x201A: // ‚
        case 0x201C: // “
        case 0x201D: // ”
        case 0x201E: // „
        case 0x2013: // –
        case 0x2014: // —
        case 0x2022: // •
        case 0x2026: // …
          continue;
        default:
          return false;
      }
    }
    return true;
  }

  /// Returns a detailed explanation if [data] contains non-Latin scripts that would cause
  /// content loss in PDF, or null if the report can be rendered faithfully.
  static String? checkUnsupportedScript(ExportReportData data) {
    if (!isStringSupported(data.outcomeSummary)) {
      return 'PDF export is unavailable because the summary contains unsupported non-Latin script (such as Urdu or emojis). Please export as Plain Text (.txt) for full, complete, and unredacted fidelity.';
    }
    for (final finding in data.findings) {
      if (!isStringSupported(finding.category) ||
          !isStringSupported(finding.explanation)) {
        return 'PDF export is unavailable because finding descriptions contain unsupported non-Latin script (such as Urdu or emojis). Please export as Plain Text (.txt) for full, complete, and unredacted fidelity.';
      }
      for (final quote in finding.evidenceQuotes) {
        if (!isStringSupported(quote)) {
          return 'PDF export is unavailable because evidence quotes contain unsupported non-Latin script (such as Urdu or emojis). Please export as Plain Text (.txt) for full, complete, and unredacted fidelity.';
        }
      }
    }
    for (final action in data.suggestedActions) {
      if (!isStringSupported(action)) {
        return 'PDF export is unavailable because suggested actions contain unsupported non-Latin script (such as Urdu or emojis). Please export as Plain Text (.txt) for full, complete, and unredacted fidelity.';
      }
    }
    for (final limitation in data.limitations) {
      if (!isStringSupported(limitation)) {
        return 'PDF export is unavailable because disclosures contain unsupported non-Latin script (such as Urdu or emojis). Please export as Plain Text (.txt) for full, complete, and unredacted fidelity.';
      }
    }
    if (data.hasReviewedText && !isStringSupported(data.reviewedText!)) {
      return 'PDF export is unavailable because the reviewed message content contains unsupported non-Latin script (such as Urdu or emojis). Standard PDF typography cannot shape or render this script without losing content. Please export as Plain Text (.txt) for 100% complete, lossless fidelity.';
    }
    return null;
  }

  /// Builds a complete PDF document and returns the binary bytes.
  /// Throws [UnsupportedPdfScriptException] if [data] contains non-Latin scripts.
  static Future<Uint8List> buildPdf(ExportReportData data) async {
    final unsupportedReason = checkUnsupportedScript(data);
    if (unsupportedReason != null) {
      throw UnsupportedPdfScriptException(unsupportedReason);
    }
    final pdf = pw.Document(
      title: 'TrustCue Scam Analysis Report',
      author: 'TrustCue Mobile Security',
      creator: 'TrustCue (Offline Analysis Engine)',
    );

    final regularFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();
    final italicFont = pw.Font.helveticaOblique();

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      italic: italicFont,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        theme: theme,
        header: (context) => _buildHeader(data, context),
        footer: (context) => _buildFooter(data, context),
        build: (context) => [
          _buildMetadataCard(data),
          pw.SizedBox(height: 14),
          _buildSummarySection(data),
          pw.SizedBox(height: 14),
          _buildIndicatorsSection(data),
          pw.SizedBox(height: 14),
          _buildSuggestedActionsSection(data),
          pw.SizedBox(height: 14),
          _buildLimitationsSection(data),
          pw.SizedBox(height: 14),
          _buildReviewedContentSection(data),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(ExportReportData data, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TRUSTCUE SCAM ANALYSIS REPORT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.Text(
                'Automated On-Device Evidence & Threat Pattern Assessment',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.blueGrey600,
                ),
              ),
            ],
          ),
          pw.Text(
            _sanitizeForPdf(urduNotice),
            style: const pw.TextStyle(
              fontSize: 6.5,
              color: PdfColors.blueGrey500,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(ExportReportData data, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Confidential - Generated locally on device by TrustCue',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetadataCard(ExportReportData data) {
    final outcomeColor = _getOutcomePdfColor(data.outcomeState);
    final outcomeLabel = _getOutcomeLabel(data.outcomeState);

    final provenanceStr = data.hasAiAnalysis
        ? 'On-Device Heuristics + AI-Assisted (${data.aiProvider ?? "Remote AI"} / ${data.aiModel ?? "AI"})'
        : 'On-Device Deterministic Heuristic Rules';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Report ID: ${data.reportId}',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: outcomeColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Text(
                  outcomeLabel,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey300, height: 0.8),
          pw.SizedBox(height: 6),
          _buildMetaRow(
            'Export Date:',
            '${_formatTimestamp(data.exportedAt)} (Export generated)',
          ),
          _buildMetaRow(
            'Analysis Date:',
            '${_formatTimestamp(data.analyzedAt)} (Text evaluated)',
          ),
          _buildMetaRow('Input Channel:', data.inputSource.name.toUpperCase()),
          _buildMetaRow('Provenance:', provenanceStr),
          if (data.isCloudSummaryOnly)
            _buildMetaRow(
              'Record Source:',
              'Reconstructed from cloud summary metadata (original text not stored)',
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 85,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _sanitizeForPdf(value),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(ExportReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('EXECUTIVE SUMMARY'),
        pw.SizedBox(height: 4),
        pw.Text(
          _sanitizeForPdf(data.outcomeSummary),
          style: const pw.TextStyle(
            fontSize: 9.5,
            color: PdfColors.grey900,
            lineSpacing: 1.4,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildIndicatorsSection(ExportReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'DETECTED SCAM WARNING INDICATORS (${data.findingCount})',
        ),
        pw.SizedBox(height: 4),
        if (data.findings.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              'No matching scam indicator patterns were identified during this evaluation. '
              'Note: This does not prove that the communication is safe or legitimate.',
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.grey800,
              ),
            ),
          )
        else
          ...data.findings.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final finding = entry.value;
            final originLabel = finding.origin == FindingOrigin.remoteAi
                ? 'Server-Assisted AI'
                : 'On-Device Heuristic Rule';

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '#$index ${_sanitizeForPdf(finding.category)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.Text(
                        '$originLabel (${finding.producerId})',
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _sanitizeForPdf(finding.explanation),
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey800,
                      lineSpacing: 1.3,
                    ),
                  ),
                  if (finding.evidenceQuotes.isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Evidence Excerpts:',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    ...finding.evidenceQuotes.map(
                      (q) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 6, top: 2),
                        child: pw.Text(
                          '- "${_sanitizeForPdf(q)}"',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontStyle: pw.FontStyle.italic,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  static pw.Widget _buildSuggestedActionsSection(ExportReportData data) {
    if (data.suggestedActions.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('RECOMMENDED VERIFICATION STEPS'),
        pw.SizedBox(height: 4),
        ...data.suggestedActions.asMap().entries.map(
          (entry) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 16,
                  child: pw.Text(
                    '${entry.key + 1}.',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    _sanitizeForPdf(entry.value),
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildLimitationsSection(ExportReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('IMPORTANT LIMITATIONS & METHODOLOGY DISCLOSURES'),
        pw.SizedBox(height: 4),
        ...data.limitations.map(
          (limitation) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '- ',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    _sanitizeForPdf(limitation),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                      lineSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildReviewedContentSection(ExportReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('REVIEWED MESSAGE CONTENT'),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: data.hasReviewedText
              ? pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '[User-authorized communication excerpt]',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _sanitizeForPdf(data.reviewedText!),
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey900,
                        lineSpacing: 1.3,
                      ),
                    ),
                  ],
                )
              : pw.Text(
                  '[Reviewed message text excluded by user for privacy]',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey600,
                  ),
                ),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static PdfColor _getOutcomePdfColor(AssessmentOutcomeState state) {
    switch (state) {
      case AssessmentOutcomeState.indicatorsDetected:
        return PdfColors.amber800;
      case AssessmentOutcomeState.noIndicatorsMatched:
        return PdfColors.blue700;
      case AssessmentOutcomeState.limitedCoverage:
        return PdfColors.grey700;
    }
  }

  static String _getOutcomeLabel(AssessmentOutcomeState state) {
    switch (state) {
      case AssessmentOutcomeState.indicatorsDetected:
        return 'WARNING INDICATORS DETECTED';
      case AssessmentOutcomeState.noIndicatorsMatched:
        return 'NO MATCHING INDICATORS';
      case AssessmentOutcomeState.limitedCoverage:
        return 'LIMITED COVERAGE';
    }
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

  /// Maps common typographical punctuation to Latin-1/ASCII for PDF Type-1 font rendering.
  static String _sanitizeForPdf(String text) {
    final sb = StringBuffer();

    for (final rune in text.runes) {
      if (rune <= 255) {
        sb.writeCharCode(rune);
      } else {
        // Map common high-code-point typographical punctuation to ASCII
        switch (rune) {
          case 0x2018: // ‘
          case 0x2019: // ’
          case 0x201A: // ‚
            sb.write("'");
            break;
          case 0x201C: // “
          case 0x201D: // ”
          case 0x201E: // „
            sb.write('"');
            break;
          case 0x2013: // –
          case 0x2014: // —
            sb.write('-');
            break;
          case 0x2022: // •
            sb.write('*');
            break;
          case 0x2026: // …
            sb.write('...');
            break;
          default:
            throw UnsupportedPdfScriptException(
              'Encountered unrenderable character U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')} in PDF export. '
              'Standard PDF typography cannot faithfully render this character without data corruption. '
              'Please export as Plain Text (.txt) for 100% complete, lossless fidelity.',
            );
        }
      }
    }

    return sb.toString();
  }
}
