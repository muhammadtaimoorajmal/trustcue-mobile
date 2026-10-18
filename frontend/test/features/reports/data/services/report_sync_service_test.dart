import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/auth/data/services/account_api_client.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/data/services/report_sync_service.dart';
import 'package:trustcue_mobile/features/reports/data/services/sync_api_client.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

import '../../mocks/fake_report_repository.dart';

void main() {
  late FakeReportRepository repository;

  setUp(() {
    repository = FakeReportRepository();
  });

  SavedReport makeReport({
    required String id,
    required String accountId,
    required String text,
  }) {
    final snap = TextSnapshot(
      id: 'snap-$id',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 16),
    );

    final localReport = AnalysisReport(
      id: id,
      snapshot: snap,
      analyzedAt: DateTime.utc(2026, 10, 16),
      findings: const [],
      limitations: const [],
      suggestedActions: const [],
    );

    return SavedReport(
      id: id,
      schemaVersion: 1,
      snapshot: snap,
      accountId: accountId,
      analyzedAt: DateTime.utc(2026, 10, 16),
      savedAt: DateTime.utc(2026, 10, 16),
      localReport: localReport,
    );
  }

  group('ReportSyncService Tests', () {
    test('synchronize does nothing when syncEnabled is false', () async {
      final syncClient = SyncApiClient(tokenProvider: () async => 'token');
      final accountClient = AccountApiClient(
        tokenProvider: () async => 'token',
      );

      final service = ReportSyncService(
        repository: repository,
        syncApiClient: syncClient,
        accountApiClient: accountClient,
      );

      final result = await service.synchronize(
        accountId: 'usr-123',
        syncEnabled: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.pushedCount, equals(0));
      expect(result.valueOrNull?.message, contains('Cloud sync is disabled'));
    });

    test(
      'synchronize pushes pending reports and updates sync metadata',
      () async {
        await repository.saveReport(
          makeReport(
            id: 'rep-local-1',
            accountId: 'usr-123',
            text: 'Scam text 1',
          ),
        );
        await repository.saveReport(
          makeReport(
            id: 'rep-local-2',
            accountId: 'usr-123',
            text: 'Scam text 2',
          ),
        );

        final mockHttp = MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/sync/reports') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final list = body['reports'] as List;
            expect(list.length, equals(2));

            return http.Response(
              jsonEncode({
                'status': 'success',
                'acceptedCount': 2,
                'rejectedCount': 0,
                'serverTimestamp': '2026-10-16T12:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.method == 'GET' &&
              request.url.path == '/api/v1/sync/reports') {
            return http.Response(
              jsonEncode({
                'status': 'success',
                'reports': [],
                'hasMore': false,
                'serverTimestamp': '2026-10-16T12:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('Not found', 404);
        });

        final syncClient = SyncApiClient(
          baseUrl: 'http://localhost:8000',
          httpClient: mockHttp,
          tokenProvider: () async => 'token-123',
        );
        final accountClient = AccountApiClient(
          baseUrl: 'http://localhost:8000',
          httpClient: mockHttp,
          tokenProvider: () async => 'token-123',
        );

        final service = ReportSyncService(
          repository: repository,
          syncApiClient: syncClient,
          accountApiClient: accountClient,
        );

        final syncResult = await service.synchronize(
          accountId: 'usr-123',
          syncEnabled: true,
        );

        expect(syncResult.isSuccess, isTrue);
        expect(syncResult.valueOrNull?.pushedCount, equals(2));
        expect(repository.syncedReportIds.contains('rep-local-1'), isTrue);
        expect(repository.syncedReportIds.contains('rep-local-2'), isTrue);
      },
    );

    test('synchronize applies remote deletion tombstones', () async {
      await repository.saveReport(
        makeReport(
          id: 'rep-to-delete',
          accountId: 'usr-123',
          text: 'Delete me',
        ),
      );

      final mockHttp = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'acceptedCount': 1,
              'rejectedCount': 0,
              'serverTimestamp': '2026-10-16T12:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'reports': [
                {
                  'id': 'cloud-tomb-1',
                  'userId': 'usr-123',
                  'clientReportId': 'rep-to-delete',
                  'snapshotId': 'snap-rep-to-delete',
                  'schemaVersion': 1,
                  'revision': 1,
                  'reportPayload': {
                    'formatVersion': 1,
                    'outcomeState': 'deleted',
                  },
                  'isDeleted': true,
                  'deletedAt': '2026-10-16T12:00:00Z',
                  'clientUpdatedAt': '2026-10-16T12:00:00Z',
                  'createdAt': '2026-10-16T12:00:00Z',
                  'updatedAt': '2026-10-16T12:00:00Z',
                },
              ],
              'hasMore': false,
              'serverTimestamp': '2026-10-16T12:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not found', 404);
      });

      final syncClient = SyncApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'token-123',
      );
      final accountClient = AccountApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'token-123',
      );

      final service = ReportSyncService(
        repository: repository,
        syncApiClient: syncClient,
        accountApiClient: accountClient,
      );

      final syncResult = await service.synchronize(
        accountId: 'usr-123',
        syncEnabled: true,
      );

      expect(syncResult.isSuccess, isTrue);
      expect(syncResult.valueOrNull?.tombstonesApplied, equals(1));

      // Local report was deleted by remote tombstone
      final checkReport = await repository.getReportById('rep-to-delete');
      expect(checkReport.valueOrNull, isNull);
    });

    test('purgeCloudBackups invokes API client and clears metadata', () async {
      final mockHttp = MockClient((request) async {
        expect(request.method, equals('DELETE'));
        return http.Response(
          jsonEncode({
            'status': 'success',
            'purgedCount': 3,
            'message': 'Purged',
            'serverTimestamp': '2026-10-16T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final syncClient = SyncApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'token-123',
      );
      final accountClient = AccountApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'token-123',
      );

      final service = ReportSyncService(
        repository: repository,
        syncApiClient: syncClient,
        accountApiClient: accountClient,
      );

      repository.syncedReportIds.addAll(['rep-1', 'rep-2']);

      final purgeResult = await service.purgeCloudBackups(accountId: 'usr-123');
      expect(purgeResult.isSuccess, isTrue);
      expect(purgeResult.valueOrNull, equals(3));
      expect(repository.syncedReportIds, isEmpty);
    });

    test('synchronize prevents concurrent overlapping cycles', () async {
      final completer = Completer<http.Response>();
      final mockHttp = MockClient((request) async {
        return completer.future;
      });

      final syncClient = SyncApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'token-123',
      );
      final accountClient = AccountApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'token-123',
      );

      final service = ReportSyncService(
        repository: repository,
        syncApiClient: syncClient,
        accountApiClient: accountClient,
      );

      // Start first sync
      final firstSync = service.synchronize(
        accountId: 'usr-123',
        syncEnabled: true,
      );

      expect(service.isSyncing, isTrue);

      // Attempt second sync concurrently
      final secondSync = await service.synchronize(
        accountId: 'usr-123',
        syncEnabled: true,
      );

      expect(secondSync.isFailure, isTrue);
      expect(
        secondSync.failureOrNull?.message,
        contains('already in progress'),
      );

      // Complete first sync
      completer.complete(
        http.Response(
          jsonEncode({
            'status': 'success',
            'records': [],
            'tombstones': [],
            'serverTimestamp': '2026-10-16T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final firstResult = await firstSync;
      expect(firstResult.isSuccess, isTrue);
      expect(service.isSyncing, isFalse);
    });

    test('synchronize pushes pending local tombstones with cautious outcomeState and matching syncGeneration', () async {
      // Record a tombstone locally
      repository.pendingTombstoneIds.add('rep-tomb-test');

      final mockHttp = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/sync/reports') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final list = body['reports'] as List;
          expect(list.length, equals(1));
          final tomb = list[0] as Map<String, dynamic>;
          expect(tomb['clientReportId'], equals('rep-tomb-test'));
          expect(tomb['isDeleted'], isTrue);
          expect(tomb['syncGeneration'], equals(3));
          expect(tomb['reportPayload']['outcomeState'], equals('cautious'));

          return http.Response(
            jsonEncode({
              'status': 'success',
              'acceptedCount': 1,
              'rejectedCount': 0,
              'serverTimestamp': '2026-10-18T12:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'GET' &&
            request.url.path == '/api/v1/sync/reports') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'reports': [],
              'hasMore': false,
              'serverTimestamp': '2026-10-18T12:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not found', 404);
      });

      final syncClient = SyncApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'token-123',
      );
      final accountClient = AccountApiClient(
        baseUrl: 'http://localhost:8000',
        httpClient: mockHttp,
        tokenProvider: () async => 'token-123',
      );

      final service = ReportSyncService(
        repository: repository,
        syncApiClient: syncClient,
        accountApiClient: accountClient,
      );

      final syncResult = await service.synchronize(
        accountId: 'usr-123',
        syncEnabled: true,
        syncGeneration: 3,
      );

      expect(syncResult.isSuccess, isTrue);
      expect(syncResult.valueOrNull?.pushedCount, equals(1));
      // Tombstone cleared locally
      final remainingTombstones = await repository.getPendingTombstones(
        'usr-123',
      );
      expect(remainingTombstones.valueOrNull, isEmpty);
    });
  });
}
