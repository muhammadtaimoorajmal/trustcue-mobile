import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';

import 'package:trustcue_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launch and smoke test', (WidgetTester tester) async {
    // Launch the application using its main entry point
    app.main();

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that the title is visible
    expect(find.text('TrustCue'), findsOneWidget);

    // Verify the counter starts at zero
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Find the increment button and tap it
    final fabFinder = find.byIcon(Icons.add);
    expect(fabFinder, findsOneWidget);

    await tester.tap(fabFinder);

    // Wait for animations and state updates
    await tester.pumpAndSettle();

    // Verify the count has changed
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);

    // Tap again to confirm successive increments
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    final controller = Get.find<HomeController>();

    // Verify Home -> About -> Home flow
    final aboutFinder = find.byTooltip('About TrustCue');
    expect(aboutFinder, findsOneWidget);
    await tester.tap(aboutFinder);
    await tester.pumpAndSettle();

    expect(
      find.text('Understand the signals. Verify before you act.'),
      findsOneWidget,
    );

    final backFinder = find.byType(BackButton);
    expect(backFinder, findsOneWidget);
    await tester.tap(backFinder);
    await tester.pumpAndSettle();

    // Verify counter state is preserved
    expect(find.text('TrustCue'), findsWidgets);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(aboutFinder);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.home);
    expect(Get.find<HomeController>(), same(controller));
    expect(find.text('2'), findsOneWidget);

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
    expect(find.text('2'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
