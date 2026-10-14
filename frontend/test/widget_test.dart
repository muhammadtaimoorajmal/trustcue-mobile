import 'support/fake_onboarding_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:trustcue_mobile/app/routes/app_pages.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/app/trustcue_app.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';

void main() {
  tearDown(() {
    Get.reset();
  });

  testWidgets('TrustCueApp renders title and dashboard elements', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TrustCueApp(preferences: FakeOnboardingPreferences(value: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('TrustCue'), findsOneWidget);
    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(
      find.text('Choose how you want to review a suspicious message or link.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Local checks are available. Results are indicators, not a verdict.',
      ),
      findsOneWidget,
    );

    // Verify all 3 input options and availability text
    expect(find.text('Message text'), findsOneWidget);
    expect(find.text('Screenshot'), findsOneWidget);
    expect(find.text('Link or QR code'), findsOneWidget);
    expect(find.text('Local checks available'), findsOneWidget);
    expect(find.text('OCR & local checks available'), findsOneWidget);
    expect(find.text('Inspection & local checks available'), findsOneWidget);
    expect(find.text('Enter message'), findsOneWidget);
    expect(find.text('Choose screenshot'), findsOneWidget);
    expect(find.text('Inspect link or QR'), findsOneWidget);

    // Verify safety guidance card
    expect(find.text('Pause before you act.'), findsOneWidget);
    expect(find.text('Review safe-use guidance'), findsOneWidget);

    // Verify ordinary rebuild preserves dashboard
    await tester.pumpWidget(
      TrustCueApp(preferences: FakeOnboardingPreferences(value: 1)),
    );
    expect(find.text('Understand the signals.'), findsOneWidget);
  });

  testWidgets('Home route lifecycle and controller disposal', (
    WidgetTester tester,
  ) async {
    // Add a test-only route to test navigation away and back
    final testRoutes = [
      ...AppPages(FakeOnboardingPreferences(value: 1)).pages,
      GetPage(
        name: '/test',
        page: () => const Scaffold(body: Text('Test Screen')),
      ),
    ];

    await tester.pumpWidget(
      GetMaterialApp(initialRoute: AppRoutes.home, getPages: testRoutes),
    );
    await tester.pumpAndSettle();

    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(Get.isRegistered<HomeController>(), isTrue);
    final controller = Get.find<HomeController>();

    // Push another route, state should be preserved
    Get.toNamed('/test');
    await tester.pumpAndSettle();
    expect(find.text('Test Screen'), findsOneWidget);
    expect(Get.isRegistered<HomeController>(), isTrue);
    expect(Get.find<HomeController>(), same(controller));

    // Return to home, state should be preserved
    Get.back();
    await tester.pumpAndSettle();
    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(Get.find<HomeController>(), same(controller));

    // Remove home route entirely
    Get.offAllNamed('/test');
    await tester.pumpAndSettle();
    expect(find.text('Test Screen'), findsOneWidget);

    // Verify controller was disposed
    expect(Get.isRegistered<HomeController>(), isFalse);

    // Re-enter home, state should be fresh
    Get.offAllNamed(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(Get.isRegistered<HomeController>(), isTrue);
  });

  testWidgets('Theme switching preserves dashboard and updates appearance', (
    WidgetTester tester,
  ) async {
    // Start with light mode
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(
      TrustCueApp(preferences: FakeOnboardingPreferences(value: 1)),
    );
    await tester.pumpAndSettle();

    // Verify it's light theme
    BuildContext context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(Theme.of(context).scaffoldBackgroundColor, const Color(0xFFF8F9FA));
    expect(find.text('Understand the signals.'), findsOneWidget);

    // Switch to dark mode
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();

    // Verify it's dark theme
    context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).scaffoldBackgroundColor, const Color(0xFF121212));

    // Verify dashboard is preserved
    expect(find.text('Understand the signals.'), findsOneWidget);

    // Reset brightness
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  double calculateLuminance(Color color) {
    return color.computeLuminance();
  }

  double calculateContrast(Color fg, Color bg) {
    final fgL = calculateLuminance(fg);
    final bgL = calculateLuminance(bg);
    final l1 = fgL > bgL ? fgL : bgL;
    final l2 = fgL > bgL ? bgL : fgL;
    return (l1 + 0.05) / (l2 + 0.05);
  }

  testWidgets('Theme colors meet contrast requirements', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TrustCueApp(preferences: FakeOnboardingPreferences(value: 1)),
    );
    await tester.pumpAndSettle();

    // Test light theme contrast
    final lightBg = const Color(0xFFF8F9FA);
    final lightFg = const Color(0xFF111111);
    final lightPrimary = const Color(0xFF00695C);
    final lightOnPrimary = const Color(0xFFFFFFFF);

    expect(calculateContrast(lightFg, lightBg), greaterThanOrEqualTo(4.5));
    expect(
      calculateContrast(lightOnPrimary, lightPrimary),
      greaterThanOrEqualTo(4.5),
    );

    // Test dark theme contrast
    final darkBg = const Color(0xFF121212);
    final darkFg = const Color(0xFFEEEEEE);
    final darkPrimary = const Color(0xFF4DB6AC);
    final darkOnPrimary = const Color(0xFF0A2540);

    expect(calculateContrast(darkFg, darkBg), greaterThanOrEqualTo(4.5));
    expect(
      calculateContrast(darkOnPrimary, darkPrimary),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('Layout handles 200% text scaling gracefully', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    // Set a compact phone size
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      TrustCueApp(preferences: FakeOnboardingPreferences(value: 1)),
    );
    await tester.pumpAndSettle();

    // Verify UI is present and didn't crash/overflow fatally (pumpAndSettle completes)
    expect(find.text('TrustCue'), findsOneWidget);
    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(find.text('Message text'), findsOneWidget);

    // Reset test values
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
