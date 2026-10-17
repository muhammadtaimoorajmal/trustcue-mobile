import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/export/data/services/export_storage_service.dart';
import 'package:trustcue_mobile/features/export/data/services/share_launcher.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_format.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_options.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';
import 'package:trustcue_mobile/features/export/presentation/controllers/export_controller.dart';
import 'package:trustcue_mobile/features/export/presentation/widgets/export_report_sheet.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/localization/presentation/translations/app_translations.dart';

class MockStorageService implements ExportStorageService {
  @override
  Future<File> writePlainTextReport(
    String content, {
    DateTime? timestamp,
  }) async => File('dummy.txt');

  @override
  Future<File> writePdfReport(Uint8List bytes, {DateTime? timestamp}) async =>
      File('dummy.pdf');

  @override
  Future<int> pruneOldExports({
    Duration maxAge = const Duration(hours: 2),
  }) async => 0;

  @override
  Future<int> cleanupAllExports() async => 0;
}

class MockShareLauncher implements ShareLauncher {
  @override
  Future<ShareStatus> shareFile({
    required File file,
    required String mimeType,
    required String subject,
    required String text,
    Rect? sharePositionOrigin,
  }) async => ShareStatus.success;
}

void main() {
  setUp(() {
    Get.clearTranslations();
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('en', 'US');
  });

  group('ExportReportSheet Widget Tests', () {
    ExportReportData createTestData(ExportOptions options) {
      return ExportReportData(
        reportId: 'tc-sheet-test',
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        exportedAt: DateTime.utc(2026, 10, 17, 10, 0, 0),
        inputSource: InputSource.messageText,
        hasAiAnalysis: true,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        outcomeSummary: 'Sample outcome summary for testing.',
        findings: const [
          ExportFindingItem(
            category: 'urgency',
            origin: FindingOrigin.localRule,
            producerId: 'rule.urgency',
            explanation: 'Immediate action demanded.',
            evidenceQuotes: ['Act now!'],
          ),
          ExportFindingItem(
            category: 'paymentRequest',
            origin: FindingOrigin.remoteAi,
            producerId: 'groq.analysis',
            explanation: 'AI detected payment request.',
            evidenceQuotes: [],
          ),
        ],
        limitations: const ['Sample limitation.'],
        suggestedActions: const ['Sample action.'],
        reviewedText: 'Dear user, Act now!',
      );
    }

    testWidgets('renders all controls, default options, and preview', (
      tester,
    ) async {
      final controller = ExportController(
        dataFactory: createTestData,
        storageService: MockStorageService(),
        shareLauncher: MockShareLauncher(),
        hasSourceText: true,
        hasAiFindings: true,
        hasEvidenceQuotes: true,
      );
      controller.onInit();

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          home: Scaffold(body: ExportReportSheet(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and formats
      expect(find.text('Export & Share Report'), findsOneWidget);
      expect(find.text('Plain Text (.txt)'), findsOneWidget);
      expect(find.text('PDF Document (.pdf)'), findsOneWidget);

      // Check privacy checkboxes
      expect(find.text('Include reviewed message text'), findsOneWidget);
      expect(find.text('Include evidence quotes'), findsOneWidget);
      expect(find.text('Include AI explanations'), findsOneWidget);

      // Verify checkboxes are unchecked by default
      final textCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Include reviewed message text'),
      );
      expect(textCheckbox.value, isFalse);

      final evidenceCheckbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Include evidence quotes'),
      );
      expect(evidenceCheckbox.value, isFalse);

      // Check privacy warning banner
      expect(
        find.textContaining(
          'Warning: Exported reports may expose sensitive communication.',
        ),
        findsOneWidget,
      );

      // Check buttons
      expect(find.text('Share Report'), findsOneWidget);
      expect(find.text('Copy Text'), findsOneWidget);
    });

    testWidgets('switching format to PDF shows Urdu typography notice', (
      tester,
    ) async {
      final controller = ExportController(
        dataFactory: createTestData,
        storageService: MockStorageService(),
        shareLauncher: MockShareLauncher(),
        hasSourceText: true,
        hasAiFindings: true,
        hasEvidenceQuotes: true,
      );
      controller.onInit();

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          home: Scaffold(body: ExportReportSheet(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Notice should NOT be visible initially (when Plain Text is active)
      expect(find.textContaining('PDF uses Latin typography'), findsNothing);

      // Tap PDF format chip
      await tester.tap(find.text('PDF Document (.pdf)'));
      await tester.pumpAndSettle();

      // Notice should now be visible
      expect(find.textContaining('PDF uses Latin typography'), findsOneWidget);
      expect(controller.options.value.format, ExportFormat.pdf);

      // In PDF mode, Copy Text button should be hidden (since copying binary PDF text is not applicable)
      expect(find.text('Copy Text'), findsNothing);
    });

    testWidgets('toggling checkboxes updates controller options', (
      tester,
    ) async {
      final controller = ExportController(
        dataFactory: createTestData,
        storageService: MockStorageService(),
        shareLauncher: MockShareLauncher(),
        hasSourceText: true,
        hasAiFindings: true,
        hasEvidenceQuotes: true,
      );
      controller.onInit();

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          home: Scaffold(body: ExportReportSheet(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the reviewed text checkbox
      await tester.tap(find.text('Include reviewed message text'));
      await tester.pumpAndSettle();

      expect(controller.options.value.includeReviewedText, isTrue);

      // Tap the evidence quotes checkbox
      await tester.tap(find.text('Include evidence quotes'));
      await tester.pumpAndSettle();

      expect(controller.options.value.includeEvidenceQuotes, isTrue);
    });
  });
}
