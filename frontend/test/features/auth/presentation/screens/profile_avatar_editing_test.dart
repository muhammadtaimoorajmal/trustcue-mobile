import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/auth/data/services/account_api_client.dart';
import 'package:trustcue_mobile/features/auth/data/services/avatar_image_service.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/account_screen.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';

import '../../mocks/fake_auth_repository.dart';
import '../../../reports/mocks/fake_report_repository.dart';

class _FakeAvatarImageService extends AvatarImageService {
  String? lastUploadedPath;
  String? lastDeletedPath;
  bool shouldUploadFail = false;

  @override
  Future<Result<String>> uploadAvatar({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    if (shouldUploadFail) {
      return Result.failure(
        AnalysisFailure.unavailable('Mock storage upload error'),
      );
    }
    final path = '$userId/avatar_mock.png';
    lastUploadedPath = path;
    return Result.success(path);
  }

  @override
  Future<bool> deleteAvatar(String avatarPath) async {
    lastDeletedPath = avatarPath;
    return true;
  }

  @override
  Future<String?> getSignedUrl(
    String avatarPath, {
    int expiresInSeconds = 3600,
  }) async {
    return 'https://storage.trustcue.test/avatars/$avatarPath?token=signed';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile & Avatar Editing Integration Tests', () {
    late FakeAuthRepository fakeAuth;
    late FakeReportRepository fakeRepo;
    late _FakeAvatarImageService fakeAvatarService;
    late AuthController authController;
    late AuthUser testUser;
    String? currentDisplayName;
    String? currentAvatarPath;

    setUp(() {
      Get.testMode = true;
      Get.reset();

      fakeAuth = FakeAuthRepository();
      fakeRepo = FakeReportRepository();
      fakeAvatarService = _FakeAvatarImageService();
      currentDisplayName = 'Inspector Gadget';
      currentAvatarPath = null;

      testUser = AuthUser(
        id: 'user-uuid-9999',
        email: 'gadget@trustcue.test',
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
                'avatarPath': currentAvatarPath,
                'email': testUser.email,
                'emailVerified': true,
                'createdAt': (testUser.createdAt ?? DateTime.utc(2026, 10, 1))
                    .toIso8601String(),
                'syncEnabled': false,
                'quotaRemainingToday': 15,
              }),
              200,
            );
          }
          if (request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body.containsKey('displayName')) {
              currentDisplayName = body['displayName'] as String?;
            }
            if (body.containsKey('avatarPath')) {
              currentAvatarPath = body['avatarPath'] as String?;
            }
            if (body['clearAvatar'] == true) {
              currentAvatarPath = null;
            }
            return http.Response(
              jsonEncode({
                'userId': testUser.id,
                'displayName': currentDisplayName,
                'avatarPath': currentAvatarPath,
                'email': testUser.email,
                'emailVerified': true,
                'createdAt': (testUser.createdAt ?? DateTime.utc(2026, 10, 1))
                    .toIso8601String(),
                'syncEnabled': false,
                'quotaRemainingToday': 15,
              }),
              200,
            );
          }
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
        avatarImageService: fakeAvatarService,
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
        ],
      );
    }

    testWidgets('renders fallback avatar initials when no avatar is set', (
      tester,
    ) async {
      fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
      await authController.fetchProfile();

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Inspector Gadget'), findsOneWidget);
      // Initials 'IG'
      expect(find.text('IG'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets(
      'tapping Edit Profile opens edit modal with current name and privacy note',
      (tester) async {
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
        await authController.fetchProfile();

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Profile'), findsNWidgets(2)); // Button and Title
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Choose Photo'), findsOneWidget);
        expect(
          find.textContaining('Privacy Note: Your avatar is stored'),
          findsOneWidget,
        );

        // Cancel closes dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Choose Photo'), findsNothing);
      },
    );

    testWidgets(
      'saving new display name via Edit Profile persists and updates UI',
      (tester) async {
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
        await authController.fetchProfile();

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Super Sleuth');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Super Sleuth'), findsOneWidget);
        expect(currentDisplayName, equals('Super Sleuth'));
        // Initials updated to 'SS'
        expect(find.text('SS'), findsOneWidget);

        // Drain snackbar timer and dismiss animation
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'send password reset email button triggers dispatch and surfaces confirmation banner',
      (tester) async {
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
        await authController.fetchProfile();

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        final resetBtn = find.text('Send Password Reset Email');
        await tester.ensureVisible(resetBtn);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        expect(fakeAuth.sendPasswordResetCallCount, equals(1));
        expect(fakeAuth.lastPasswordResetEmail, equals('gadget@trustcue.test'));

        // Drain snackbar timer and dismiss animation
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      },
    );

    test(
      'updateProfileData handles avatar upload and sets signedUrl on profile',
      () async {
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
        await authController.fetchProfile();

        final validPng = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
          0x00,
          0x00,
          0x0D,
        ]);

        final success = await authController.updateProfileData(
          displayName: 'Avatar Hero',
          newAvatarBytes: validPng,
        );

        expect(success, isTrue);
        expect(
          fakeAvatarService.lastUploadedPath,
          equals('user-uuid-9999/avatar_mock.png'),
        );
        expect(
          authController.profile.value?.avatarPath,
          equals('user-uuid-9999/avatar_mock.png'),
        );
        expect(authController.profile.value?.avatarUrl, contains('signed'));
      },
    );

    test(
      'updateProfileData handles avatar removal and cleans up storage',
      () async {
        currentAvatarPath = 'user-uuid-9999/old_avatar.png';
        fakeAuth.setStatus(AuthStatus.authenticated, user: testUser);
        await authController.fetchProfile();

        final success = await authController.updateProfileData(
          displayName: 'Avatar Hero',
          clearAvatar: true,
        );

        expect(success, isTrue);
        expect(
          fakeAvatarService.lastDeletedPath,
          equals('user-uuid-9999/old_avatar.png'),
        );
        expect(authController.profile.value?.avatarPath, isNull);
        expect(authController.profile.value?.avatarUrl, isNull);
      },
    );
  });
}
