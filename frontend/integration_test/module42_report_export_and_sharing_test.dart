import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/analysis/presentation/screens/analysis_results_screen.dart';
import 'package:trustcue_mobile/features/export/presentation/widgets/export_report_sheet.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';
import 'package:trustcue_mobile/features/reports/presentation/screens/history_screen.dart';
import 'package:trustcue_mobile/features/reports/presentation/screens/saved_report_detail_screen.dart';
import 'package:trustcue_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Module 42 Device Verification: Report Export and Sharing Flow',
    (WidgetTester tester) async {
      // 1. Mark onboarding completed so app lands directly on Home
      final preferences = SharedPreferencesAsync();
      await preferences.setInt(OnboardingPreferences.key, 1);

      app.main();
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.home);

      // =========================================================================
      // STEP 1: CREATE SUSPICIOUS TEXT & RUN LOCAL ANALYSIS
      // =========================================================================
      // Tap Message Text card
      final textCard = find.text('Message text');
      await tester.ensureVisible(textCard);
      await tester.pumpAndSettle();
      await tester.tap(textCard);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputText);

      // Enter suspicious message text
      final inputField = find.byType(AppTextField);
      expect(inputField, findsOneWidget);
      await tester.enterText(
        inputField,
        'Urgent: Your account is suspended. Send \$500 immediately to verify!',
      );
      await tester.pumpAndSettle();

      // Tap Review and continue
      final reviewBtn = find.widgetWithText(AppButton, 'Review and continue');
      await tester.ensureVisible(reviewBtn);
      await tester.pumpAndSettle();
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputReview);

      // Tap Check this text
      final checkBtn = find.widgetWithText(AppButton, 'Check this text');
      await tester.ensureVisible(checkBtn);
      await tester.pumpAndSettle();
      await tester.tap(checkBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.analysisResults);
      expect(find.byType(AnalysisResultsScreen), findsOneWidget);

      // =========================================================================
      // STEP 2: OPEN EXPORT SHEET FROM ANALYSIS RESULTS
      // =========================================================================
      // Find export action in AppBar
      final exportAppBarBtn = find.byTooltip('Export or Share Report');
      expect(exportAppBarBtn, findsOneWidget);

      await tester.tap(exportAppBarBtn);
      await tester.pumpAndSettle();

      // Verify ExportReportSheet modal appeared
      expect(find.byType(ExportReportSheet), findsOneWidget);
      expect(find.text('Export & Share Report'), findsOneWidget);
      expect(find.text('Plain Text (.txt)'), findsOneWidget);
      expect(find.text('PDF Document (.pdf)'), findsOneWidget);

      // Verify strict privacy defaults: Checkboxes are unchecked
      final textCheckboxFinder = find.widgetWithText(
        CheckboxListTile,
        'Include reviewed message text',
      );
      expect(textCheckboxFinder, findsOneWidget);
      final textCheckbox = tester.widget<CheckboxListTile>(textCheckboxFinder);
      expect(textCheckbox.value, isFalse);

      final quotesCheckboxFinder = find.widgetWithText(
        CheckboxListTile,
        'Include evidence quotes',
      );
      expect(quotesCheckboxFinder, findsOneWidget);
      final quotesCheckbox = tester.widget<CheckboxListTile>(quotesCheckboxFinder);
      expect(quotesCheckbox.value, isFalse);

      // Verify privacy notice in preview
      expect(
        find.textContaining('[Reviewed message text excluded by user for privacy]'),
        findsOneWidget,
      );

      // =========================================================================
      // STEP 3: SWITCH TO PDF FORMAT & VERIFY URDU/LATIN NOTICE
      // =========================================================================
      await tester.tap(find.text('PDF Document (.pdf)'));
      await tester.pumpAndSettle();

      // Urdu typography notice must be visible
      expect(find.textContaining('PDF uses Latin typography'), findsOneWidget);

      // =========================================================================
      // STEP 4: TOGGLE PRIVACY INCLUSIONS & VERIFY PREVIEW
      // =========================================================================
      // Switch back to Plain Text
      await tester.tap(find.text('Plain Text (.txt)'));
      await tester.pumpAndSettle();

      // Check reviewed message text
      await tester.tap(textCheckboxFinder);
      await tester.pumpAndSettle();

      // Check evidence quotes
      await tester.tap(quotesCheckboxFinder);
      await tester.pumpAndSettle();

      // Verify preview updated with message text
      expect(
        find.textContaining('Urgent: Your account is suspended.'),
        findsOneWidget,
      );

      // Verify Copy Text button works
      final copyBtn = find.widgetWithText(AppButton, 'Copy Text');
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      expect(find.text('Report copied to clipboard'), findsOneWidget);

      // Close the export bottom sheet
      final closeBtn = find.byIcon(Icons.close);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ExportReportSheet), findsNothing);

      // =========================================================================
      // STEP 5: SAVE REPORT LOCALLY & EXPORT FROM SAVED REPORT DETAILS
      // =========================================================================
      final saveBtn = find.widgetWithText(AppButton, 'Save on this device');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Saved on this device'), findsOneWidget);

      // Navigate to Home
      Get.offAllNamed(AppRoutes.home);
      await tester.pumpAndSettle();

      // Navigate to History
      final historyBtn = find.byTooltip('Saved Reports');
      expect(historyBtn, findsOneWidget);
      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.history);
      expect(find.byType(HistoryScreen), findsOneWidget);

      // Tap the saved report card to view details
      final reportCard = find.textContaining('Urgent: Your account is suspended');
      expect(reportCard, findsOneWidget);
      await tester.tap(reportCard);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.historyDetail);
      expect(find.byType(SavedReportDetailScreen), findsOneWidget);

      // Verify Export action in Saved Report Details AppBar
      final detailExportBtn = find.byTooltip('Export or Share Report');
      expect(detailExportBtn, findsOneWidget);

      await tester.tap(detailExportBtn);
      await tester.pumpAndSettle();

      // Verify ExportReportSheet appears from saved report detail
      expect(find.byType(ExportReportSheet), findsOneWidget);
      expect(find.text('Export & Share Report'), findsOneWidget);

      // Dismiss export sheet
      final closeDetailExport = find.byIcon(Icons.close);
      await tester.tap(closeDetailExport);
      await tester.pumpAndSettle();

      expect(find.byType(ExportReportSheet), findsNothing);
    },
  );
}
