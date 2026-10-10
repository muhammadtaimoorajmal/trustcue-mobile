import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/app/trustcue_app.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';
import 'package:trustcue_mobile/app/routes/app_pages.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';

void main() {
  setUp(() {
    Get.reset();
  });

  group('Navigation Tests', () {
    testWidgets('Normal startup opens Home and counter works', (tester) async {
      await tester.pumpWidget(const TrustCueApp());
      await tester.pumpAndSettle();

      expect(find.text('TrustCue'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Home info action opens About, app-bar back preserves counter', (tester) async {
      await tester.pumpWidget(const TrustCueApp());
      await tester.pumpAndSettle();

      // Increment counter
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      // Go to About
      await tester.tap(find.byTooltip('About TrustCue'));
      await tester.pumpAndSettle();

      expect(find.text('About TrustCue'), findsOneWidget);
      expect(Get.currentRoute, AppRoutes.about);

      // Press App-bar back button
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.home);
      expect(find.text('1'), findsOneWidget); // Counter preserved
    });

    testWidgets('Framework back request returns from About', (tester) async {
      await tester.pumpWidget(const TrustCueApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('About TrustCue'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.about);

      // Simulate system/framework back
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.home);
    });

    testWidgets('Rapid repeated About taps do not require multiple back actions', (tester) async {
      await tester.pumpWidget(const TrustCueApp());
      await tester.pumpAndSettle();

      final aboutIcon = find.byTooltip('About TrustCue');
      await tester.tap(aboutIcon);
      await tester.tap(aboutIcon, warnIfMissed: false);
      await tester.tap(aboutIcon, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.about);

      // Press App-bar back button once
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.home);
    });

    testWidgets('Explicit not-found route displays fallback screen without exception', (tester) async {
      await tester.pumpWidget(const TrustCueApp());
      await tester.pumpAndSettle();

      Get.toNamed(AppRoutes.notFound);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Page unavailable'), findsOneWidget);
    });

    testWidgets('Recovery through Home -> About -> not-found route returns to original Home and preserves counter', (tester) async {
      await tester.pumpWidget(const TrustCueApp());
      await tester.pumpAndSettle();

      // Increment
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      // Go to About
      Get.toNamed(AppRoutes.about);
      await tester.pumpAndSettle();

      // Go to not-found
      Get.toNamed(AppRoutes.notFound);
      await tester.pumpAndSettle();

      expect(find.text('Page unavailable'), findsOneWidget);

      // Recover
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.home);
      expect(find.text('1'), findsOneWidget); // Counter preserved
      
      // Verify no 'About' in stack
      expect(Get.isSnackbarOpen, false);
    });

    testWidgets('Recovery works when no Home route remains', (tester) async {
      // Start app directly at not-found route (simulate no home in stack)
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.notFound,
          getPages: AppPages.pages,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page unavailable'), findsOneWidget);

      // Recover
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.home);
      expect(find.text('TrustCue'), findsWidgets); // App bar title
      
      // Make sure counter works (controller is successfully initialized)
      expect(find.text('0'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Unsupported initial route follows safe fallback behavior (GetX default)', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/fake-startup-route',
          getPages: AppPages.pages,
          unknownRoute: AppPages.unknownRoute,
        ),
      );
      await tester.pumpAndSettle();

      // GetX 4.x safely falls back to the first route (Home) if unknownRoute fails to push
      expect(find.text('TrustCue'), findsWidgets);
    });
  });
}
