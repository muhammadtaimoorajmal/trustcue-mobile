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

  testWidgets('TrustCueApp renders title and counter increments', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TrustCueApp());
    await tester.pumpAndSettle();

    expect(find.text('TrustCue'), findsOneWidget);

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);

    // Verify ordinary rebuild doesn't reset counter
    await tester.pumpWidget(const TrustCueApp());
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Home route lifecycle and controller disposal', (
    WidgetTester tester,
  ) async {
    // Add a test-only route to test navigation away and back
    final testRoutes = [
      ...AppPages.pages,
      GetPage(
        name: '/test',
        page: () => const Scaffold(body: Text('Test Screen')),
      ),
    ];

    await tester.pumpWidget(
      GetMaterialApp(initialRoute: AppRoutes.home, getPages: testRoutes),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // Push another route, state should be preserved
    Get.toNamed('/test');
    await tester.pumpAndSettle();
    expect(find.text('Test Screen'), findsOneWidget);

    // Return to home, state should be preserved
    Get.back();
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    // Remove home route entirely
    Get.offAllNamed('/test');
    await tester.pumpAndSettle();
    expect(find.text('Test Screen'), findsOneWidget);

    // Verify controller was disposed
    expect(Get.isRegistered<HomeController>(), isFalse);

    // Re-enter home, state should be fresh
    Get.offAllNamed(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
  });
}
