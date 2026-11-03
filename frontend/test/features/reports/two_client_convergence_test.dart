import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/auth/data/services/account_api_client.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/data/repositories/sqlite_report_repository.dart';
import 'package:trustcue_mobile/features/reports/data/services/report_sync_service.dart';
import 'package:trustcue_mobile/features/reports/data/services/sync_api_client.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late SqliteReportRepository clientARepo;
  late SqliteReportRepository clientBRepo;

  final cloudReports = <String, Map<String, dynamic>>{};
  int serverRevision = 1;

  MockClient buildMockServer() {
    return MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'POST' && path == '/api/v1/sync/reports') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final incoming = (body['reports'] as List).cast<Map<String, dynamic>>();

        for (final item in incoming) {
          final id = item['clientReportId'] as String;
          final isDel = item['isDeleted'] as bool? ?? false;
          final itemTime = DateTime.parse(item['clientUpdatedAt'] as String);

          if (cloudReports.containsKey(id)) {
            final existing = cloudReports[id]!;
            final existingTime = DateTime.parse(
              existing['clientUpdatedAt'] as String,
            );
            final existingIsDel = existing['isDeleted'] as bool? ?? false;

            // Conflict resolution:
            // 1. Stale update rejected
            if (itemTime.isBefore(existingTime)) {
              continue;
            }
            // 2. Equal timestamp: tombstone wins
            if (itemTime.isAtSameMomentAs(existingTime) &&
                existingIsDel &&
                !isDel) {
              continue;
            }
          }

          cloudReports[id] = {
            'id': 'cloud-$id',
            'clientReportId': id,
            'snapshotId': item['snapshotId'],
            'schemaVersion': item['schemaVersion'] ?? 1,
            'revision': serverRevision++,
            'syncGeneration': item['syncGeneration'] ?? 1,
            'reportPayload': item['reportPayload'],
            'isDeleted': isDel,
            'deletedAt': item['deletedAt'],
            'clientUpdatedAt': item['clientUpdatedAt'],
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          };
        }

        return http.Response(
          jsonEncode({
            'status': 'success',
            'acceptedCount': incoming.length,
            'syncedReportIds': incoming
                .map((e) => e['clientReportId'])
                .toList(),
            'serverTimestamp': DateTime.now().toUtc().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.method == 'GET' && path == '/api/v1/sync/reports') {
        return http.Response(
          jsonEncode({
            'status': 'success',
            'reports': cloudReports.values.toList(),
            'hasMore': false,
            'serverTimestamp': DateTime.now().toUtc().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.method == 'DELETE' && path == '/api/v1/sync/reports') {
        final count = cloudReports.length;
        cloudReports.clear();
        return http.Response(
          jsonEncode({
            'status': 'success',
            'purgedCount': count,
            'message': 'All cloud reports purged.',
            'serverTimestamp': DateTime.now().toUtc().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('Not Found', 404);
    });
  }

  SavedReport createSampleReport({
    required String id,
    required String accountId,
    required String text,
  }) {
    final snap = TextSnapshot(
      id: 'snap-$id',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
    );

    const excerpt = 'URGENT:';
    final hasExcerpt = text.startsWith(excerpt);
    final match = hasExcerpt
        ? excerpt
        : text.substring(0, text.length > 5 ? 5 : text.length);

    final finding = AnalysisFinding(
      id: 'find-$id-1',
      category: 'urgency',
      explanation: 'Demands immediate money transfer',
      origin: FindingOrigin.localRule,
      producerId: 'rule.urgency',
      evidence: [
        EvidenceReference(
          snapshotId: snap.id,
          startOffset: text.indexOf(match),
          endOffset: text.indexOf(match) + match.length,
          exactExcerpt: match,
        ),
      ],
    );

    final localReport = AnalysisReport(
      id: 'rep_local_$id',
      snapshot: snap,
      analyzedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      findings: [finding],
      limitations: const ['Local test heuristic'],
      suggestedActions: const ['Verify sender identity'],
    );

    return SavedReport(
      id: id,
      snapshot: snap,
      accountId: accountId,
      analyzedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      savedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      localReport: localReport,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('two_client_sync_test_');
    cloudReports.clear();
    serverRevision = 1;

    clientARepo = SqliteReportRepository(
      databaseFactory: databaseFactory,
      customDatabasePath: p.join(tempDir.path, 'client_a.db'),
    );
    await clientARepo.initialize();

    clientBRepo = SqliteReportRepository(
      databaseFactory: databaseFactory,
      customDatabasePath: p.join(tempDir.path, 'client_b.db'),
    );
    await clientBRepo.initialize();
  });

  tearDown(() async {
    await clientARepo.close();
    await clientBRepo.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Two-Client Convergence & Deletion Matrix Suite', () {
    test('Client A pushes rich report -> Client B pulls metadata summary -> Client A retains rich text without overwrite', () async {
      const testUser = 'usr-two-client';
      const richText =
          'URGENT: Transfer \$1000 now to avoid account suspension!';

      // 1. Client A creates a rich report locally
      final reportA = createSampleReport(
        id: 'rep-sync-1',
        accountId: testUser,
        text: richText,
      );
      await clientARepo.saveReport(reportA);

      final mockServer = buildMockServer();
      final syncClientA = SyncApiClient(
        httpClient: mockServer,
        tokenProvider: () async => 'jwt-token',
      );
      final accountClientA = AccountApiClient(
        httpClient: mockServer,
        tokenProvider: () async => 'jwt-token',
      );
      final serviceA = ReportSyncService(
        repository: clientARepo,
        syncApiClient: syncClientA,
        accountApiClient: accountClientA,
      );

      // 2. Client A synchronizes (pushes to cloud)
      final pushResultA = await serviceA.synchronize(
        accountId: testUser,
        syncEnabled: true,
      );
      expect(pushResultA.isSuccess, isTrue);
      expect(pushResultA.valueOrNull?.pushedCount, equals(1));

      // Verify cloud payload contains 0 raw message text (strict privacy allowlist)
      expect(cloudReports.containsKey('rep-sync-1'), isTrue);
      final cloudItem = cloudReports['rep-sync-1']!;
      final cloudPayload = cloudItem['reportPayload'] as Map<String, dynamic>;
      expect(cloudPayload.containsKey('text'), isFalse);
      expect(cloudPayload.containsKey('raw_text'), isFalse);
      expect(cloudPayload.containsKey('evidence'), isFalse);
      expect(cloudPayload['outcomeState'], equals('indicatorsDetected'));
      expect(cloudPayload['indicatorCount'], equals(1));

      // 3. Client B (isolated secondary device) synchronizes (pulls from cloud)
      final syncClientB = SyncApiClient(
        httpClient: mockServer,
        tokenProvider: () async => 'jwt-token',
      );
      final accountClientB = AccountApiClient(
        httpClient: mockServer,
        tokenProvider: () async => 'jwt-token',
      );
      final serviceB = ReportSyncService(
        repository: clientBRepo,
        syncApiClient: syncClientB,
        accountApiClient: accountClientB,
      );

      final pullResultB = await serviceB.synchronize(
        accountId: testUser,
        syncEnabled: true,
      );
      expect(pullResultB.isSuccess, isTrue);
      expect(pullResultB.valueOrNull?.pulledCount, equals(1));

      // 4. Verify Client B restored metadata-only summary with EMPTY snapshot text
      final clientBReport = (await clientBRepo.getReportById(
        'rep-sync-1',
        accountId: testUser,
      )).valueOrNull!;
      expect(clientBReport.id, equals('rep-sync-1'));
      expect(clientBReport.snapshot.text, isEmpty); // Strict privacy guarantee!
      expect(
        clientBReport.totalFindingsCount,
        equals(0),
      ); // Findings quotes not stored in cloud

      final clientBSummaries = (await clientBRepo.getReportSummaries(
        accountId: testUser,
      )).valueOrNull!;
      expect(clientBSummaries.length, equals(1));
      expect(clientBSummaries.first.findingsCount, equals(1));
      expect(
        clientBSummaries.first.previewText,
        equals('[Cloud Backup Summary]'),
      );

      // 5. Client A synchronizes AGAIN: Client A local rich text MUST NOT BE OVERWRITTEN!
      final secondSyncA = await serviceA.synchronize(
        accountId: testUser,
        syncEnabled: true,
      );
      expect(secondSyncA.isSuccess, isTrue);

      final clientAReportAfter = (await clientARepo.getReportById(
        'rep-sync-1',
        accountId: testUser,
      )).valueOrNull!;
      expect(
        clientAReportAfter.snapshot.text,
        equals(richText),
      ); // 100% PRESERVED!
      expect(clientAReportAfter.previewText, contains('URGENT: Transfer'));
    });

    test('Deletion Matrix: Local-only delete on Client A preserves cloud backup and Client B record', () async {
      const testUser = 'usr-deletion-matrix';
      final rep = createSampleReport(
        id: 'rep-matrix-1',
        accountId: testUser,
        text: 'URGENT: Sample phishing message',
      );
      await clientARepo.saveReport(rep);

      final mockServer = buildMockServer();
      final serviceA = ReportSyncService(
        repository: clientARepo,
        syncApiClient: SyncApiClient(
          httpClient: mockServer,
          tokenProvider: () async => 'jwt-token',
        ),
        accountApiClient: AccountApiClient(
          httpClient: mockServer,
          tokenProvider: () async => 'jwt-token',
        ),
      );
      final serviceB = ReportSyncService(
        repository: clientBRepo,
        syncApiClient: SyncApiClient(
          httpClient: mockServer,
          tokenProvider: () async => 'jwt-token',
        ),
        accountApiClient: AccountApiClient(
          httpClient: mockServer,
          tokenProvider: () async => 'jwt-token',
        ),
      );

      // Client A pushes, Client B pulls
      await serviceA.synchronize(accountId: testUser, syncEnabled: true);
      await serviceB.synchronize(accountId: testUser, syncEnabled: true);

      expect(
        (await clientBRepo.getReportById(
          'rep-matrix-1',
          accountId: testUser,
        )).valueOrNull,
        isNotNull,
      );

      // Client A performs LOCAL-ONLY delete (tombstoneForCloud = false)
      await clientARepo.deleteReport(
        'rep-matrix-1',
        accountId: testUser,
        tombstoneForCloud: false,
      );
      expect(
        (await clientARepo.getReportById(
          'rep-matrix-1',
          accountId: testUser,
        )).valueOrNull,
        isNull,
      );

      // Client A synchronizes -> zero tombstones pushed
      final syncAfterLocalDel = await serviceA.synchronize(
        accountId: testUser,
        syncEnabled: true,
      );
      expect(syncAfterLocalDel.valueOrNull?.tombstonesApplied, equals(0));
      expect(cloudReports['rep-matrix-1']!['isDeleted'], isFalse);

      // Client B synchronizes -> report remains intact on Client B
      await serviceB.synchronize(accountId: testUser, syncEnabled: true);
      expect(
        (await clientBRepo.getReportById(
          'rep-matrix-1',
          accountId: testUser,
        )).valueOrNull,
        isNotNull,
      );
    });

    test('Deletion Matrix: Device & Cloud delete on Client B propagates tombstone to Client A', () async {
      const testUser = 'usr-tomb-matrix';
      final rep = createSampleReport(
        id: 'rep-tomb-2',
        accountId: testUser,
        text: 'URGENT: Another scam attempt',
      );
      await clientARepo.saveReport(rep);

      final mockServer = buildMockServer();
      final serviceA = ReportSyncService(
        repository: clientARepo,
        syncApiClient: SyncApiClient(
          httpClient: mockServer,
          tokenProvider: () async => 'jwt-token',
        ),
        accountApiClient: AccountApiClient(
          httpClient: mockServer,
          tokenProvider: () async => 'jwt-token',
        ),
      );
      final serviceB = ReportSyncService(
        repository: clientBRepo,
        syncApiClient: SyncApiClient(
          httpClient: mockServer,
          tokenProvider: () async => 'jwt-token',
        ),
        accountApiClient: AccountApiClient(
          httpClient: mockServer,
          tokenProvider: () async => 'jwt-token',
        ),
      );

      // Client A pushes, Client B pulls
      await serviceA.synchronize(accountId: testUser, syncEnabled: true);
      await serviceB.synchronize(accountId: testUser, syncEnabled: true);

      // Client B deletes with Device & Cloud (tombstoneForCloud = true)
      await clientBRepo.deleteReport(
        'rep-tomb-2',
        accountId: testUser,
        tombstoneForCloud: true,
      );
      expect(
        (await clientBRepo.getReportById(
          'rep-tomb-2',
          accountId: testUser,
        )).valueOrNull,
        isNull,
      );

      // Client B syncs -> pushes tombstone to cloud
      final bPush = await serviceB.synchronize(
        accountId: testUser,
        syncEnabled: true,
      );
      expect(bPush.valueOrNull?.pushedCount, equals(1));
      expect(cloudReports['rep-tomb-2']!['isDeleted'], isTrue);

      // Client A syncs -> pulls tombstone and deletes local report
      final aPull = await serviceA.synchronize(
        accountId: testUser,
        syncEnabled: true,
      );
      expect(aPull.valueOrNull?.tombstonesApplied, equals(1));
      expect(
        (await clientARepo.getReportById(
          'rep-tomb-2',
          accountId: testUser,
        )).valueOrNull,
        isNull,
      );
    });
  });
}
