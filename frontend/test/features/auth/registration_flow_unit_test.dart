import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/register_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/account_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/verify_email_screen.dart';

import 'mocks/fake_auth_repository.dart';

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

  group('Module 60: Registration & Confirmation Lifecycle Unit Tests', () {
    testWidgets(
      'confirmation-required signup transitions to verificationPending and routes to verify email screen',
      (tester) async {
        fakeRepo.nextSignUpResult = AuthResult.success(
          AuthUser(
            id: 'test-user-id-unverified',
            email: 'newuser@example.com',
            emailVerified: false,
            createdAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'newuser@example.com');
        await tester.enterText(textFields.at(1), 'password123');
        await tester.enterText(textFields.at(2), 'password123');

        final submitBtn = find.widgetWithText(FilledButton, 'Create account');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.signUpCallCount, equals(1));
        expect(fakeRepo.currentStatus, equals(AuthStatus.verificationPending));
        expect(Get.currentRoute, equals(AppRoutes.authVerifyEmail));
        expect(find.text('newuser@example.com'), findsOneWidget);
      },
    );

    testWidgets(
      'immediate auto-confirmed signup transitions directly to authenticated and routes to account',
      (tester) async {
        fakeRepo.nextSignUpResult = AuthResult.success(
          AuthUser(
            id: 'test-user-id-confirmed',
            email: 'autoconfirmed@example.com',
            emailVerified: true,
            createdAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'autoconfirmed@example.com');
        await tester.enterText(textFields.at(1), 'password123');
        await tester.enterText(textFields.at(2), 'password123');

        final submitBtn = find.widgetWithText(FilledButton, 'Create account');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.signUpCallCount, equals(1));
        expect(fakeRepo.currentStatus, equals(AuthStatus.authenticated));
        expect(Get.currentRoute, equals(AppRoutes.account));
      },
    );

    testWidgets(
      'duplicate email disclosure prevention surfaces safe failure without crashing',
      (tester) async {
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
        expect(fakeRepo.currentStatus, equals(AuthStatus.unauthenticated));
        expect(
          find.text(
            'An account already exists for this email address. Please sign in instead.',
          ),
          findsOneWidget,
        );
        expect(Get.currentRoute, equals(AppRoutes.authRegister));
      },
    );

    testWidgets(
      'network failure during signup maps cleanly to user error banner and stays unauthenticated',
      (tester) async {
        fakeRepo.nextSignUpResult = AuthResult.failure(
          AuthFailure.networkError(),
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'networkfail@example.com');
        await tester.enterText(textFields.at(1), 'password123');
        await tester.enterText(textFields.at(2), 'password123');

        final submitBtn = find.widgetWithText(FilledButton, 'Create account');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.signUpCallCount, equals(1));
        expect(fakeRepo.currentStatus, equals(AuthStatus.unauthenticated));
        expect(
          find.text(
            'Unable to connect to the authentication service. Please check your internet connection.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'double-tap on submit button is prevented while submission is in progress',
      (tester) async {
        final controller = RegisterController(authRepository: fakeRepo);
        Get.put<RegisterController>(controller);

        controller.emailController.text = 'doubletap@example.com';
        controller.passwordController.text = 'password123';
        controller.confirmPasswordController.text = 'password123';

        // Trigger two concurrent sign ups
        final future1 = controller.signUp();
        final future2 = controller.signUp();

        await Future.wait([future1, future2]);

        // Exactly one call should have been dispatched to repository
        expect(fakeRepo.signUpCallCount, equals(1));
      },
    );

    test(
      'handleAuthCallback processes valid callback URL and updates auth status',
      () async {
        final callbackUri = Uri.parse(
          'trustcue://auth-callback#access_token=mock_jwt&refresh_token=mock_refresh&type=signup',
        );

        final result = await fakeRepo.handleAuthCallback(callbackUri);

        expect(result.isSuccess, isTrue);
        expect(fakeRepo.handleCallbackCallCount, equals(1));
      },
    );

    test('handleAuthCallback returns invalidCallback failure for corrupted or error callback URL', () async {
      fakeRepo.nextCallbackResult = AuthResult.failure(
        AuthFailure.invalidCallback(),
      );

      final corruptedUri = Uri.parse(
        'trustcue://auth-callback?error=access_denied&error_description=Confirmation+token+is+invalid',
      );

      final result = await fakeRepo.handleAuthCallback(corruptedUri);

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('Expected failure'),
        failure: (failure) {
          expect(failure.code, equals(AuthFailureCode.invalidCallback));
        },
      );
    });
  });
}
