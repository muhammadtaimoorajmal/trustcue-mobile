import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trustcue_mobile/features/reports/data/services/sync_api_client.dart';
import 'package:trustcue_mobile/features/reports/domain/models/cloud_sync_models.dart';

void main() {
  group('SyncApiClient Tests', () {
    test('pushReports succeeds on 200 with valid response', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/sync/reports'));
        expect(request.method, equals('POST'));
        expect(
          request.headers['Authorization'],
          equals('Bearer test-jwt-token'),
        );

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['reports'], isA<List>());

        return http.Response(
          jsonEncode({
            'status': 'success',
            'acceptedCount': 1,
            'syncedReportIds': ['rep-1'],
            'serverTimestamp': '2026-10-16T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = SyncApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'test-jwt-token',
      );

      final item = CloudReportItem(
        clientReportId: 'rep-1',
        snapshotId: 'snap-1',
        schemaVersion: 1,
        reportPayload: const {'formatVersion': 1, 'outcomeState': 'safe'},
        isDeleted: false,
        clientUpdatedAt: DateTime.utc(2026, 10, 16),
      );

      final result = await client.pushReports([item]);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.acceptedCount, equals(1));
      expect(result.valueOrNull?.syncedReportIds, equals(['rep-1']));
    });

    test('pushReports handles 403 sync opt-in required', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'sync_opt_in_required',
            'message': 'Cloud sync must be enabled',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = SyncApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'test-jwt-token',
      );

      final item = CloudReportItem(
        clientReportId: 'rep-1',
        snapshotId: 'snap-1',
        schemaVersion: 1,
        reportPayload: const {'formatVersion': 1, 'outcomeState': 'safe'},
        isDeleted: false,
        clientUpdatedAt: DateTime.utc(2026, 10, 16),
      );

      final result = await client.pushReports([item]);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('Cloud sync is disabled'));
    });

    test('pullReports parses reports and delta cursor', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/sync/reports'));
        expect(request.method, equals('GET'));
        expect(
          request.url.queryParameters['since'],
          equals('2026-10-15T00:00:00.000Z'),
        );

        return http.Response(
          jsonEncode({
            'status': 'success',
            'reports': [
              {
                'id': 'cloud-id-1',
                'userId': 'usr-1',
                'clientReportId': 'rep-remote-1',
                'snapshotId': 'snap-1',
                'schemaVersion': 1,
                'revision': 1,
                'reportPayload': {'formatVersion': 1, 'outcomeState': 'danger'},
                'isDeleted': false,
                'deletedAt': null,
                'clientUpdatedAt': '2026-10-15T10:00:00Z',
                'createdAt': '2026-10-15T10:00:00Z',
                'updatedAt': '2026-10-15T10:00:01Z',
              },
            ],
            'hasMore': false,
            'serverTimestamp': '2026-10-16T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = SyncApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'test-jwt-token',
      );

      final result = await client.pullReports(
        since: DateTime.utc(2026, 10, 15),
      );
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.reports.length, equals(1));
      expect(
        result.valueOrNull?.reports.first.clientReportId,
        equals('rep-remote-1'),
      );
    });

    test('purgeSyncedReports sends DELETE and returns count', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/sync/reports'));
        expect(request.method, equals('DELETE'));

        return http.Response(
          jsonEncode({
            'status': 'success',
            'purgedCount': 5,
            'message': 'Purged',
            'serverTimestamp': '2026-10-16T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = SyncApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'test-jwt-token',
      );

      final result = await client.purgeSyncedReports();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.purgedCount, equals(5));
    });

    test('fails immediately when token is null or empty', () async {
      final client = SyncApiClient(
        baseUrl: 'http://localhost:8000',
        tokenProvider: () async => null,
      );

      final result = await client.pullReports();
      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.message,
        contains('Authentication required'),
      );
    });
  });
}
