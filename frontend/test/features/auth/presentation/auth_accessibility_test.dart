import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/account_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/register_screen.dart';

import '../mocks/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fakeRepo;

  setUp(() {
    Get.testMode = true;
    fakeRepo = FakeAuthRepository();
    Get.put<AuthRepository>(fakeRepo);
  });

  tearDown(() {
    Get.reset();
  });

  Widget buildTestHost({
    required Widget child,
    required Brightness brightness,
    double textScale = 2.0,
  }) {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 640),
          textScaler: TextScaler.linear(textScale),
          platformBrightness: brightness,
        ),
        child: child,
      ),
    );
  }

  group('Auth Accessibility & Responsive Stress Tests', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'LoginScreen adapts cleanly to narrow 320px width and 200% text scale in $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          LoginBinding().dependencies();

          await tester.pumpWidget(
            buildTestHost(
              child: const LoginScreen(),
              brightness: brightness,
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Sign in'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'RegisterScreen adapts cleanly to narrow 320px width and 200% text scale in $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          RegisterBinding().dependencies();

          await tester.pumpWidget(
            buildTestHost(
              child: const RegisterScreen(),
              brightness: brightness,
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Create account'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'AccountScreen guest view adapts cleanly to narrow 320px width and 200% text scale in $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          AuthBinding().dependencies();

          await tester.pumpWidget(
            buildTestHost(
              child: const AccountScreen(),
              brightness: brightness,
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Guest Mode'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
