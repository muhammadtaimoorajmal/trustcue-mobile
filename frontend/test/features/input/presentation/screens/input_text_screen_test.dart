import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_text_screen.dart';
import 'package:trustcue_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';

void main() {
  tearDown(() {
    Get.reset();
  });

  Widget buildTestApp({
    ThemeMode themeMode = ThemeMode.light,
    double textScaleFactor = 1.0,
  }) {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: AppRoutes.inputText,
      getPages: [
        GetPage(
          name: AppRoutes.home,
          page: () => const Scaffold(body: Text('Home Dashboard')),
        ),
        GetPage(
          name: AppRoutes.inputText,
          page: () => const InputTextScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut<InputTextController>(() => InputTextController());
          }),
        ),
        GetPage(
          name: AppRoutes.guidance,
          page: () => const OnboardingScreen(mode: OnboardingMode.review),
        ),
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        );
      },
    );
  }

  testWidgets('InputTextScreen renders all initial UI components', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Message text'), findsOneWidget);
    expect(
      find.text('Type or paste the message you want to review.'),
      findsOneWidget,
    );
    expect(
      find.text('For messages copied from SMS, email, or chat.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Text preparation is available. Scam analysis is not available in this build yet.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.text('0 / 10,000 characters'), findsOneWidget);
    expect(
      find.text(
        'Never include passwords, PINs, or one-time verification codes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Prepare text'), findsOneWidget);
    expect(find.text('Clear text'), findsOneWidget);
    expect(find.text('Safety reminder'), findsOneWidget);
    expect(find.text('Review safe-use guidance'), findsOneWidget);

    // Initial buttons disabled state
    final prepareButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Prepare text'),
    );
    final clearButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Clear text'),
    );
    expect(prepareButton.onPressed, isNull);
    expect(clearButton.onPressed, isNull);
  });

  testWidgets(
    'Typing into TextField updates character counter and enables buttons',
    (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Warning: update your PIN',
      );
      await tester.pumpAndSettle();

      expect(find.text('24 / 10,000 characters'), findsOneWidget);

      final prepareButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Prepare text'),
      );
      final clearButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Clear text'),
      );
      expect(prepareButton.onPressed, isNotNull);
      expect(clearButton.onPressed, isNotNull);
    },
  );

  testWidgets('Validation error is displayed inline when entering whitespace', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '     ');
    await tester.pumpAndSettle();

    // Prepare button is enabled because text is not empty
    final prepareFinder = find.widgetWithText(AppButton, 'Prepare text');
    await tester.ensureVisible(prepareFinder);
    await tester.tap(prepareFinder);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Message contains only blank or invisible characters. Please enter visible message text.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Text prepared on this device. It has not been analyzed or sent anywhere.',
      ),
      findsNothing,
    );
  });

  testWidgets(
    'Preparing valid text shows confirmation banner and editing dismisses it',
    (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Urgent: claim lottery prize now.',
      );
      await tester.pumpAndSettle();

      final prepareFinder = find.widgetWithText(AppButton, 'Prepare text');
      await tester.ensureVisible(prepareFinder);
      await tester.tap(prepareFinder);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Text prepared on this device. It has not been analyzed or sent anywhere.',
        ),
        findsOneWidget,
      );

      // Prepare button disabled because text is prepared and unchanged
      final prepareButtonAfter = tester.widget<AppButton>(prepareFinder);
      expect(prepareButtonAfter.onPressed, isNull);

      // Any edit clears confirmation banner and re-enables prepare button
      await tester.enterText(
        find.byType(TextField),
        'Urgent: claim lottery prize now. Contact 000.',
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Text prepared on this device. It has not been analyzed or sent anywhere.',
        ),
        findsNothing,
      );
      final prepareButtonReenabled = tester.widget<AppButton>(prepareFinder);
      expect(prepareButtonReenabled.onPressed, isNotNull);
    },
  );

  testWidgets('Clear text button prompts confirmation dialog and clears text', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Draft text to clear');
    await tester.pumpAndSettle();

    // Tap clear text
    final clearFinder = find.widgetWithText(AppButton, 'Clear text');
    await tester.ensureVisible(clearFinder);
    await tester.tap(clearFinder);
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Clear message?'), findsOneWidget);
    expect(
      find.text('This will remove the current message text from this screen.'),
      findsOneWidget,
    );

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Text remains intact
    expect(find.text('Draft text to clear'), findsOneWidget);

    // Tap clear text again
    await tester.ensureVisible(clearFinder);
    await tester.tap(clearFinder);
    await tester.pumpAndSettle();

    // Tap Clear
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    // Text is cleared and counter resets
    expect(find.text('0 / 10,000 characters'), findsOneWidget);
    final clearButton = tester.widget<AppButton>(clearFinder);
    expect(clearButton.onPressed, isNull);
  });

  testWidgets('AppBar back button without draft navigates back immediately', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Home Dashboard'), findsOneWidget);
    expect(find.text('Discard message?'), findsNothing);
  });

  testWidgets('AppBar back button with unsaved draft prompts discard dialog', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Unsaved message draft');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Discard message?'), findsOneWidget);
    expect(
      find.text(
        'You have unsaved message text. If you leave now, your draft will be discarded.',
      ),
      findsOneWidget,
    );

    // Tap "Keep editing"
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    // User is still on InputTextScreen with text intact
    expect(find.text('Unsaved message draft'), findsOneWidget);
    expect(find.text('Home Dashboard'), findsNothing);

    // Tap back button again and confirm Discard
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Home Dashboard'), findsOneWidget);
  });

  testWidgets(
    'Navigating to safe-use guidance preserves draft without discard dialog',
    (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Important saved draft');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Review safe-use guidance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review safe-use guidance'));
      await tester.pumpAndSettle();

      // On Guidance screen, no discard dialog shown
      expect(find.text('Discard message?'), findsNothing);
      expect(Get.currentRoute, AppRoutes.guidance);

      // Back from Guidance screen to InputTextScreen
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputText);
      expect(find.text('Important saved draft'), findsOneWidget);
    },
  );

  testWidgets('Operable at 200% text scale in dark theme', (tester) async {
    await tester.pumpWidget(
      buildTestApp(themeMode: ThemeMode.dark, textScaleFactor: 2.0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Message text'), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
