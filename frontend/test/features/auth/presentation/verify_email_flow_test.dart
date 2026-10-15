import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/verify_email_controller.dart';
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

  Widget createWidgetUnderTest({String email = 'verify@example.com'}) {
    Get.put<VerifyEmailController>(
      VerifyEmailController(authRepository: fakeRepo, initialEmail: email),
    );
    return GetMaterialApp(
      initialRoute: AppRoutes.authVerifyEmail,
      getPages: [
        GetPage(
          name: AppRoutes.authVerifyEmail,
          page: () => const VerifyEmailScreen(),
        ),
        GetPage(
          name: AppRoutes.authLogin,
          page: () => const LoginScreen(),
          binding: LoginBinding(),
        ),
      ],
    );
  }

  group('VerifyEmailScreen & Flow', () {
    testWidgets('renders email verification instructions with target email', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(email: 'testuser@example.com'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('testuser@example.com'), findsOneWidget);
      expect(find.text('Resend confirmation email'), findsOneWidget);
      expect(find.text('Return to sign in'), findsOneWidget);
    });

    testWidgets('resend triggers cooldown countdown and success feedback', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(email: 'testuser@example.com'),
      );
      await tester.pumpAndSettle();

      final resendBtn = find.widgetWithText(
        FilledButton,
        'Resend confirmation email',
      );
      await tester.tap(resendBtn);
      await tester.pump();

      expect(fakeRepo.resendVerificationCallCount, equals(1));
      expect(fakeRepo.lastResendEmail, equals('testuser@example.com'));

      final controller = Get.find<VerifyEmailController>();
      expect(controller.cooldownSeconds.value, equals(60));
      expect(find.textContaining('Resend email ('), findsOneWidget);
      expect(
        find.text(
          'Verification request sent. Please check your inbox or spam folder.',
        ),
        findsOneWidget,
      );

      // Advance clock by 1 second to test timer decrement
      await tester.pump(const Duration(seconds: 1));
      expect(controller.cooldownSeconds.value, equals(59));

      // Exhaust remaining cooldown to cancel the periodic timer
      await tester.pump(const Duration(seconds: 59));
      expect(controller.cooldownSeconds.value, equals(0));
    });

    testWidgets('handles rate limit by respecting retry after seconds', (
      tester,
    ) async {
      fakeRepo.nextResendVerificationResult = AuthResult.failure(
        AuthFailure.rateLimitExceeded(retryAfterSeconds: 45),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final resendBtn = find.widgetWithText(
        FilledButton,
        'Resend confirmation email',
      );
      await tester.tap(resendBtn);
      await tester.pump();

      final controller = Get.find<VerifyEmailController>();
      expect(controller.cooldownSeconds.value, equals(45));
      expect(
        find.text('Too many requests sent. Please wait before trying again.'),
        findsOneWidget,
      );

      // Exhaust cooldown to cancel timer
      await tester.pump(const Duration(seconds: 45));
      expect(controller.cooldownSeconds.value, equals(0));
    });

    testWidgets('navigates back to sign in screen', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final returnBtn = find.widgetWithText(
        OutlinedButton,
        'Return to sign in',
      );
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, equals(AppRoutes.authLogin));
    });
  });
}
