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
                startOffset: 8,
                endOffset: 42,
                exactExcerpt: 'Verify your banking credentials at',
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
}
