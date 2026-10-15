import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/login_screen.dart';

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
      initialRoute: AppRoutes.authForgotPassword,
      getPages: [
        GetPage(
          name: AppRoutes.authForgotPassword,
          page: () => const ForgotPasswordScreen(),
          binding: ForgotPasswordBinding(),
        ),
        GetPage(
          name: AppRoutes.authLogin,
          page: () => const LoginScreen(),
          binding: LoginBinding(),
        ),
      ],
    );
  }

  group('ForgotPasswordScreen & Flow', () {
    testWidgets('renders reset request form and links', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Reset password'), findsWidgets);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
    });

    testWidgets('validates invalid email before sending', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'notanemail');

      final submitBtn = find.widgetWithText(FilledButton, 'Send reset link');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(fakeRepo.sendPasswordResetCallCount, equals(0));
    });

    testWidgets(
      'shows generic confirmation preventing enumeration on success',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'someone@example.com');

        final submitBtn = find.widgetWithText(FilledButton, 'Send reset link');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.sendPasswordResetCallCount, equals(1));
        expect(fakeRepo.lastPasswordResetEmail, equals('someone@example.com'));

        // Check generic confirmation card
        expect(find.text('Check your inbox'), findsOneWidget);
        expect(find.text('Reset link requested'), findsOneWidget);
        expect(
          find.textContaining('If an account is associated with this email'),
          findsOneWidget,
        );
      },
    );

    testWidgets('displays rate limit error when limit is exceeded', (
      tester,
    ) async {
      fakeRepo.nextSendPasswordResetResult = AuthResult.failure(
        AuthFailure.rateLimitExceeded(),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'someone@example.com');

      final submitBtn = find.widgetWithText(FilledButton, 'Send reset link');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Too many requests sent. Please wait before requesting another reset.',
        ),
        findsOneWidget,
      );
    });
  });
}
