import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/analysis/presentation/screens/analysis_results_screen.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_format.dart';
import 'package:trustcue_mobile/features/export/presentation/controllers/export_controller.dart';
import 'package:trustcue_mobile/features/export/presentation/widgets/export_report_sheet.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';
import 'package:trustcue_mobile/features/reports/presentation/screens/history_screen.dart';
import 'package:trustcue_mobile/features/reports/presentation/screens/saved_report_detail_screen.dart';
import 'package:trustcue_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Module 43 Device Verification: Offline Reliability, Concurrency Guards, and Script Blocking',
    (WidgetTester tester) async {
      // 1. Mark onboarding completed so app lands directly on Home
      final preferences = SharedPreferencesAsync();
      await preferences.setInt(OnboardingPreferences.key, 1);

      app.main();
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.home);

      // =========================================================================
      // STEP 1: VERIFY OFFLINE TEXT INPUT, REVIEW, AND LOCAL ANALYSIS PIPELINE
      // =========================================================================
      final textCard = find.text('Message text');
      await tester.ensureVisible(textCard);
      await tester.pumpAndSettle();
      await tester.tap(textCard);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputText);

      // Enter Urdu scam message to test script fidelity and local detection
      final inputField = find.byType(AppTextField);
      expect(inputField, findsOneWidget);
      await tester.enterText(
        inputField,
        'فوری طور پر پاس ورڈ بھیجیں ورنہ اکاؤنٹ بلاک ہو جائے گا۔ Urgent verify now!',
      );
      await tester.pumpAndSettle();

      // Proceed to Review
      final reviewBtn = find.widgetWithText(AppButton, 'Review and continue');
      await tester.ensureVisible(reviewBtn);
      await tester.pumpAndSettle();
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputReview);

      // Run on-device analysis (operates offline without network)
      final checkBtn = find.widgetWithText(AppButton, 'Check this text');
      await tester.ensureVisible(checkBtn);
      await tester.pumpAndSettle();
      await tester.tap(checkBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.analysisResults);
      expect(find.byType(AnalysisResultsScreen), findsOneWidget);

      // =========================================================================
      // STEP 2: VERIFY PDF SCRIPT FIDELITY BLOCKING FOR URDU CONTENT
      // =========================================================================
      final exportAppBarBtn = find.byTooltip('Export or Share Report');
      expect(exportAppBarBtn, findsOneWidget);
      await tester.tap(exportAppBarBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ExportReportSheet), findsOneWidget);

      // Switch to PDF Document format
      await tester.tap(find.text('PDF Document (.pdf)'));
      await tester.pumpAndSettle();

      // Because text contains Urdu, PDF export must be blocked with explanatory notice
      expect(
        find.textContaining('unsupported non-Latin script'),
        findsOneWidget,
      );

      // Verify the 'Switch to Plain Text (.txt)' shortcut works
      final switchBtn = find.text('Switch to Plain Text (.txt) ->');
      expect(switchBtn, findsOneWidget);
      await tester.tap(switchBtn);
      await tester.pumpAndSettle();

      // Should be back to Plain Text format
      final exportCtrl = Get.find<ExportController>();
      expect(exportCtrl.options.value.format, ExportFormat.plainText);

      // Dismiss export sheet
      final closeBtn = find.byIcon(Icons.close);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // =========================================================================
      // STEP 3: CONCURRENCY GUARD & RESILIENT PERSISTENCE
      // =========================================================================
      final saveBtn = find.widgetWithText(AppButton, 'Save on this device');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Saved on this device'), findsOneWidget);

      // =========================================================================
      // STEP 4: OFFLINE LOCAL RETRIEVAL & DELETION LIFECYCLE
      // =========================================================================
      // Navigate to Home then History
      Get.offAllNamed(AppRoutes.home);
      await tester.pumpAndSettle();

      final historyBtn = find.byTooltip('Saved Reports');
      expect(historyBtn, findsOneWidget);
      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.history);
      expect(find.byType(HistoryScreen), findsOneWidget);

      // Open the saved report
      final reportItem = find.textContaining('فوری طور پر پاس ورڈ بھیجیں');
      expect(reportItem, findsOneWidget);
      await tester.tap(reportItem);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.historyDetail);
      expect(find.byType(SavedReportDetailScreen), findsOneWidget);

      // Delete the report from details
      final deleteBtn = find.byTooltip('Delete report from device');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      final confirmDeleteBtn = find.text('Delete from this device');
      expect(confirmDeleteBtn, findsOneWidget);
      await tester.tap(confirmDeleteBtn);
      await tester.pumpAndSettle();

      // Navigates back to History after deletion
      expect(Get.currentRoute, AppRoutes.history);
    },
  );
}
