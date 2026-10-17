import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/export/data/services/plain_text_export_formatter.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';

void main() {
  group('PlainTextExportFormatter Tests', () {
    test('formats complete plain text report with accurate timestamps and boundaries', () {
      final data = ExportReportData(
        reportId: 'tc-rep-8899',
        analyzedAt: DateTime.utc(2026, 10, 15, 14, 30, 0),
        exportedAt: DateTime.utc(2026, 10, 17, 9, 15, 0),
        inputSource: InputSource.messageText,
        hasAiAnalysis: true,
        aiProvider: 'Groq',
        aiModel: 'llama-3.3-70b-versatile',
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        outcomeSummary: 'Analysis detected 2 warning indicators.',
        findings: const [
          ExportFindingItem(
            category: 'urgency',
            origin: FindingOrigin.localRule,
            producerId: 'urgency_rule',
            explanation: 'Immediate action demanded.',
            evidenceQuotes: ['Act now or account closed!'],
          ),
          ExportFindingItem(
            category: 'paymentRequest',
            origin: FindingOrigin.remoteAi,
            producerId: 'groq.provider',
            explanation: 'Unusual gift card payment method.',
            evidenceQuotes: ['Buy \$200 Google Play cards'],
          ),
        ],
        limitations: const [
          'Evaluates observable patterns only.',
          'Cannot verify sender identity.',
        ],
        suggestedActions: const [
          'Do not send gift cards.',
          'Verify using official website.',
        ],
        reviewedText: 'Dear customer, Act now or account closed! Buy \$200 Google Play cards.',
        isCloudSummaryOnly: false,
      );

      final output = PlainTextExportFormatter.format(data);

      expect(output, contains('TRUSTCUE SCAM ANALYSIS REPORT'));
      expect(output, contains('Export Generated:     2026-10-17 09:15:00 UTC'));
      expect(output, contains('Analysis Executed:    2026-10-15 14:30:00 UTC'));
      expect(output, contains('Report Identifier:    tc-rep-8899'));
      expect(output, contains('Input Channel:        MESSAGETEXT'));
      expect(output, contains('Analysis Provenance:  On-Device Heuristics + AI-Assisted (Groq / llama-3.3-70b-versatile)'));
      expect(output, contains('Assessment Outcome:   WARNING INDICATORS DETECTED'));
      expect(output, contains('--- SUMMARY ---'));
      expect(output, contains('Analysis detected 2 warning indicators.'));
      expect(output, contains('--- DETECTED INDICATORS (2) ---'));
      expect(output, contains('[1] urgency'));
      expect(output, contains('    Provenance: On-Device Heuristic Rule (producer: urgency_rule)'));
      expect(output, contains('      * "Act now or account closed!"'));
      expect(output, contains('[2] paymentRequest'));
      expect(output, contains('    Provenance: Server-Assisted AI (producer: groq.provider)'));
      expect(output, contains('      * "Buy \$200 Google Play cards"'));
      expect(output, contains('--- SUGGESTED VERIFICATION STEPS ---'));
      expect(output, contains('1. Do not send gift cards.'));
      expect(output, contains('2. Verify using official website.'));
      expect(output, contains('--- IMPORTANT LIMITATIONS & SCOPE DISCLOSURES ---'));
      expect(output, contains('* Evaluates observable patterns only.'));
      expect(output, contains('--- REVIEWED MESSAGE CONTENT ---'));
      expect(output, contains('[User-authorized communication excerpt]'));
      expect(output, contains('Dear customer, Act now or account closed!'));
      expect(output, contains('END OF TRUSTCUE REPORT'));
    });

    test('preserves full UTF-8 fidelity for Urdu text and emojis', () {
      final data = ExportReportData(
        reportId: 'tc-urdu-01',
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        exportedAt: DateTime.utc(2026, 10, 17, 10, 0, 0),
        inputSource: InputSource.messageText,
        hasAiAnalysis: false,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        outcomeSummary: 'مشتبہ اشارہ شناخت ہوا۔',
        findings: const [
          ExportFindingItem(
            category: 'urgency',
            origin: FindingOrigin.localRule,
            producerId: 'urgency_rule',
            explanation: 'فوری کارروائی کا دباؤ۔',
            evidenceQuotes: ['فوری رابطہ کریں'],
          ),
        ],
        limitations: const [
          'یہ جانچ شناخت کی تصدیق نہیں کر سکتی۔',
        ],
        suggestedActions: const [
          'بینک سے براہ راست رابطہ کریں۔',
        ],
        reviewedText: 'محترم صارف، آپ کا اکاؤنٹ معطل ہو گیا ہے۔ ⚠️ فوری رابطہ کریں۔',
      );

      final output = PlainTextExportFormatter.format(data);

      expect(output, contains('محترم صارف، آپ کا اکاؤنٹ معطل ہو گیا ہے۔ ⚠️ فوری رابطہ کریں۔'));
      expect(output, contains('فوری کارروائی کا دباؤ۔'));
      expect(output, contains('بینک سے براہ راست رابطہ کریں۔'));
    });

    test('replaces reviewed text with privacy notice when excluded', () {
      final data = ExportReportData(
        reportId: 'tc-rep-privacy',
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        exportedAt: DateTime.utc(2026, 10, 17, 10, 0, 0),
        inputSource: InputSource.messageText,
        hasAiAnalysis: false,
        outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
        outcomeSummary: 'No indicators matched.',
        findings: const [],
        limitations: const ['Honest limitation notice.'],
        suggestedActions: const [],
        reviewedText: null, // Excluded for privacy
      );

      final output = PlainTextExportFormatter.format(data);

      expect(output, contains('[Reviewed message text excluded by user for privacy]'));
      expect(output, contains('No matching scam indicator patterns were identified'));
    });

    test('displays cloud summary notice when isCloudSummaryOnly is true', () {
      final data = ExportReportData(
        reportId: 'tc-cloud-summary',
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        exportedAt: DateTime.utc(2026, 10, 17, 10, 0, 0),
        inputSource: InputSource.link,
        hasAiAnalysis: false,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        outcomeSummary: 'Cloud summary item.',
        findings: const [],
        limitations: const ['Reconstructed from cloud summary.'],
        suggestedActions: const [],
        reviewedText: null,
        isCloudSummaryOnly: true,
      );

      final output = PlainTextExportFormatter.format(data);

      expect(output, contains('[NOTICE: Reconstructed from cloud summary metadata.'));
    });
  });
}

