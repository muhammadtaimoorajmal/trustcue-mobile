import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

import 'package:trustcue_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launch and smoke test', (WidgetTester tester) async {
    final preferences = SharedPreferencesAsync();
    const key = OnboardingPreferences.key;
    final previous = (await preferences.getAll(allowList: {key}))[key];
    addTearDown(() async {
      // Restore just this module's key, including an invalid existing type.
      switch (previous) {
        case null:
          await preferences.remove(key);
        case int value:
          await preferences.setInt(key, value);
        case bool value:
          await preferences.setBool(key, value);
        case double value:
          await preferences.setDouble(key, value);
        case String value:
          await preferences.setString(key, value);
        case List<String> value:
          await preferences.setStringList(key, value);
        default:
          throw StateError(
            'Unexpected preference type; do not clear other preferences.',
          );
      }
    });
    await preferences.setString(key, 'synthetic-invalid-version');
    expect(
      await LocalOnboardingPreferences().readVersion(),
      'synthetic-invalid-version',
    );
    await preferences.remove(key);
    // Launch the application using its main entry point
    app.main();

    // Wait for the app to settle
    await tester.pumpAndSettle();

    expect(find.text('Welcome to TrustCue'), findsOneWidget);
    expect(Get.isRegistered<HomeController>(), isFalse);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue to TrustCue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to TrustCue'));
    await tester.pumpAndSettle();
    expect(await LocalOnboardingPreferences().readVersion(), 1);
    expect(Get.key.currentState!.canPop(), isFalse);

    // Reconstruct startup with the real adapter. This is not a process restart.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    Get.reset();
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to TrustCue'), findsNothing);

    // Verify that the dashboard is visible
    expect(find.text('TrustCue'), findsOneWidget);
    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(find.text('Message text'), findsOneWidget);
    expect(find.text('Screenshot'), findsOneWidget);
    expect(find.text('Link or QR code'), findsOneWidget);

    final controller = Get.find<HomeController>();

    // Verify navigating to an input preparation screen and returning
    final viewInputFinder = find
        .widgetWithText(AppButton, 'View input options')
        .first;
    await tester.ensureVisible(viewInputFinder);
    await tester.pumpAndSettle();
    await tester.tap(viewInputFinder);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.inputText);
    expect(find.text('Message text'), findsWidgets);
    expect(find.text('Safety reminder'), findsOneWidget);

    // Return to Home via back button
    final backFinder = find.byType(BackButton);
    expect(backFinder, findsOneWidget);
    await tester.tap(backFinder);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.home);
    expect(Get.find<HomeController>(), same(controller));
    expect(find.text('Understand the signals.'), findsOneWidget);

    // Verify Home -> About -> Home flow
    final aboutFinder = find.byTooltip('About TrustCue');
    expect(aboutFinder, findsOneWidget);
    await tester.tap(aboutFinder);
    await tester.pumpAndSettle();

    expect(
      find.text('Understand the signals. Verify before you act.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Review safe-use guidance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review safe-use guidance'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.guidance);
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(backFinder);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.about);
    expect(await LocalOnboardingPreferences().readVersion(), 1);
    await tester.tap(backFinder);
    await tester.pumpAndSettle();

    // Verify Home dashboard is preserved
    expect(find.text('TrustCue'), findsWidgets);
    expect(find.text('Understand the signals.'), findsOneWidget);

    await tester.tap(aboutFinder);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.home);
    expect(Get.find<HomeController>(), same(controller));
    expect(find.text('Understand the signals.'), findsOneWidget);

    await tester.tap(aboutFinder);
    await tester.pumpAndSettle();
    final returned = expectLater(
      Get.toNamed('/about/does-not-exist'),
      completion(isNull),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page unavailable'), findsOneWidget);
    await tester.tap(find.text('Return to Home'));
    await tester.pumpAndSettle();
    await returned;
    expect(Get.currentRoute, AppRoutes.home);
    expect(Get.key.currentState!.canPop(), isFalse);
    expect(Get.find<HomeController>(), same(controller));
    expect(find.text('Understand the signals.'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
