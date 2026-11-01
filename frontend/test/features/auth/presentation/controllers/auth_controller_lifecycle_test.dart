import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trustcue_mobile/features/auth/data/services/account_api_client.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';

import '../../mocks/fake_auth_repository.dart';

void main() {
  group('AuthController Session Lifecycle & Staleness Tests', () {
    late FakeAuthRepository fakeAuth;

    setUp(() {
      Get.testMode = true;
      Get.reset();
      fakeAuth = FakeAuthRepository();
    });

    test('signOut immediately clears profile and user', () async {
      final user = AuthUser(
        id: 'user-1',
        email: 'user1@test.com',
        emailVerified: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      fakeAuth.setStatus(AuthStatus.authenticated, user: user);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'userId': 'user-1',
            'email': 'user1@test.com',
            'displayName': 'User 1',
            'emailVerified': true,
            'createdAt': '2026-01-01T00:00:00Z',
            'syncEnabled': false,
            'syncGeneration': 1,
            'quotaRemainingToday': 14,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final accountApiClient = AccountApiClient(
        baseUrl: 'https://test.trustcue.internal',
        httpClient: mockClient,
        tokenProvider: () async => 'token-user-1',
      );

      final controller = AuthController(
        authRepository: fakeAuth,
        accountApiClient: accountApiClient,
      );
      controller.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.isAuthenticated, isTrue);
      expect(controller.user.value?.id, equals('user-1'));
      expect(controller.profile.value?.displayName, equals('User 1'));

      // Sign out
      await controller.signOut();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.user.value, isNull);
      expect(controller.profile.value, isNull);
    });

    test('late fetchProfile response after logout is safely discarded', () async {
      final user = AuthUser(
        id: 'user-late-logout',
        email: 'latelogout@test.com',
        emailVerified: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      fakeAuth.setStatus(AuthStatus.authenticated, user: user);

      final completer = Completer<http.Response>();
      final mockClient = MockClient((request) => completer.future);

      final accountApiClient = AccountApiClient(
        baseUrl: 'https://test.trustcue.internal',
        httpClient: mockClient,
        tokenProvider: () async => 'token-late',
      );

      final controller = AuthController(
        authRepository: fakeAuth,
        accountApiClient: accountApiClient,
      );
      controller.onInit();
      // Allow _initAuth to start fetchProfile
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // fetchProfile is now in flight
      expect(controller.isLoadingProfile.value, isTrue);
      expect(controller.user.value?.id, equals('user-late-logout'));

      // User signs out before fetchProfile completes
      await controller.signOut();
      expect(controller.user.value, isNull);
      expect(controller.profile.value, isNull);

      // Now the delayed backend response arrives
      completer.complete(
        http.Response(
          jsonEncode({
            'userId': 'user-late-logout',
            'email': 'latelogout@test.com',
            'displayName': 'Late User',
            'emailVerified': true,
            'createdAt': '2026-01-01T00:00:00Z',
            'syncEnabled': false,
            'syncGeneration': 1,
            'quotaRemainingToday': 10,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The late profile must NOT overwrite the logged-out state!
      expect(controller.profile.value, isNull);
      expect(controller.user.value, isNull);
      expect(controller.isAuthenticated, isFalse);
    });

    test('late fetchProfile response from earlier user after account switch is safely discarded', () async {
      final userA = AuthUser(
        id: 'user-A',
        email: 'usera@test.com',
        emailVerified: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final userB = AuthUser(
        id: 'user-B',
        email: 'userb@test.com',
        emailVerified: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      fakeAuth.setStatus(AuthStatus.authenticated, user: userA);

      final completerA = Completer<http.Response>();
      final completerB = Completer<http.Response>();

      final mockClient = MockClient((request) {
        if (request.headers['authorization']?.contains('token-A') ?? false) {
          return completerA.future;
        }
        return completerB.future;
      });

      final accountApiClient = AccountApiClient(
        baseUrl: 'https://test.trustcue.internal',
        httpClient: mockClient,
        tokenProvider: () async {
          return fakeAuth.currentUser?.id == 'user-A' ? 'token-A' : 'token-B';
        },
      );

      final controller = AuthController(
        authRepository: fakeAuth,
        accountApiClient: accountApiClient,
      );
      controller.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Request for user A is in flight
      expect(controller.user.value?.id, equals('user-A'));

      // Now switch account to user B
      fakeAuth.setStatus(AuthStatus.authenticated, user: userB);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Profile was immediately cleared on account switch
      expect(controller.user.value?.id, equals('user-B'));
      expect(controller.profile.value, isNull);

      // User A's slow response finally arrives
      completerA.complete(
        http.Response(
          jsonEncode({
            'userId': 'user-A',
            'email': 'usera@test.com',
            'displayName': 'Account A',
            'emailVerified': true,
            'createdAt': '2026-01-01T00:00:00Z',
            'syncEnabled': false,
            'syncGeneration': 1,
            'quotaRemainingToday': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // User A's response must NOT become user B's profile!
      expect(controller.profile.value, isNull);

      // User B's response arrives
      completerB.complete(
        http.Response(
          jsonEncode({
            'userId': 'user-B',
            'email': 'userb@test.com',
            'displayName': 'Account B',
            'emailVerified': true,
            'createdAt': '2026-01-01T00:00:00Z',
            'syncEnabled': true,
            'syncGeneration': 1,
            'quotaRemainingToday': 15,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Only User B's profile is populated
      expect(controller.profile.value?.displayName, equals('Account B'));
      expect(controller.profile.value?.quotaRemainingToday, equals(15));
    });
  });
}
