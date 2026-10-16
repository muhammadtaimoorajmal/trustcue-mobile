import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/auth/data/services/account_api_client.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';

import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/account_screen.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

import '../../mocks/fake_auth_repository.dart';
import '../../../reports/mocks/fake_report_repository.dart';

void main() {
  group('AccountScreen Profile & Deletion Tests', () {
    late FakeAuthRepository fakeAuth;
    late FakeReportRepository fakeRepo;
    late AuthController authController;
    late AuthUser testUser;
    String? currentDisplayName;
    bool syncEnabledState = false;
    bool deleteAccountCalled = false;

    setUp(() {
      Get.testMode = true;
      Get.reset();

      fakeAuth = FakeAuthRepository();
      fakeRepo = FakeReportRepository();
      currentDisplayName = 'Original Name';
      syncEnabledState = false;
      deleteAccountCalled = false;

      testUser = AuthUser(
        id: 'user-uuid-1111',
        email: 'agent@trustcue.test',
        emailVerified: true,
        createdAt: DateTime.utc(2026, 10, 1, 10, 0, 0),
      );

      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/api/v1/account/profile')) {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'userId': testUser.id,
                'displayName': currentDisplayName,
                'email': testUser.email,
                'emailVerified': true,
                'createdAt': (testUser.createdAt ?? DateTime.utc(2026, 10, 1))
                    .toIso8601String(),
                'syncEnabled': syncEnabledState,
                'quotaRemainingToday': 14,
              }),
              200,
            );
          }
          if (request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body.containsKey('displayName')) {
              currentDisplayName = body['displayName'] as String?;
            }
            if (body.containsKey('syncEnabled')) {
              syncEnabledState = body['syncEnabled'] as bool;
            }
            return http.Response(
              jsonEncode({
                'userId': testUser.id,
                'displayName': currentDisplayName,
                'email': testUser.email,
                'emailVerified': true,
                'createdAt': (testUser.createdAt ?? DateTime.utc(2026, 10, 1))
                    .toIso8601String(),
                'syncEnabled': syncEnabledState,
                'quotaRemainingToday': 14,
              }),
              200,
            );
          }
        }
        if (request.url.path.contains('/api/v1/account') &&
            request.method == 'DELETE') {
          deleteAccountCalled = true;
          return http.Response(
            jsonEncode({
              'status': 'deleted',
              'userId': testUser.id,
              'deletedAt': DateTime.now().toIso8601String(),
            }),
            200,
          );
        }
        return http.Response('{"error": "not found"}', 404);
      });

      final accountApiClient = AccountApiClient(
        baseUrl: 'https://api.trustcue.test',
        httpClient: mockHttp,
        tokenProvider: () async => 'test-bearer-token',
      );

      authController = AuthController(
        authRepository: fakeAuth,
        accountApiClient: accountApiClient,
        reportRepository: fakeRepo,
      );

      Get.put<AuthRepository>(fakeAuth, permanent: true);
      Get.put<LocalReportRepository>(fakeRepo, permanent: true);
      Get.put<AuthController>(authController, permanent: true);
    });

    tearDown(() {
      Get.reset();
    });

    Widget createTestApp() {
      return GetMaterialApp(
        initialRoute: AppRoutes.account,
        getPages: [
          GetPage(
            name: AppRoutes.account,
            page: () => const AccountScreen(),
            binding: BindingsBuilder(() {
              if (!Get.isRegistered<AuthController>()) {
                Get.put<AuthController>(authController, permanent: true);
              }
            }),
          ),
          GetPage(
            name: AppRoutes.home,
            page: () => const Scaffold(body: Text('Home Screen')),
          ),
        ],
      );
    }

    testWidgets(
      'displays profile metadata: displayName, quota, sync status, and protected note',
      (tester) async {
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
        await authController.fetchProfile();

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Your Account'), findsOneWidget);
        expect(find.text('agent@trustcue.test'), findsOneWidget);
        expect(find.text('Original Name'), findsOneWidget);
        expect(
          find.textContaining('14 of 15 analysis queries remaining today'),
          findsOneWidget,
        );
        expect(find.text('Disabled (Local only)'), findsOneWidget);
        expect(
          find.textContaining('Strict Privacy Protection: Raw message text'),
          findsOneWidget,
        );
      },
    );

    testWidgets('edit display name flow updates displayName via PATCH', (
      tester,
    ) async {
      fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
      await authController.fetchProfile();

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Original Name'), findsOneWidget);

      // Tap Edit
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Display Name'), findsOneWidget);

      // Enter new name
      await tester.enterText(find.byType(TextFormField), 'Chief Investigator');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify updated name on screen
      expect(find.text('Chief Investigator'), findsOneWidget);
      expect(currentDisplayName, equals('Chief Investigator'));
    });

    testWidgets(
      'account deletion modal shows 3 boundaries and cancel preserves account',
      (tester) async {
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
        await authController.fetchProfile();

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Scroll to Delete Account button and tap
        final deleteBtn = find.text('Delete Account');
        await tester.ensureVisible(deleteBtn);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Check 3 data boundaries
        expect(
          find.text('Delete Account'),
          findsNWidgets(2),
        ); // Button + Dialog title
        expect(find.text('Hosted Cloud Data'), findsOneWidget);
        expect(find.text('This Device Storage'), findsOneWidget);
        expect(find.text('Third-Party AI Diagnostics'), findsOneWidget);

        // Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Account is still authenticated
        expect(fakeAuth.currentStatus, equals(AuthStatus.authenticated));
        expect(deleteAccountCalled, isFalse);
      },
    );

    testWidgets(
      'account deletion requires password, purges local reports, and transitions to guest',
      (tester) async {
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
        await authController.fetchProfile();

        // Add a synthetic report for this user in fakeRepo
        final snap = TextSnapshot(
          id: 'snap-del',
          text: 'User secret test report',
          source: InputSource.messageText,
          createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        );
        final rep = SavedReport(
          id: 'rep-user-del',
          snapshot: snap,
          accountId: testUser.id,
          analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
          savedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
          localReport: AnalysisReport(
            id: 'rep-user-del',
            snapshot: snap,
            analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
            findings: const [],
            limitations: const [],
            suggestedActions: const [],
          ),
        );
        await fakeRepo.saveReport(rep);
        expect(fakeRepo.storage.containsKey('rep-user-del'), isTrue);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Open deletion dialog
        final deleteBtn = find.text('Delete Account');
        await tester.ensureVisible(deleteBtn);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // 1. Submit empty password -> error message
        await tester.tap(find.text('Delete Permanently'));
        await tester.pumpAndSettle();
        expect(find.text('Please enter your password.'), findsOneWidget);

        // 2. Submit incorrect password
        fakeAuth.nextSignInResult = AuthResult.failure(
          AuthFailure.invalidCredentials(),
        );

        await tester.enterText(find.byType(TextField), 'wrongpassword');
        await tester.tap(find.text('Delete Permanently'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Incorrect password'), findsOneWidget);

        // 3. Submit correct password
        fakeAuth.nextSignInResult = AuthResult.success(testUser);
        await tester.enterText(find.byType(TextField), 'correct-password-123');
        await tester.tap(find.text('Delete Permanently'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // Deletion executed on backend
        expect(deleteAccountCalled, isTrue);

        // Local report scoped to this user purged from device SQLite
        expect(fakeRepo.storage.containsKey('rep-user-del'), isFalse);

        // State reset to guest/unauthenticated
        expect(fakeAuth.currentStatus, equals(AuthStatus.unauthenticated));
      },
    );

    testWidgets(
      'displays Cloud Report Backup card with switch disabled and privacy disclosure banner',
      (tester) async {
        syncEnabledState = false;
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Cloud Report Backup'), findsOneWidget);
        expect(find.text('Disabled (Local only)'), findsOneWidget);
        expect(
          find.textContaining('Strict Privacy Protection: Raw message text'),
          findsOneWidget,
        );
        expect(find.byType(Switch), findsOneWidget);
      },
    );

    testWidgets(
      'toggling Cloud Report Backup switch enables sync and shows Sync Now',
      (tester) async {
        syncEnabledState = false;
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        final switchFinder = find.byType(Switch);
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(syncEnabledState, isTrue);
        expect(find.text('Enabled (Summary backup)'), findsOneWidget);
        expect(find.text('Sync Now'), findsOneWidget);
        expect(find.text('Delete Cloud Backups'), findsOneWidget);
      },
    );

    testWidgets(
      'toggling switch off presents confirmation dialog with keep or delete cloud copies',
      (tester) async {
        syncEnabledState = true;
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
        await authController.fetchProfile();

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Enabled (Summary backup)'), findsOneWidget);

        final switchFinder = find.byType(Switch);
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(find.text('Turn Off Cloud Backup?'), findsOneWidget);
        expect(find.text('Keep Cloud Copies'), findsOneWidget);
        expect(find.text('Delete Cloud Copies'), findsOneWidget);

        // Tap Keep Cloud Copies
        await tester.tap(find.text('Keep Cloud Copies'));
        await tester.pumpAndSettle();

        expect(syncEnabledState, isFalse);
        expect(find.text('Disabled (Local only)'), findsOneWidget);
      },
    );
  });
}
