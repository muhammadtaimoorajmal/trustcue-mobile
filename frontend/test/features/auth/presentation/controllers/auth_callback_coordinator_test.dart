import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/domain/models/user_profile.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_callback_coordinator.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';

import '../../mocks/fake_auth_repository.dart';

class _MockAuthController extends AuthController {
  _MockAuthController({required super.authRepository});

  UserProfile? mockProfile;
  int fetchProfileCallCount = 0;

  @override
  Future<void> fetchProfile() async {
    fetchProfileCallCount++;
    profile.value = mockProfile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository fakeRepo;
  late _MockAuthController mockAuthController;
  late AuthCallbackCoordinator coordinator;
  String? lastNavigatedRoute;
  dynamic lastNavigatedArgs;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    lastNavigatedRoute = null;
    lastNavigatedArgs = null;
    fakeRepo = FakeAuthRepository();
    mockAuthController = _MockAuthController(authRepository: fakeRepo);
    Get.put<AuthController>(mockAuthController);
    coordinator = AuthCallbackCoordinator(
      authRepository: fakeRepo,
      authController: mockAuthController,
      onNavigate: (route, {arguments}) {
        lastNavigatedRoute = route;
        lastNavigatedArgs = arguments;
        return null;
      },
    );
  });

  tearDown(() {
    coordinator.dispose();
    Get.reset();
  });

  test('ignores non-callback URIs', () async {
    final uri = Uri.parse('https://example.com/unrelated/path');
    await coordinator.handleCallbackUri(uri);

    expect(fakeRepo.handleCallbackCallCount, 0);
    expect(lastNavigatedRoute, isNull);
  });

  test(
    'rejects loose path containing auth-callback with untrusted host',
    () async {
      final uri = Uri.parse('https://malicious.org/auth-callback?token=bad');
      await coordinator.handleCallbackUri(uri);

      expect(fakeRepo.handleCallbackCallCount, 0);
      expect(lastNavigatedRoute, isNull);
    },
  );

  test(
    'routes explicit error in callback to login with error banner',
    () async {
      final uri = Uri.parse(
        'trustcue://auth-callback#error=access_denied&error_code=403&error_description=Link+expired',
      );
      await coordinator.handleCallbackUri(uri);

      expect(fakeRepo.handleCallbackCallCount, 0);
      expect(lastNavigatedRoute, AppRoutes.authLogin);
      expect(lastNavigatedArgs, isA<Map<String, dynamic>>());
      expect(lastNavigatedArgs['isError'], isTrue);
      expect(lastNavigatedArgs['bannerMessage'], contains('Link expired'));
    },
  );

  test('routes password recovery callback to authResetPassword when exchange succeeds', () async {
    final uri = Uri.parse(
      'trustcue://auth-callback#access_token=token123&refresh_token=refresh123&type=recovery',
    );
    fakeRepo.nextCallbackResult = const AuthResult.success(null);
    fakeRepo.setStatus(AuthStatus.recoverySession);

    await coordinator.handleCallbackUri(uri);

    expect(fakeRepo.handleCallbackCallCount, 1);
    expect(lastNavigatedRoute, AppRoutes.authResetPassword);
  });

  test('routes failed callback exchange to login with error banner (never false success)', () async {
    final uri = Uri.parse(
      'trustcue://auth-callback?code=missing_pkce_verifier',
    );

    fakeRepo.nextCallbackResult = AuthResult.failure(
      AuthFailure.invalidCallback(),
    );

    await coordinator.handleCallbackUri(uri);

    expect(fakeRepo.handleCallbackCallCount, 1);
    expect(lastNavigatedRoute, AppRoutes.authLogin);
    expect(lastNavigatedArgs['isError'], isTrue);
    expect(
      lastNavigatedArgs['bannerMessage'],
      isNot(contains('Email confirmed!')),
    );
  });

  test(
    'routes authenticated signup with incomplete profile to profileSetup',
    () async {
      final uri = Uri.parse(
        'trustcue://auth-callback#access_token=token123&refresh_token=refresh123&type=signup',
      );

      fakeRepo.nextCallbackResult = const AuthResult.success(null);
      fakeRepo.setStatus(
        AuthStatus.authenticated,
        user: AuthUser(
          id: 'user-1',
          email: 'user@example.com',
          emailVerified: true,
          createdAt: DateTime.now(),
        ),
      );
      mockAuthController.mockProfile = UserProfile(
        userId: 'user-1',
        email: 'user@example.com',
        displayName: null,
        emailVerified: true,
        createdAt: DateTime.now(),
        syncEnabled: false,
        quotaRemainingToday: 15,
      );

      await coordinator.handleCallbackUri(uri);

      expect(fakeRepo.handleCallbackCallCount, 1);
      expect(mockAuthController.fetchProfileCallCount, greaterThanOrEqualTo(1));
      expect(lastNavigatedRoute, AppRoutes.profileSetup);
    },
  );

  test(
    'routes authenticated signup with existing display name to account',
    () async {
      final uri = Uri.parse(
        'trustcue://auth-callback#access_token=token123&refresh_token=refresh123&type=signup',
      );

      fakeRepo.nextCallbackResult = const AuthResult.success(null);
      fakeRepo.setStatus(
        AuthStatus.authenticated,
        user: AuthUser(
          id: 'user-1',
          email: 'user@example.com',
          emailVerified: true,
          createdAt: DateTime.now(),
        ),
      );
      mockAuthController.mockProfile = UserProfile(
        userId: 'user-1',
        email: 'user@example.com',
        displayName: 'Existing User',
        emailVerified: true,
        createdAt: DateTime.now(),
        syncEnabled: false,
        quotaRemainingToday: 15,
      );

      await coordinator.handleCallbackUri(uri);

      expect(fakeRepo.handleCallbackCallCount, 1);
      expect(mockAuthController.fetchProfileCallCount, greaterThanOrEqualTo(1));
      expect(lastNavigatedRoute, AppRoutes.account);
    },
  );

  test('routes successful unauthenticated signup confirmation to login screen with confirmation banner', () async {
    final uri = Uri.parse('trustcue://auth-callback?code=valid_signup_code');

    fakeRepo.nextCallbackResult = const AuthResult.success(null);
    fakeRepo.setStatus(AuthStatus.unauthenticated);

    await coordinator.handleCallbackUri(uri);

    expect(fakeRepo.handleCallbackCallCount, 1);
    expect(lastNavigatedRoute, AppRoutes.authLogin);
    expect(lastNavigatedArgs['isError'], isFalse);
    expect(lastNavigatedArgs['bannerMessage'], contains('Email confirmed!'));
  });

  test('deduplicates rapid consecutive callback events', () async {
    final uri = Uri.parse('trustcue://auth-callback?code=dedup_test');
    fakeRepo.nextCallbackResult = const AuthResult.success(null);

    await coordinator.handleCallbackUri(uri);
    await coordinator.handleCallbackUri(uri);

    expect(fakeRepo.handleCallbackCallCount, 1);
  });
}
