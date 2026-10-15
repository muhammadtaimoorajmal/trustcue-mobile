import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';
import 'package:trustcue_mobile/features/home/presentation/screens/home_screen.dart';

import '../../../auth/mocks/fake_auth_repository.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<HomeController>(HomeController());
    Get.put<AuthRepository>(FakeAuthRepository());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'HomeScreen AppBar includes Account button with proper constraints and navigation',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.home,
          getPages: [
            GetPage(
              name: AppRoutes.home,
              page: () => const HomeScreen(title: 'TrustCue'),
            ),
            GetPage(
              name: AppRoutes.account,
              page: () => const Scaffold(body: Text('Account Destination')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final accountBtnFinder = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Account' &&
            widget.constraints?.minWidth == 48 &&
            widget.constraints?.minHeight == 48,
      );

      expect(accountBtnFinder, findsOneWidget);
      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);

      await tester.tap(accountBtnFinder);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, equals(AppRoutes.account));
      expect(find.text('Account Destination'), findsOneWidget);
    },
  );
}
