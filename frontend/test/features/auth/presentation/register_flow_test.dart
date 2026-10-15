import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/account_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/register_screen.dart';
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
      initialRoute: AppRoutes.authRegister,
      getPages: [
        GetPage(
          name: AppRoutes.authRegister,
          page: () => const RegisterScreen(),
          binding: RegisterBinding(),
        ),
        GetPage(
          name: AppRoutes.authVerifyEmail,
          page: () => const VerifyEmailScreen(),
          binding: VerifyEmailBinding(),
        ),
        GetPage(
          name: AppRoutes.account,
          page: () => const AccountScreen(),
          binding: AuthBinding(),
        ),
      ],
    );
  }

  group('RegisterScreen & Flow', () {
    testWidgets('renders all registration fields and links', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Create account'), findsWidgets);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Continue as guest'), findsOneWidget);
    });

    testWidgets('validates invalid email', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'invalidemail');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');

      final submitBtn = find.widgetWithText(FilledButton, 'Create account');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(fakeRepo.signUpCallCount, equals(0));
    });

    testWidgets('validates password length under 6 characters', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'user@example.com');
      await tester.enterText(textFields.at(1), '12345');
      await tester.enterText(textFields.at(2), '12345');

      final submitBtn = find.widgetWithText(FilledButton, 'Create account');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
      expect(fakeRepo.signUpCallCount, equals(0));
    });

    testWidgets('validates password mismatch', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'user@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'passwordXYZ');

      final submitBtn = find.widgetWithText(FilledButton, 'Create account');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(fakeRepo.signUpCallCount, equals(0));
    });

    testWidgets(
      'navigates to verify-email on successful signup with unverified email',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'newuser@example.com');
        await tester.enterText(textFields.at(1), 'securePassword123');
        await tester.enterText(textFields.at(2), 'securePassword123');

        final submitBtn = find.widgetWithText(FilledButton, 'Create account');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.signUpCallCount, equals(1));
        expect(fakeRepo.lastSignUpEmail, equals('newuser@example.com'));
        expect(Get.currentRoute, equals(AppRoutes.authVerifyEmail));
      },
    );

    testWidgets('displays server error on registration failure', (
      tester,
    ) async {
      fakeRepo.nextSignUpResult = AuthResult.failure(
        const AuthFailure(
          code: AuthFailureCode.userAlreadyExists,
          message: 'An account already exists for this email address. Please sign in instead.',
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'existing@example.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'password123');

      final submitBtn = find.widgetWithText(FilledButton, 'Create account');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.signUpCallCount, equals(1));
      expect(
        find.text(
          'An account already exists for this email address. Please sign in instead.',
        ),
        findsOneWidget,
      );
    });
  });
}
