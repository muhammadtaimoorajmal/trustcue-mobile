import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/reset_password_screen.dart';

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
      initialRoute: AppRoutes.authResetPassword,
      getPages: [
        GetPage(
          name: AppRoutes.authResetPassword,
          page: () => const ResetPasswordScreen(),
          binding: ResetPasswordBinding(),
        ),
        GetPage(
          name: AppRoutes.authLogin,
          page: () => const LoginScreen(),
          binding: LoginBinding(),
        ),
      ],
    );
  }

  group('ResetPasswordScreen & Flow', () {
    testWidgets('renders reset password form fields', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);
      expect(find.text('Save new password'), findsOneWidget);
    });

    testWidgets('validates password length under 6 chars', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '12345');
      await tester.enterText(textFields.at(1), '12345');

      final submitBtn = find.widgetWithText(FilledButton, 'Save new password');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
      expect(fakeRepo.updatePasswordCallCount, equals(0));
    });

    testWidgets('validates password mismatch', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'password123');
      await tester.enterText(textFields.at(1), 'passwordXYZ');

      final submitBtn = find.widgetWithText(FilledButton, 'Save new password');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(fakeRepo.updatePasswordCallCount, equals(0));
    });

    testWidgets('shows success card when password update succeeds', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'brandNewPassword123');
      await tester.enterText(textFields.at(1), 'brandNewPassword123');

      final submitBtn = find.widgetWithText(FilledButton, 'Save new password');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.updatePasswordCallCount, equals(1));
      expect(fakeRepo.lastUpdatedPassword, equals('brandNewPassword123'));
      expect(find.text('Password updated'), findsOneWidget);
      expect(find.text('Continue to sign in'), findsOneWidget);
    });

    testWidgets('displays error message on repository failure', (tester) async {
      fakeRepo.nextUpdatePasswordResult = AuthResult.failure(
        AuthFailure.weakPassword(),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'abcdef');
      await tester.enterText(textFields.at(1), 'abcdef');

      final submitBtn = find.widgetWithText(FilledButton, 'Save new password');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.updatePasswordCallCount, equals(1));
      expect(
        find.text('Password must be at least 6 characters in length.'),
        findsOneWidget,
      );
    });
  });
}
