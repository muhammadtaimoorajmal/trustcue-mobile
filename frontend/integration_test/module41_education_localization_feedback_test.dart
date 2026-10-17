import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/education/presentation/screens/education_screen.dart';
import 'package:trustcue_mobile/features/education/presentation/screens/education_topic_detail_screen.dart';
import 'package:trustcue_mobile/features/education/presentation/widgets/draft_replacement_dialog.dart';
import 'package:trustcue_mobile/features/feedback/data/repositories/sqlite_feedback_repository.dart';
import 'package:trustcue_mobile/features/feedback/presentation/widgets/feedback_dialog.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_text_screen.dart';
import 'package:trustcue_mobile/features/localization/domain/models/app_language.dart';
import 'package:trustcue_mobile/features/localization/presentation/controllers/localization_controller.dart';
import 'package:trustcue_mobile/features/localization/presentation/widgets/language_selector_dialog.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';
import 'package:trustcue_mobile/features/privacy/presentation/controllers/privacy_controller.dart';
import 'package:trustcue_mobile/features/privacy/presentation/screens/privacy_screen.dart';
import 'package:trustcue_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Module 41 & 40 Device Verification: Education, Practice, Feedback, Localization, Privacy',
    (WidgetTester tester) async {
      // 1. Mark onboarding completed so app lands directly on Home
      final preferences = SharedPreferencesAsync();
      await preferences.setInt(OnboardingPreferences.key, 1);

      app.main();
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.home);

      // Verify Home AppBar Education action exists
      final educationAppBarBtn = find.byTooltip('Scam Education');
      expect(educationAppBarBtn, findsOneWidget);

      // Verify Home Language action exists
      final languageAppBarBtn = find.byTooltip('Language');
      expect(languageAppBarBtn, findsOneWidget);

      // =========================================================================
      // STEP 1: EDUCATION CENTER BROWSING (OFFLINE)
      // =========================================================================
      await tester.tap(educationAppBarBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.education);
      expect(find.byType(EducationScreen), findsOneWidget);
      expect(find.text('Scam Education Center'), findsWidgets);

      // Verify search filtering works
      final searchField = find.widgetWithText(AppTextField, 'Search');
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Credentials');
      await tester.pumpAndSettle();

      expect(find.text('Requests for credentials'), findsOneWidget);
      expect(find.text('Urgency or artificial pressure'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(find.text('Urgency or artificial pressure'), findsOneWidget);

      // =========================================================================
      // STEP 2: TOPIC DETAIL SCREEN VERIFICATION
      // =========================================================================
      await tester.tap(find.text('Urgency or artificial pressure'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.educationTopic);
      expect(find.byType(EducationTopicDetailScreen), findsOneWidget);

      // Check essential educational sections
      expect(find.text('What pattern is observed'), findsOneWidget);
      expect(find.text('Why it deserves attention'), findsOneWidget);
      expect(find.text('What this check cannot establish'), findsOneWidget);
      expect(find.text('Synthetic practice example'), findsOneWidget);

      // Scroll to review contrasting example and verification steps
      final scrollable = find.byType(SingleChildScrollView).first;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Contrasting ordinary example'), findsOneWidget);
      expect(find.text('Why this differs from a scam'), findsOneWidget);

      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.text('Practical independent verification steps'),
        findsOneWidget,
      );
      expect(find.text('Official Reference Guidance'), findsOneWidget);
      expect(find.text('Was this topic helpful?'), findsOneWidget);

      // Scroll back up to practice section
      await tester.drag(scrollable, const Offset(0, 1000));
      await tester.pumpAndSettle();

      // =========================================================================
      // STEP 3: SAFE PRACTICE EXAMPLE (NO DRAFT -> POPULATE DIRECTLY)
      // =========================================================================
      final tryExampleBtn = find.text('Practice with this example');
      expect(tryExampleBtn, findsOneWidget);
      await tester.ensureVisible(tryExampleBtn);
      await tester.pumpAndSettle();

      await tester.tap(tryExampleBtn);
      await tester.pumpAndSettle();

      // Landed on InputTextScreen with example loaded
      expect(Get.currentRoute, AppRoutes.inputText);
      expect(find.byType(InputTextScreen), findsOneWidget);

      final inputController = Get.find<InputTextController>();
      expect(inputController.hasDraft, isTrue);
      expect(
        inputController.textEditingController.text,
        contains('URGENT: Your account access expires'),
      );

      // Verify analysis is NOT automatically started (user must explicitly initiate)
      expect(find.text('Prepare text'), findsOneWidget);

      // Navigate back to Topic Detail
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      if (find.text('Discard message?').evaluate().isNotEmpty) {
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
      }
      expect(Get.currentRoute, AppRoutes.educationTopic);

      // =========================================================================
      // STEP 4: SAFE PRACTICE EXAMPLE (ACTIVE DRAFT -> DRAFT REPLACEMENT GUARD)
      // =========================================================================
      final activeInputController = Get.put<InputTextController>(
        InputTextController(),
      );
      activeInputController.populateSharedText(
        'My active custom draft message',
      );

      await tester.ensureVisible(tryExampleBtn);
      await tester.pumpAndSettle();
      await tester.tap(tryExampleBtn);
      await tester.pumpAndSettle();

      // Draft replacement dialog displayed
      expect(find.byType(DraftReplacementDialog), findsOneWidget);
      expect(find.text('Replace current draft?'), findsOneWidget);

      // 4a. Cancel replacement -> draft kept
      await tester.tap(find.text('Keep Existing Draft'));
      await tester.pumpAndSettle();

      expect(find.byType(DraftReplacementDialog), findsNothing);
      expect(Get.currentRoute, AppRoutes.educationTopic);

      // 4b. Re-tap and confirm replacement
      await tester.ensureVisible(tryExampleBtn);
      await tester.pumpAndSettle();
      await tester.tap(tryExampleBtn);
      await tester.pumpAndSettle();
      expect(find.byType(DraftReplacementDialog), findsOneWidget);

      await tester.tap(find.text('Replace Draft'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputText);

      // Navigate back to Topic Detail
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      if (find.text('Discard message?').evaluate().isNotEmpty) {
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
      }
      expect(Get.currentRoute, AppRoutes.educationTopic);

      // =========================================================================
      // STEP 5: LOCAL ANONYMOUS FEEDBACK SUBMISSION
      // =========================================================================
      await tester.drag(scrollable, const Offset(0, -1200));
      await tester.pumpAndSettle();

      final feedbackBtn = find.text('Leave anonymous feedback');
      expect(feedbackBtn, findsOneWidget);
      await tester.ensureVisible(feedbackBtn);
      await tester.pumpAndSettle();

      await tester.tap(feedbackBtn);
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackDialog), findsOneWidget);
      expect(
        find.text(
          'TrustCue is an educational tool, not a law enforcement agency or reporting authority. Submitting feedback will NOT report a scam to authorities or protect against fraud.',
        ),
        findsOneWidget,
      );

      // Select rating
      await tester.tap(find.text('Helpful'));
      await tester.pumpAndSettle();

      // Select reason chip
      await tester.tap(find.text('Clear explanation'));
      await tester.pumpAndSettle();

      // Enter 200-char max comment
      final feedbackCommentField = find.widgetWithText(
        AppTextField,
        'Optional comment (max 200 chars)',
      );
      await tester.enterText(
        feedbackCommentField,
        'Very clear educational explanation of artificial urgency.',
      );
      await tester.pumpAndSettle();

      // Save feedback locally
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Confirm local save confirmation
      expect(
        find.text('Feedback saved locally on this device.'),
        findsOneWidget,
      );
      expect(
        find.text('Your feedback is stored anonymously on this device only.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackDialog), findsNothing);

      // Verify SQLite feedback table has stored the record
      final feedbackRepo = SqliteFeedbackRepository();
      final count = await feedbackRepo.getFeedbackCount();
      expect(count, greaterThanOrEqualTo(1));

      // Return to Education Screen, then Home Screen
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.education);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.home);

      // =========================================================================
      // STEP 6: LOCALIZATION & RTL/LTR DISCLOSURE VERIFICATION
      // =========================================================================
      await tester.tap(languageAppBarBtn);
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSelectorDialog), findsOneWidget);
      expect(
        find.textContaining('Changing the app language translates interface'),
        findsOneWidget,
      );

      // Switch to Urdu
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RadioListTile<AppLanguage> && w.value == AppLanguage.urdu,
        ),
      );
      await tester.pumpAndSettle();

      final locController = Get.find<LocalizationController>();
      expect(locController.currentLanguage.value, equals(AppLanguage.urdu));
      expect(locController.isRtl.value, isTrue);

      await tester.tap(find.widgetWithText(AppButton, 'close'.tr));
      await tester.pumpAndSettle();

      // Home Screen now reflects Urdu RTL interface
      expect(find.text('TrustCue'), findsWidgets); // App name preserved

      // Open Language Dialog in Urdu
      await tester.tap(find.byTooltip('Language'));
      await tester.pumpAndSettle();

      // Switch back to English
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is RadioListTile<AppLanguage> && w.value == AppLanguage.english,
        ),
      );
      await tester.pumpAndSettle();
      expect(locController.currentLanguage.value, equals(AppLanguage.english));
      expect(locController.isRtl.value, isFalse);

      await tester.tap(find.widgetWithText(AppButton, 'close'.tr));
      await tester.pumpAndSettle();

      // =========================================================================
      // STEP 7: MODULE 40 GAP CLOSURE (PRIVACY CENTER & RETENTION VERIFICATION)
      // =========================================================================
      await tester.tap(find.byTooltip('About TrustCue'));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.about);

      final privacyNavBtn = find.text('Privacy & Data Controls');
      await tester.ensureVisible(privacyNavBtn);
      await tester.pumpAndSettle();
      await tester.tap(privacyNavBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.privacy);
      expect(find.byType(PrivacyScreen), findsOneWidget);

      final privacyController = Get.find<PrivacyController>();
      await privacyController.loadStatus();
      await tester.pumpAndSettle();

      expect(privacyController.feedbackCount.value, greaterThanOrEqualTo(1));

      // Test Clear Local Feedback
      final clearFeedbackBtn = find.text('Clear Local Feedback');
      await tester.ensureVisible(clearFeedbackBtn);
      await tester.pumpAndSettle();
      await tester.tap(clearFeedbackBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(
        find.textContaining('delete all locally stored feedback records'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Clear All'));
      await tester.pumpAndSettle();

      expect(privacyController.feedbackCount.value, equals(0));

      // Return to Home
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.about);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.home);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
