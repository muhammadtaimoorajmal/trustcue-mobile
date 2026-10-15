import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/features/analysis/data/services/analysis_api_client.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/upload_consent.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('AnalysisApiClient Tests', () {
    const testSnapshotText = 'Urgent: Transfer \$100 to account 12345.';
    late TextSnapshot snapshot;
    late UploadConsent validConsent;
    const accountId = 'user-abc-123';

    setUp(() {
      snapshot = TextSnapshot(
        id: 'snapshot-001',
        text: testSnapshotText,
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 10, 0, 0),
      );
      validConsent = UploadConsent.affirmative(
        snapshot: snapshot,
        accountId: accountId,
      );
    });

    test(
      'fails locally without network request when consent is invalid',
      () async {
        var networkHit = false;
        final mockClient = MockClient((request) async {
          networkHit = true;
          return http.Response('{}', 200);
        });

        final client = AnalysisApiClient(
          httpClient: mockClient,
          tokenProvider: () async => 'valid-jwt-token',
        );

        final invalidConsent = UploadConsent.declined(
          snapshot: snapshot,
          accountId: accountId,
        );

        final result = await client.analyzeWithAi(
          snapshot: snapshot,
          consent: invalidConsent,
          sourceRevision: 'rev-1',
          currentAccountId: accountId,
        );

        expect(networkHit, isFalse);
        expect(result.isFailure, isTrue);
        expect(
          result.failureOrNull?.code,
          equals(AnalysisFailureCode.consentRequired),
        );
      },
    );

    test(
      'fails locally without network request when token is missing',
      () async {
        var networkHit = false;
        final mockClient = MockClient((request) async {
          networkHit = true;
          return http.Response('{}', 200);
        });

        final client = AnalysisApiClient(
          httpClient: mockClient,
          tokenProvider: () async => null, // No token
        );

        final result = await client.analyzeWithAi(
          snapshot: snapshot,
          consent: validConsent,
          sourceRevision: 'rev-1',
          currentAccountId: accountId,
        );

        expect(networkHit, isFalse);
        expect(result.isFailure, isTrue);
        expect(
          result.failureOrNull?.code,
          equals(AnalysisFailureCode.unauthorized),
        );
      },
    );

    test(
      'sends Bearer token, payload, and parses 200 response successfully',
      () async {
        http.Request? capturedRequest;
        final mockClient = MockClient((request) async {
          capturedRequest = request;
          final responseBody = jsonEncode({
            'reportId': 'rep-777',
            'snapshotId': 'snapshot-001',
            'provider': 'groq',
            'model': 'qwen/qwen3.8-27b',
            'analyzedAt': '2026-10-15T10:05:00Z',
            'factualSummary': 'Observed urgent payment request.',
            'findings': [
              {
                'id': 'f-1',
                'category': 'urgency',
                'explanation': 'Demands fast transfer.',
                'origin': 'remoteAi',
                'producerId': 'groq-qwen',
                'evidence': [
                  {'startOffset': 0, 'endOffset': 6, 'exactExcerpt': 'Urgent'},
                ],
              },
            ],
            'uncertaintyNotes': ['AI limitations note.'],
            'suggestedActions': [],
          });
          return http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = AnalysisApiClient(
          baseUrl: 'https://api.test.trustcue.app',
          httpClient: mockClient,
          tokenProvider: () async => 'my-secret-jwt-token',
        );

        final result = await client.analyzeWithAi(
          snapshot: snapshot,
          consent: validConsent,
          sourceRevision: 'rev-1',
          currentAccountId: accountId,
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull?.reportId, equals('rep-777'));
        expect(result.valueOrNull?.findings.length, equals(1));

        // Verify request headers
        expect(
          capturedRequest?.headers['Authorization'],
          equals('Bearer my-secret-jwt-token'),
        );
        expect(
          capturedRequest?.headers['Content-Type'],
          equals('application/json'),
        );

        // Verify request payload
        final sentBody =
            jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(sentBody['snapshotId'], equals('snapshot-001'));
        expect(sentBody['text'], equals(testSnapshotText));
        expect(sentBody['consent']['granted'], isTrue);
        expect(sentBody['consent']['disclosureVersion'], equals('1.0.0'));
      },
    );

    test('maps 400 consent_required error correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'consent_required',
              'message': 'Upload consent is required to perform AI analysis.',
            },
          }),
          400,
        );
      });

      final client = AnalysisApiClient(
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      final result = await client.analyzeWithAi(
        snapshot: snapshot,
        consent: validConsent,
        sourceRevision: 'rev-1',
        currentAccountId: accountId,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals(AnalysisFailureCode.consentRequired),
      );
    });

    test('maps 401 unauthorized session expiry correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'unauthorized', 'message': 'Token expired.'},
          }),
          401,
        );
      });

      final client = AnalysisApiClient(
        httpClient: mockClient,
        tokenProvider: () async => 'expired-token',
      );

      final result = await client.analyzeWithAi(
        snapshot: snapshot,
        consent: validConsent,
        sourceRevision: 'rev-1',
        currentAccountId: accountId,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals(AnalysisFailureCode.unauthorized),
      );
    });

    test('maps 429 rate limit with retry-after header', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'rate_limit_exceeded',
              'message': 'Daily AI request quota reached.',
            },
          }),
          429,
          headers: {'retry-after': '3600'},
        );
      });

      final client = AnalysisApiClient(
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      final result = await client.analyzeWithAi(
        snapshot: snapshot,
        consent: validConsent,
        sourceRevision: 'rev-1',
        currentAccountId: accountId,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals(AnalysisFailureCode.rateLimited),
      );
      expect(result.failureOrNull?.retryAfterSeconds, equals('3600'));
    });

    test('maps 502 grounding failure correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'ai_grounding_failed',
              'message': 'AI provider generated ungrounded evidence.',
            },
          }),
          502,
        );
      });

      final client = AnalysisApiClient(
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      final result = await client.analyzeWithAi(
        snapshot: snapshot,
        consent: validConsent,
        sourceRevision: 'rev-1',
        currentAccountId: accountId,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals(AnalysisFailureCode.providerError),
      );
    });

    test('maps 503 provider unavailable correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'provider_unavailable',
              'message': 'AI service is temporarily unavailable.',
            },
          }),
          503,
        );
      });

      final client = AnalysisApiClient(
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      final result = await client.analyzeWithAi(
        snapshot: snapshot,
        consent: validConsent,
        sourceRevision: 'rev-1',
        currentAccountId: accountId,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals(AnalysisFailureCode.unavailable),
      );
    });

    test('handles network SocketException gracefully without leaking sensitive info', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final client = AnalysisApiClient(
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      final result = await client.analyzeWithAi(
        snapshot: snapshot,
        consent: validConsent,
        sourceRevision: 'rev-1',
        currentAccountId: accountId,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals(AnalysisFailureCode.unavailable),
      );
    });

    test('rejects response exceeding max byte limit', () async {
      final largeBytes = List.filled(5000, 65); // 5000 bytes
      final mockClient = MockClient((request) async {
        return http.Response.bytes(largeBytes, 200);
      });

      final client = AnalysisApiClient(
        maxResponseBytes: 1000, // Limit to 1000 bytes
        httpClient: mockClient,
        tokenProvider: () async => 'token',
      );

      final result = await client.analyzeWithAi(
        snapshot: snapshot,
        consent: validConsent,
        sourceRevision: 'rev-1',
        currentAccountId: accountId,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals(AnalysisFailureCode.malformedData),
      );
    });
  });
}
