import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/account_screen.dart';

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
      initialRoute: AppRoutes.account,
      getPages: [
        GetPage(
          name: AppRoutes.account,
          page: () => const AccountScreen(),
          binding: AuthBinding(),
        ),
        GetPage(
          name: AppRoutes.home,
          page: () => const Scaffold(body: Text('Home Content')),
        ),
      ],
    );
  }

  group('AccountScreen', () {
    testWidgets('renders unconfigured state when isConfigured is false', (
      tester,
    ) async {
      fakeRepo.setStatus(AuthStatus.unconfigured);
      fakeRepo.isConfigured = false;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Cloud Service Not Configured'), findsOneWidget);
      expect(
        find.textContaining('All local scam analysis, text extraction'),
        findsOneWidget,
      );
      expect(find.text('Return to Home'), findsOneWidget);
    });

    testWidgets('renders guest mode when unauthenticated', (tester) async {
      fakeRepo.setStatus(AuthStatus.unauthenticated);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Guest Mode'), findsOneWidget);
      expect(
        find.textContaining('using TrustCue locally without an account'),
        findsOneWidget,
      );
      expect(find.text('Optional Account Access'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });

    testWidgets(
      'renders authenticated view with user details and sign out option',
      (tester) async {
        final user = AuthUser(
          id: '123e4567-e89b-12d3-a456-426614174000',
          email: 'authenticated.user@trustcue.test',
          emailVerified: true,
          createdAt: DateTime.now(),
        );
        fakeRepo.setStatus(AuthStatus.authenticated, user: user);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(find.text('Your Account'), findsOneWidget);
        expect(find.text('authenticated.user@trustcue.test'), findsOneWidget);
        expect(find.text('Email verified'), findsOneWidget);
        expect(find.text('Session Security'), findsOneWidget);
        expect(find.text('Sign out'), findsOneWidget);
      },
    );

    testWidgets(
      'sign out flow opens confirmation dialog and confirms signOut',
      (tester) async {
        final user = AuthUser(
          id: '123e4567-e89b-12d3-a456-426614174000',
          email: 'user@example.com',
          emailVerified: true,
          createdAt: DateTime.now(),
        );
        fakeRepo.setStatus(AuthStatus.authenticated, user: user);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final signOutBtn = find.widgetWithText(OutlinedButton, 'Sign out');
        await tester.tap(signOutBtn);
        await tester.pumpAndSettle();

        // Check dialog
        expect(find.text('Sign out of TrustCue?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Confirm sign out in dialog
        final confirmBtn = find.widgetWithText(FilledButton, 'Sign out');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.signOutCallCount, equals(1));
        // Should now display guest view
        expect(find.text('Guest Mode'), findsOneWidget);
      },
    );
  });
}
