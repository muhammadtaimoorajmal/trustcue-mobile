import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/features/auth/data/services/account_api_client.dart';

void main() {
  group('AccountApiClient Tests', () {
    const testBaseUrl = 'https://api.trustcue.test';
    const testToken = 'valid-jwt-bearer-token-12345';

    test(
      'getProfile returns unauthorized failure when token is null or empty',
      () async {
        final client = AccountApiClient(
          baseUrl: testBaseUrl,
          tokenProvider: () async => null,
        );

        final result = await client.getProfile();
        expect(result.isFailure, isTrue);
        expect(
          result.failureOrNull?.code,
          equals(AnalysisFailureCode.unauthorized),
        );
      },
    );

    test('getProfile successfully parses valid UserProfile response', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.method, equals('GET'));
        expect(
          request.url.toString(),
          equals('$testBaseUrl/api/v1/account/profile'),
        );
        expect(request.headers['Authorization'], equals('Bearer $testToken'));

        return http.Response(
          jsonEncode({
            'userId': '123e4567-e89b-12d3-a456-426614174000',
            'displayName': 'Alice Detective',
            'email': 'alice@trustcue.test',
            'emailVerified': true,
            'createdAt': '2026-10-15T12:00:00Z',
            'syncEnabled': false,
            'quotaRemainingToday': 12,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AccountApiClient(
        baseUrl: testBaseUrl,
        httpClient: mockHttpClient,
        tokenProvider: () async => testToken,
      );

      final result = await client.getProfile();
      expect(result.isSuccess, isTrue);
      final profile = result.valueOrNull!;
      expect(profile.userId, equals('123e4567-e89b-12d3-a456-426614174000'));
      expect(profile.displayName, equals('Alice Detective'));
      expect(profile.email, equals('alice@trustcue.test'));
      expect(profile.emailVerified, isTrue);
      expect(profile.syncEnabled, isFalse);
      expect(profile.quotaRemainingToday, equals(12));
    });

    test('getProfile maps HTTP 401 to unauthorized failure', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response('{"error": {"code": "unauthorized"}}', 401);
      });

      final client = AccountApiClient(
        baseUrl: testBaseUrl,
        httpClient: mockHttpClient,
        tokenProvider: () async => testToken,
      );

      final result = await client.getProfile();
      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals(AnalysisFailureCode.unauthorized),
      );
    });

    test('getProfile handles network timeout cleanly', () async {
      final mockHttpClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      });

      final client = AccountApiClient(
        baseUrl: testBaseUrl,
        httpClient: mockHttpClient,
        tokenProvider: () async => testToken,
        timeout: const Duration(milliseconds: 10),
      );

      final result = await client.getProfile();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, equals(AnalysisFailureCode.timeout));
    });

    test(
      'updateProfile sends PATCH with displayName and returns updated profile',
      () async {
        final mockHttpClient = MockClient((request) async {
          expect(request.method, equals('PATCH'));
          expect(
            request.url.toString(),
            equals('$testBaseUrl/api/v1/account/profile'),
          );
          expect(request.headers['Authorization'], equals('Bearer $testToken'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['displayName'], equals('Bob Agent'));

          return http.Response(
            jsonEncode({
              'userId': '123e4567-e89b-12d3-a456-426614174000',
              'displayName': 'Bob Agent',
              'email': 'bob@trustcue.test',
              'emailVerified': true,
              'createdAt': '2026-10-15T12:00:00Z',
              'syncEnabled': false,
              'quotaRemainingToday': 15,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = AccountApiClient(
          baseUrl: testBaseUrl,
          httpClient: mockHttpClient,
          tokenProvider: () async => testToken,
        );

        final result = await client.updateProfile(displayName: 'Bob Agent');
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull?.displayName, equals('Bob Agent'));
      },
    );

    test(
      'deleteAccount sends DELETE to /api/v1/account and returns success',
      () async {
        final mockHttpClient = MockClient((request) async {
          expect(request.method, equals('DELETE'));
          expect(request.url.toString(), equals('$testBaseUrl/api/v1/account'));
          expect(request.headers['Authorization'], equals('Bearer $testToken'));

          return http.Response(
            jsonEncode({
              'status': 'deleted',
              'userId': '123e4567-e89b-12d3-a456-426614174000',
              'deletedAt': '2026-10-16T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = AccountApiClient(
          baseUrl: testBaseUrl,
          httpClient: mockHttpClient,
          tokenProvider: () async => testToken,
        );

        final result = await client.deleteAccount();
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isTrue);
      },
    );

    test('deleteAccount maps server error to unavailable failure', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response('{"error": "Internal server error"}', 500);
      });

      final client = AccountApiClient(
        baseUrl: testBaseUrl,
        httpClient: mockHttpClient,
        tokenProvider: () async => testToken,
      );

      final result = await client.deleteAccount();
      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals(AnalysisFailureCode.unavailable),
      );
    });
  });
}
