import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';

void main() {
  group('AuthUser', () {
    test(
      'instantiates with valid values and hides internal details in toString',
      () {
        final now = DateTime.now();
        final user = AuthUser(
          id: '123e4567-e89b-12d3-a456-426614174000',
          email: 'user@example.com',
          emailVerified: true,
          createdAt: now,
        );

        expect(user.id, '123e4567-e89b-12d3-a456-426614174000');
        expect(user.email, 'user@example.com');
        expect(user.emailVerified, isTrue);
        expect(user.createdAt, now);

        final str = user.toString();
        expect(str, contains('123e4567-e89b-12d3-a456-426614174000'));
        expect(str, contains('emailVerified: true'));
      },
    );

    test('implements value equality and hashCode', () {
      final now = DateTime.utc(2026, 1, 1);
      final user1 = AuthUser(
        id: 'user-1',
        email: 'test@example.com',
        emailVerified: true,
        createdAt: now,
      );
      final user2 = AuthUser(
        id: 'user-1',
        email: 'test@example.com',
        emailVerified: true,
        createdAt: now,
      );
      final user3 = AuthUser(
        id: 'user-2',
        email: 'other@example.com',
        emailVerified: false,
        createdAt: now,
      );

      expect(user1, equals(user2));
      expect(user1.hashCode, equals(user2.hashCode));
      expect(user1, isNot(equals(user3)));
    });
  });

  group('AuthFailure', () {
    test('creates expected standardized failure variants', () {
      final invalidCreds = AuthFailure.invalidCredentials();
      expect(invalidCreds.code, AuthFailureCode.invalidCredentials);
      expect(invalidCreds.message, contains('Invalid email or password'));

      final unconfirmed = AuthFailure.emailNotConfirmed();
      expect(unconfirmed.code, AuthFailureCode.emailNotConfirmed);
      expect(unconfirmed.message, contains('has not been confirmed'));

      final network = AuthFailure.networkError();
      expect(network.code, AuthFailureCode.networkError);
      expect(network.message, contains('Unable to connect'));

      final rateLimit = AuthFailure.rateLimitExceeded(retryAfterSeconds: 30);
      expect(rateLimit.code, AuthFailureCode.rateLimitExceeded);
      expect(rateLimit.retryAfterSeconds, 30);

      final unconfigured = AuthFailure.unconfigured();
      expect(unconfigured.code, AuthFailureCode.unconfigured);
      expect(
        unconfigured.message,
        contains('Cloud authentication is not configured'),
      );

      final unknown = AuthFailure.unknown('Custom issue');
      expect(unknown.code, AuthFailureCode.unknown);
      expect(unknown.message, 'Custom issue');
    });

    test('toString includes code and message', () {
      final failure = AuthFailure.weakPassword();
      expect(failure.toString(), contains('weakPassword'));
    });
  });

  group('AuthResult', () {
    test('success outcome exposes value and executes success callbacks', () {
      const result = AuthResult.success('test_token');

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 'test_token');
      expect(result.failureOrNull, isNull);

      final folded = result.fold(
        onSuccess: (val) => 'got: $val',
        onFailure: (err) => 'err: ${err.message}',
      );
      expect(folded, 'got: test_token');

      final whenResult = result.when(
        success: (val) => 'when: $val',
        failure: (err) => 'err',
      );
      expect(whenResult, 'when: test_token');
    });

    test('failure outcome exposes failure and executes failure callbacks', () {
      final failure = AuthFailure.sessionExpired();
      final result = AuthResult<String>.failure(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, equals(failure));

      final folded = result.fold(
        onSuccess: (val) => 'got: $val',
        onFailure: (err) => err.code.name,
      );
      expect(folded, 'sessionExpired');

      final whenResult = result.when(
        success: (val) => 'val',
        failure: (err) => err.code.name,
      );
      expect(whenResult, 'sessionExpired');
    });
  });

  group('AuthState and AuthSession', () {
    test('AuthSession correctly evaluates expiration', () {
      final user = AuthUser(
        id: 'user-session',
        email: 'session@example.com',
        emailVerified: true,
      );

      final activeSession = AuthSession(
        user: user,
        accessToken: 'active_token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(activeSession.isExpired, isFalse);

      final expiredSession = AuthSession(
        user: user,
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(expiredSession.isExpired, isTrue);
    });
  });
}
