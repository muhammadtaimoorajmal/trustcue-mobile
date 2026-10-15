import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/login_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/account_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/verify_email_screen.dart';

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

  Widget createWidgetUnderTest() {
    return GetMaterialApp(
      initialRoute: AppRoutes.authLogin,
      getPages: [
        GetPage(
          name: AppRoutes.authLogin,
          page: () => const LoginScreen(),
          binding: LoginBinding(),
        ),
        GetPage(
          name: AppRoutes.account,
          page: () => const AccountScreen(),
          binding: AuthBinding(),
        ),
        GetPage(
          name: AppRoutes.authVerifyEmail,
          page: () => const VerifyEmailScreen(),
          binding: VerifyEmailBinding(),
        ),
      ],
    );
  }

  group('LoginScreen & Flow', () {
    testWidgets('renders all fields, buttons, and navigation links', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Continue as guest'), findsOneWidget);
    });

    testWidgets('shows validation message on empty submission', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final signInButton = find.widgetWithText(FilledButton, 'Sign in');
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter both email and password.'),
        findsOneWidget,
      );
      expect(fakeRepo.signInCallCount, equals(0));
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final controller = Get.find<LoginController>();
      expect(controller.isPasswordVisible.value, isFalse);

      final visibilityIcon = find.byIcon(Icons.visibility_outlined);
      expect(visibilityIcon, findsOneWidget);

      await tester.tap(visibilityIcon);
      await tester.pumpAndSettle();

      expect(controller.isPasswordVisible.value, isTrue);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('displays error message when signIn fails', (tester) async {
      fakeRepo.nextSignInResult = AuthResult.failure(
        AuthFailure.invalidCredentials(),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'user@example.com');
      await tester.enterText(textFields.at(1), 'wrongpassword');

      final signInButton = find.widgetWithText(FilledButton, 'Sign in');
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(fakeRepo.signInCallCount, equals(1));
      expect(
        find.text('Invalid email or password. Please verify your details.'),
        findsOneWidget,
      );
    });

    testWidgets('navigates to verify-email when account is unconfirmed', (
      tester,
    ) async {
      fakeRepo.nextSignInResult = AuthResult.failure(
        AuthFailure.emailNotConfirmed(),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'unverified@example.com');
      await tester.enterText(textFields.at(1), 'password123');

      final signInButton = find.widgetWithText(FilledButton, 'Sign in');
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, equals(AppRoutes.authVerifyEmail));
    });

    testWidgets('navigates to account screen on successful sign in', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'valid@example.com');
      await tester.enterText(textFields.at(1), 'securePass123');

      final signInButton = find.widgetWithText(FilledButton, 'Sign in');
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(fakeRepo.signInCallCount, equals(1));
      expect(Get.currentRoute, equals(AppRoutes.account));
    });
  });
}
