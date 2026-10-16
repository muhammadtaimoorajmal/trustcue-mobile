import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/data/database/database_constants.dart';
import 'package:trustcue_mobile/features/reports/data/repositories/sqlite_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;
  late SqliteReportRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trustcue_db_test_');
    dbPath = p.join(tempDir.path, 'test_reports.db');
    repository = SqliteReportRepository(
      databaseFactory: databaseFactory,
      customDatabasePath: dbPath,
    );
    await repository.initialize();
  });

  tearDown(() async {
    await repository.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  TextSnapshot createSnapshot({
    String id = 'snap-001',
    String text =
        'Urgent: Verify your banking credentials at http://fake.com now!',
  }) {
    return TextSnapshot(
      id: id,
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
    );
  }

  SavedReport createSavedReport({
    String id = 'rep-001',
    TextSnapshot? snapshot,
    String? accountId,
    bool includeAi = false,
  }) {
    final snap = snapshot ?? createSnapshot();
    final excerpt = snap.text.contains('Urgent:')
        ? 'Urgent:'
        : (snap.text.contains('Urgent') ? 'Urgent' : snap.text.substring(0, 1));
    final startOffset = snap.text.indexOf(excerpt);
    final endOffset = startOffset + excerpt.length;

    final finding = AnalysisFinding(
      id: 'f-1-$id',
      category: 'urgency',
      explanation: 'Demands immediate verification.',
      origin: FindingOrigin.localRule,
      producerId: 'rule.urgency',
      evidence: [
        EvidenceReference(
          snapshotId: snap.id,
          startOffset: startOffset,
          endOffset: endOffset,
          exactExcerpt: excerpt,
        ),
      ],
    );

    final localReport = AnalysisReport(
      id: id,
      snapshot: snap,
      analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 1),
      findings: [finding],
      limitations: const ['Evaluated standard urgency heuristics.'],
      suggestedActions: const ['Do not click suspicious links.'],
    );

    AiAnalysisReport? aiReport;
    if (includeAi) {
      final String aiExcerpt;
      final int aiStart;
      final int aiEnd;
      if (snap.text.contains('Verify your banking credentials at')) {
        aiExcerpt = 'Verify your banking credentials at';
        aiStart = snap.text.indexOf(aiExcerpt);
        aiEnd = aiStart + aiExcerpt.length;
      } else {
        aiStart = 0;
        aiEnd = snap.text.length >= 4 ? 4 : snap.text.length;
        aiExcerpt = snap.text.substring(aiStart, aiEnd);
      }

      aiReport = AiAnalysisReport(
        reportId: 'ai-$id',
        snapshotId: snap.id,
        provider: 'groq-cloud',
        model: 'qwen/qwen3.8-27b',
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 5),
        factualSummary: 'AI identified urgency and credential harvesting link.',
        findings: [
          AnalysisFinding(
            id: 'ai-f-$id',
            category: 'credential',
            explanation:
                'Requests banking credentials via unverified destination.',
            origin: FindingOrigin.remoteAi,
            producerId: 'groq-cloud',
            evidence: [
              EvidenceReference(
                snapshotId: snap.id,
                startOffset: aiStart,
                endOffset: aiEnd,
                exactExcerpt: aiExcerpt,
              ),
            ],
          ),
        ],
        uncertaintyNotes: const [
          'Domain ownership was not checked against a live registrar.',
        ],
        suggestedActions: [
          AssessmentAction(
            id: 'act-$id',
            title: 'Verify banking portal',
            description:
                'Navigate to your banking portal using a bookmarked URL.',
            priority: AssessmentActionPriority.immediate,
            supportingFindingIds: ['ai-f-$id'],
            supportingCategoryIds: const ['credential'],
          ),
        ],
      );
    }

    return SavedReport(
      id: id,
      snapshot: snap,
      accountId: accountId,
      analyzedAt: localReport.analyzedAt,
      savedAt: DateTime.utc(2026, 10, 15, 12, 1, 0),
      localReport: localReport,
      aiReport: aiReport,
    );
  }

  group('SqliteReportRepository Lifecycle & CRUD Tests', () {
    test('saves local report and retrieves by ID with exact byte-for-byte fidelity', () async {
      final report = createSavedReport();
      final saveResult = await repository.saveReport(report);
      expect(saveResult.isSuccess, isTrue);

      final loadResult = await repository.getReportById(report.id);
      expect(loadResult.isSuccess, isTrue);
      final loaded = loadResult.valueOrNull;
      expect(loaded, isNotNull);
      expect(loaded!.id, equals(report.id));
      expect(loaded.snapshot.text, equals(report.snapshot.text));
      expect(loaded.hasAiAnalysis, isFalse);
      expect(loaded.totalFindingsCount, equals(1));
      expect(
        loaded.localReport.findings.first.evidence.first.exactExcerpt,
        equals('Urgent:'),
      );
    });

    test('saves report with AI analysis and retrieves with full AI metadata intact', () async {
      final report = createSavedReport(
        id: 'rep-ai',
        includeAi: true,
        accountId: 'user-456',
      );
      final saveResult = await repository.saveReport(report);
      expect(saveResult.isSuccess, isTrue);

      final loadResult = await repository.getReportById('rep-ai');
      expect(loadResult.isSuccess, isTrue);
      final loaded = loadResult.valueOrNull;
      expect(loaded, isNotNull);
      expect(loaded!.hasAiAnalysis, isTrue);
      expect(loaded.accountId, equals('user-456'));
      expect(loaded.aiReport!.provider, equals('groq-cloud'));
      expect(loaded.aiReport!.model, equals('qwen/qwen3.8-27b'));
      expect(loaded.aiReport!.findings.length, equals(1));
      expect(
        loaded.aiReport!.findings.first.evidence.first.exactExcerpt,
        equals('Verify your banking credentials at'),
      );
    });

    test('preserves complex Unicode, Urdu text, and Emojis across persistence', () async {
      const complexText =
          'Urgent 🛡️: برائے مہربانی اپنا کوڈ 12345 کسی سے شیئر نہ کریں۔\nEOF';
      final complexSnapshot = createSnapshot(
        id: 'snap-complex',
        text: complexText,
      );
      final report = createSavedReport(
        id: 'rep-complex',
        snapshot: complexSnapshot,
      );

      final saveResult = await repository.saveReport(report);
      expect(saveResult.isSuccess, isTrue);

      final loadResult = await repository.getReportById('rep-complex');
      expect(loadResult.isSuccess, isTrue);
      final loaded = loadResult.valueOrNull;
      expect(loaded!.snapshot.text, equals(complexText));
      expect(loaded.snapshot.text, contains('🛡️'));
      expect(loaded.snapshot.text, contains('برائے مہربانی'));
    });

    test('duplicate save of identical report is safe and idempotent', () async {
      final report = createSavedReport(id: 'rep-dupe');
      final firstSave = await repository.saveReport(report);
      expect(firstSave.isSuccess, isTrue);

      // Save again
      final secondSave = await repository.saveReport(report);
      expect(secondSave.isSuccess, isTrue);

      final countResult = await repository.getReportCount();
      expect(countResult.valueOrNull, equals(1));
    });

    test(
      'conflicting save with same ID but different snapshot is rejected',
      () async {
        final report = createSavedReport(id: 'rep-conflict');
        await repository.saveReport(report);

        final differentSnapshot = createSnapshot(
          id: 'snap-completely-different',
          text: 'Urgent: completely different text',
        );
        final conflictingReport = createSavedReport(
          id: 'rep-conflict', // Same ID
          snapshot: differentSnapshot,
        );

        final secondSave = await repository.saveReport(conflictingReport);
        expect(secondSave.isFailure, isTrue);
        expect(
          secondSave.failureOrNull?.code,
          equals(AnalysisFailureCode.storage),
        );
        expect(
          secondSave.failureOrNull?.message,
          contains('already exists with a different snapshot'),
        );

        // Ensure original data was preserved
        final original = await repository.getReportById('rep-conflict');
        expect(original.valueOrNull!.snapshot.id, equals(report.snapshot.id));
      },
    );

    test(
      'close and reopen persists data safely across storage lifecycle',
      () async {
        final report = createSavedReport(id: 'rep-persist');
        await repository.saveReport(report);
        await repository.close();

        expect(repository.isOpen, isFalse);

        // Reopen repository with same database file
        final reopenedRepo = SqliteReportRepository(
          databaseFactory: databaseFactory,
          customDatabasePath: dbPath,
        );
        await reopenedRepo.initialize();

        final loadResult = await reopenedRepo.getReportById('rep-persist');
        expect(loadResult.isSuccess, isTrue);
        expect(loadResult.valueOrNull?.id, equals('rep-persist'));

        await reopenedRepo.close();
      },
    );

    test('getReportById returns null when report ID does not exist', () async {
      final result = await repository.getReportById('non-existent-id');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test(
      'corrupt payload in database returns typed corruptData failure',
      () async {
        final report = createSavedReport(id: 'rep-corrupt');
        await repository.saveReport(report);

        // Directly corrupt the payload JSON in the database using the shared open connection
        final rawDb = await databaseFactory.openDatabase(dbPath);
        await rawDb.update(
          DatabaseConstants.tableReports,
          {DatabaseConstants.colReportPayload: 'corrupt-not-json'},
          where: '${DatabaseConstants.colReportId} = ?',
          whereArgs: ['rep-corrupt'],
        );

        final loadResult = await repository.getReportById('rep-corrupt');
        expect(loadResult.isFailure, isTrue);
        expect(
          loadResult.failureOrNull?.code,
          equals(AnalysisFailureCode.corruptData),
        );
      },
    );
  });

  group('SqliteReportRepository Summaries & Account Boundary Tests', () {
    test(
      'getReportSummaries returns bounded list with pagination and ordering',
      () async {
        for (var i = 1; i <= 5; i++) {
          final report = createSavedReport(
            id: 'rep-order-$i',
            snapshot: createSnapshot(id: 'snap-order-$i'),
          );
          await repository.saveReport(report);
        }

        final page1 = await repository.getReportSummaries(limit: 3, offset: 0);
        expect(page1.isSuccess, isTrue);
        expect(page1.valueOrNull!.length, equals(3));

        final page2 = await repository.getReportSummaries(limit: 3, offset: 3);
        expect(page2.isSuccess, isTrue);
        expect(page2.valueOrNull!.length, equals(2));
      },
    );

    test(
      'account scoping isolates guest reports from user account reports',
      () async {
        // 1. Guest report (accountId = null)
        final guestReport = createSavedReport(
          id: 'rep-guest',
          snapshot: createSnapshot(id: 'snap-guest'),
          accountId: null,
        );
        await repository.saveReport(guestReport);

        // 2. User A report
        final userAReport = createSavedReport(
          id: 'rep-user-a',
          snapshot: createSnapshot(id: 'snap-user-a'),
          accountId: 'user-a-uuid',
        );
        await repository.saveReport(userAReport);

        // 3. User B report
        final userBReport = createSavedReport(
          id: 'rep-user-b',
          snapshot: createSnapshot(id: 'snap-user-b'),
          accountId: 'user-b-uuid',
        );
        await repository.saveReport(userBReport);

        // Guest query only retrieves guest reports
        final guestSummaries = await repository.getReportSummaries(
          accountId: null,
        );
        expect(guestSummaries.valueOrNull!.length, equals(1));
        expect(guestSummaries.valueOrNull!.first.id, equals('rep-guest'));

        // User A query only retrieves User A reports
        final userASummaries = await repository.getReportSummaries(
          accountId: 'user-a-uuid',
        );
        expect(userASummaries.valueOrNull!.length, equals(1));
        expect(userASummaries.valueOrNull!.first.id, equals('rep-user-a'));

        // User B query only retrieves User B reports
        final userBSummaries = await repository.getReportSummaries(
          accountId: 'user-b-uuid',
        );
        expect(userBSummaries.valueOrNull!.length, equals(1));
        expect(userBSummaries.valueOrNull!.first.id, equals('rep-user-b'));

        // Count checks
        expect(
          (await repository.getReportCount(accountId: null)).valueOrNull,
          equals(1),
        );
        expect(
          (await repository.getReportCount(accountId: 'user-a-uuid'))
              .valueOrNull,
          equals(1),
        );
      },
    );
  });

  group('SqliteReportRepository Deletion Tests', () {
    test('deleteReport deletes report and prunes orphan snapshot', () async {
      final report = createSavedReport(id: 'rep-del');
      await repository.saveReport(report);

      final deleteResult = await repository.deleteReport('rep-del');
      expect(deleteResult.isSuccess, isTrue);
      expect(deleteResult.valueOrNull, isTrue);

      final loadResult = await repository.getReportById('rep-del');
      expect(loadResult.valueOrNull, isNull);

      // Verify orphan snapshot was pruned
      final rawDb = await databaseFactory.openDatabase(dbPath);
      final remainingSnapshots = await rawDb.query(
        DatabaseConstants.tableSnapshots,
        where: '${DatabaseConstants.colSnapshotId} = ?',
        whereArgs: [report.snapshot.id],
      );
      expect(remainingSnapshots, isEmpty);
      await rawDb.close();
    });

    test(
      'deleteReport retains snapshot if another report still references it',
      () async {
        final sharedSnapshot = createSnapshot(id: 'snap-shared');
        final report1 = createSavedReport(
          id: 'rep-shared-1',
          snapshot: sharedSnapshot,
        );
        final report2 = createSavedReport(
          id: 'rep-shared-2',
          snapshot: sharedSnapshot,
        );

        await repository.saveReport(report1);
        await repository.saveReport(report2);

        // Delete report1
        await repository.deleteReport('rep-shared-1');

        // report2 is still present and valid
        final load2 = await repository.getReportById('rep-shared-2');
        expect(load2.isSuccess, isTrue);
        expect(load2.valueOrNull?.snapshot.id, equals('snap-shared'));

        // Snapshot still exists
        final rawDb = await databaseFactory.openDatabase(dbPath);
        final remainingSnapshots = await rawDb.query(
          DatabaseConstants.tableSnapshots,
          where: '${DatabaseConstants.colSnapshotId} = ?',
          whereArgs: ['snap-shared'],
        );
        expect(remainingSnapshots, isNotEmpty);
        await rawDb.close();
      },
    );

    test('deleteReport returns false for non-existent report', () async {
      final deleteResult = await repository.deleteReport('non-existent-id');
      expect(deleteResult.isSuccess, isTrue);
      expect(deleteResult.valueOrNull, isFalse);
    });
  });

  group('SqliteReportRepository Enrichment Save Tests', () {
    test('saving report with AI enrichment updates existing record for same snapshot', () async {
      final snapshot = createSnapshot(id: 'snap-enrich');
      final initialLocalReport = createSavedReport(
        id: 'rep-enrich',
        snapshot: snapshot,
        includeAi: false,
      );
      await repository.saveReport(initialLocalReport);

      final initialLoaded = (await repository.getReportById('rep-enrich'))
          .valueOrNull;
      expect(initialLoaded!.hasAiAnalysis, isFalse);
      expect(initialLoaded.aiReport, isNull);

      // Enrich with AI
      final enrichedReport = createSavedReport(
        id: 'rep-enrich',
        snapshot: snapshot,
        includeAi: true,
      );
      final enrichResult = await repository.saveReport(enrichedReport);
      expect(enrichResult.isSuccess, isTrue);

      final updatedLoaded = (await repository.getReportById('rep-enrich'))
          .valueOrNull;
      expect(updatedLoaded!.hasAiAnalysis, isTrue);
      expect(updatedLoaded.aiReport, isNotNull);
      expect(updatedLoaded.aiReport!.provider, equals('groq-cloud'));
    });
  });

  group('SqliteReportRepository Search Tests', () {
    setUp(() async {
      // Seed distinct reports
      final snap1 = createSnapshot(
        id: 'snap-s1',
        text: 'Congratulations! You won 100% free lottery prize!',
      );
      final snap2 = createSnapshot(
        id: 'snap-s2',
        text: 'Urgent security alert: update your bank pin_number now',
      );
      final snap3 = TextSnapshot(
        id: 'snap-s3',
        text: 'https://secure-login.fakebank.com/portal?verify=1',
        source: InputSource.link,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );
      final snap4 = TextSnapshot(
        id: 'snap-s4',
        text: 'برائے مہربانی اپنا کوڈ 12345 شیئر نہ کریں',
        source: InputSource.screenshot,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      await repository.saveReport(
        createSavedReport(id: 'rep-s1', snapshot: snap1, includeAi: false),
      );
      await repository.saveReport(
        createSavedReport(id: 'rep-s2', snapshot: snap2, includeAi: true),
      );
      await repository.saveReport(
        createSavedReport(id: 'rep-s3', snapshot: snap3, includeAi: true),
      );
      await repository.saveReport(
        createSavedReport(id: 'rep-s4', snapshot: snap4, includeAi: false),
      );
    });

    test('searches by exact keyword in snapshot text', () async {
      final results = await repository.searchReportSummaries(query: 'lottery');
      expect(results.isSuccess, isTrue);
      expect(results.valueOrNull!.length, equals(1));
      expect(results.valueOrNull!.first.id, equals('rep-s1'));
    });

    test('escapes % wildcard so it matches literal % character only', () async {
      // '100%' should match rep-s1 ('100% free'), NOT all records
      final results = await repository.searchReportSummaries(query: '100%');
      expect(results.isSuccess, isTrue);
      expect(results.valueOrNull!.length, equals(1));
      expect(results.valueOrNull!.first.id, equals('rep-s1'));
    });

    test('escapes _ wildcard so it matches literal _ character only', () async {
      // 'pin_number' should match rep-s2 containing literal '_', not random letters
      final results = await repository.searchReportSummaries(
        query: 'pin_number',
      );
      expect(results.isSuccess, isTrue);
      expect(results.valueOrNull!.length, equals(1));
      expect(results.valueOrNull!.first.id, equals('rep-s2'));
    });

    test('filters search results by inputSource', () async {
      final results = await repository.searchReportSummaries(
        query: '',
        inputSource: InputSource.link,
      );
      expect(results.isSuccess, isTrue);
      expect(results.valueOrNull!.length, equals(1));
      expect(results.valueOrNull!.first.id, equals('rep-s3'));
    });

    test('filters search results by hasAiAnalysis provenance', () async {
      final aiResults = await repository.searchReportSummaries(
        query: '',
        hasAiAnalysis: true,
      );
      expect(aiResults.isSuccess, isTrue);
      expect(aiResults.valueOrNull!.length, equals(2));
      expect(
        aiResults.valueOrNull!.map((r) => r.id).toSet(),
        equals({'rep-s2', 'rep-s3'}),
      );

      final localResults = await repository.searchReportSummaries(
        query: '',
        hasAiAnalysis: false,
      );
      expect(localResults.isSuccess, isTrue);
      expect(localResults.valueOrNull!.length, equals(2));
      expect(
        localResults.valueOrNull!.map((r) => r.id).toSet(),
        equals({'rep-s1', 'rep-s4'}),
      );
    });

    test('searches non-ASCII Urdu text accurately', () async {
      final results = await repository.searchReportSummaries(
        query: 'برائے مہربانی',
      );
      expect(results.isSuccess, isTrue);
      expect(results.valueOrNull!.length, equals(1));
      expect(results.valueOrNull!.first.id, equals('rep-s4'));
    });

    test('pagination limits and offsets search results', () async {
      final page1 = await repository.searchReportSummaries(
        query: '',
        limit: 2,
        offset: 0,
      );
      expect(page1.valueOrNull!.length, equals(2));

      final page2 = await repository.searchReportSummaries(
        query: '',
        limit: 2,
        offset: 2,
      );
      expect(page2.valueOrNull!.length, equals(2));

      // Disjoint pages
      final ids1 = page1.valueOrNull!.map((r) => r.id).toSet();
      final ids2 = page2.valueOrNull!.map((r) => r.id).toSet();
      expect(ids1.intersection(ids2), isEmpty);
    });

    test(
      'getReportCount with query and filters returns matching count',
      () async {
        final totalCount = await repository.getReportCount();
        expect(totalCount.valueOrNull, equals(4));

        final aiCount = await repository.getReportCount(hasAiAnalysis: true);
        expect(aiCount.valueOrNull, equals(2));

        final linkCount = await repository.getReportCount(
          inputSource: InputSource.link,
        );
        expect(linkCount.valueOrNull, equals(1));

        final searchCount = await repository.getReportCount(query: 'lottery');
        expect(searchCount.valueOrNull, equals(1));
      },
    );
  });

  group('SqliteReportRepository Scoped Lookup & Deletion Tests', () {
    test(
      'getReportById with enforceAccountScope respects account boundaries',
      () async {
        final guestRep = createSavedReport(id: 'rep-g', accountId: null);
        final userRep = createSavedReport(id: 'rep-u', accountId: 'user-xyz');
        await repository.saveReport(guestRep);
        await repository.saveReport(userRep);

        // Guest querying guest rep
        final gOnG = await repository.getReportById(
          'rep-g',
          accountId: null,
          enforceAccountScope: true,
        );
        expect(gOnG.valueOrNull, isNotNull);

        // Guest querying user rep
        final gOnU = await repository.getReportById(
          'rep-u',
          accountId: null,
          enforceAccountScope: true,
        );
        expect(gOnU.valueOrNull, isNull);

        // User querying user rep
        final uOnU = await repository.getReportById(
          'rep-u',
          accountId: 'user-xyz',
          enforceAccountScope: true,
        );
        expect(uOnU.valueOrNull, isNotNull);

        // User querying guest rep
        final uOnG = await repository.getReportById(
          'rep-g',
          accountId: 'user-xyz',
          enforceAccountScope: true,
        );
        expect(uOnG.valueOrNull, isNull);

        // User A querying User B rep
        final wrongUser = await repository.getReportById(
          'rep-u',
          accountId: 'user-other',
          enforceAccountScope: true,
        );
        expect(wrongUser.valueOrNull, isNull);
      },
    );

    test(
      'deleteReport with enforceAccountScope protects cross-account records',
      () async {
        final guestRep = createSavedReport(id: 'rep-g2', accountId: null);
        final userRep = createSavedReport(id: 'rep-u2', accountId: 'user-xyz');
        await repository.saveReport(guestRep);
        await repository.saveReport(userRep);

        // User cannot delete guest report
        final deleteFail = await repository.deleteReport(
          'rep-g2',
          accountId: 'user-xyz',
          enforceAccountScope: true,
        );
        expect(deleteFail.valueOrNull, isFalse);

        // Guest cannot delete user report
        final deleteFail2 = await repository.deleteReport(
          'rep-u2',
          accountId: null,
          enforceAccountScope: true,
        );
        expect(deleteFail2.valueOrNull, isFalse);

        // Proper owner can delete
        final deleteSuccess = await repository.deleteReport(
          'rep-u2',
          accountId: 'user-xyz',
          enforceAccountScope: true,
        );
        expect(deleteSuccess.valueOrNull, isTrue);

        final check = await repository.getReportById('rep-u2');
        expect(check.valueOrNull, isNull);
      },
    );

    test('deleteReportsForAccount purges only target account reports and preserves others and guests', () async {
      final targetRep1 = createSavedReport(
        id: 'rep-purge-1',
        accountId: 'user-delete-me',
      );
      final targetRep2 = createSavedReport(
        id: 'rep-purge-2',
        accountId: 'user-delete-me',
      );
      final otherRep = createSavedReport(
        id: 'rep-preserve-other',
        accountId: 'user-keep-me',
      );
      final guestRep = createSavedReport(
        id: 'rep-preserve-guest',
        accountId: null,
      );

      await repository.saveReport(targetRep1);
      await repository.saveReport(targetRep2);
      await repository.saveReport(otherRep);
      await repository.saveReport(guestRep);

      final deleteResult = await repository.deleteReportsForAccount(
        'user-delete-me',
      );
      expect(deleteResult.isSuccess, isTrue);
      expect(deleteResult.valueOrNull, equals(2));

      // Target account reports are deleted
      expect(
        (await repository.getReportById('rep-purge-1')).valueOrNull,
        isNull,
      );
      expect(
        (await repository.getReportById('rep-purge-2')).valueOrNull,
        isNull,
      );

      // Other account report and guest report are intact
      expect(
        (await repository.getReportById('rep-preserve-other')).valueOrNull,
        isNotNull,
      );
      expect(
        (await repository.getReportById('rep-preserve-guest')).valueOrNull,
        isNotNull,
      );
    });

    test('report enrichment updates only the matching report ID and preserves separate reports sharing snapshot', () async {
      final sharedSnapshot = TextSnapshot(
        id: 'snap-shared-isolation',
        text: 'Shared message text with suspicious link',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      final localReportA = AnalysisReport(
        id: 'rep-distinct-a',
        snapshot: sharedSnapshot,
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        findings: const [],
        limitations: const ['None'],
        suggestedActions: const [],
      );

      final localReportB = AnalysisReport(
        id: 'rep-distinct-b',
        snapshot: sharedSnapshot,
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 1, 0),
        findings: const [],
        limitations: const ['None'],
        suggestedActions: const [],
      );

      final savedA = SavedReport(
        id: 'rep-distinct-a',
        snapshot: sharedSnapshot,
        analyzedAt: localReportA.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        localReport: localReportA,
      );

      final savedB = SavedReport(
        id: 'rep-distinct-b',
        snapshot: sharedSnapshot,
        analyzedAt: localReportB.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 12, 1, 0),
        localReport: localReportB,
      );

      await repository.saveReport(savedA);
      await repository.saveReport(savedB);

      // Now enrich ONLY Report A with AI findings
      final aiReportA = AiAnalysisReport(
        reportId: 'ai-rep-a',
        snapshotId: sharedSnapshot.id,
        provider: 'groq-cloud',
        model: 'llama-3.3-70b-versatile',
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 5, 0),
        factualSummary: 'AI analysis evaluated text.',
        findings: const [],
        uncertaintyNotes: const ['Probabilistic'],
        suggestedActions: const [],
      );

      final enrichedA = SavedReport(
        id: savedA.id,
        snapshot: savedA.snapshot,
        analyzedAt: savedA.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 12, 10, 0),
        localReport: savedA.localReport,
        aiReport: aiReportA,
      );
      final enrichResult = await repository.saveReport(enrichedA);

      expect(enrichResult.isSuccess, isTrue);

      // Verify Report A is enriched
      final loadedA = (await repository.getReportById('rep-distinct-a'))
          .valueOrNull!;
      expect(loadedA.hasAiAnalysis, isTrue);
      expect(loadedA.aiReport?.provider, equals('groq-cloud'));

      // Verify Report B remains distinct, local-only, and untouched
      final loadedB = (await repository.getReportById('rep-distinct-b'))
          .valueOrNull!;
      expect(loadedB.hasAiAnalysis, isFalse);
      expect(loadedB.aiReport, isNull);
    });
  });
}
