import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/export/data/services/pdf_export_builder.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';

void main() {
  group('PdfExportBuilder Tests', () {
    test('builds valid PDF binary document for standard report', () async {
      final data = ExportReportData(
        reportId: 'tc-pdf-001',
        analyzedAt: DateTime.utc(2026, 10, 15, 10, 0, 0),
        exportedAt: DateTime.utc(2026, 10, 17, 12, 0, 0),
        inputSource: InputSource.messageText,
        hasAiAnalysis: true,
        aiProvider: 'Groq',
        aiModel: 'llama-3.3-70b-versatile',
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        outcomeSummary: 'Analysis detected high-urgency scam indicators.',
        findings: const [
          ExportFindingItem(
            category: 'urgency',
            origin: FindingOrigin.localRule,
            producerId: 'rule.urgency',
            explanation: 'Immediate action demanded under threat.',
            evidenceQuotes: ['Act now or account locked!'],
          ),
        ],
        limitations: const [
          'Evaluates observable patterns only.',
          'Cannot verify sender identity.',
        ],
        suggestedActions: const [
          'Contact institution using official numbers.',
        ],
        reviewedText: 'Act now or account locked! Verify immediately.',
        isCloudSummaryOnly: false,
      );

      final bytes = await PdfExportBuilder.buildPdf(data);

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);

      // Verify PDF magic bytes '%PDF-'
      final header = latin1.decode(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('safely handles non-Latin / Urdu text and emojis without font crashes', () async {
      final data = ExportReportData(
        reportId: 'tc-pdf-urdu',
        analyzedAt: DateTime.utc(2026, 10, 15, 10, 0, 0),
        exportedAt: DateTime.utc(2026, 10, 17, 12, 0, 0),
        inputSource: InputSource.messageText,
        hasAiAnalysis: false,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        outcomeSummary: 'اردو ٹیکسٹ کے ساتھ ٹیسٹ۔ ⚠️',
        findings: const [
          ExportFindingItem(
            category: 'urgency',
            origin: FindingOrigin.localRule,
            producerId: 'rule.urgency',
            explanation: 'فوری کارروائی کی ڈیمانڈ۔',
            evidenceQuotes: ['فوری ادائیگی کریں'],
          ),
        ],
        limitations: const [
          'اردو میں محدود قواعد۔',
        ],
        suggestedActions: const [
          'تصدیق کریں۔',
        ],
        reviewedText: 'پیغام: آپ کی لاٹری نکل آئی ہے۔ 🎁',
      );

      // Must complete successfully without throwing font encoding exceptions
      final bytes = await PdfExportBuilder.buildPdf(data);

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(100));

      final header = latin1.decode(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('builds valid PDF when reviewed text is excluded for privacy', () async {
      final data = ExportReportData(
        reportId: 'tc-pdf-no-text',
        analyzedAt: DateTime.utc(2026, 10, 15, 10, 0, 0),
        exportedAt: DateTime.utc(2026, 10, 17, 12, 0, 0),
        inputSource: InputSource.link,
        hasAiAnalysis: false,
        outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
        outcomeSummary: 'No matching indicators.',
        findings: const [],
        limitations: const ['Scope disclaimer.'],
        suggestedActions: const [],
        reviewedText: null, // Excluded
      );

      final bytes = await PdfExportBuilder.buildPdf(data);
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}

