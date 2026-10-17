import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trustcue_mobile/features/reports/data/database/database_constants.dart';
import 'package:trustcue_mobile/features/reports/data/database/local_database_migrator.dart';

void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  group('LocalDatabaseMigrator Tests', () {
    const migrator = LocalDatabaseMigrator();

    test('initializes clean database to Schema Version 1 with indexes and foreign keys', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: migrator.onConfigure,
          onCreate: migrator.onCreate,
          onUpgrade: migrator.onUpgrade,
          onDowngrade: migrator.onDowngrade,
        ),
      );

      // Verify user_version is 1
      final versionResult = await db.rawQuery('PRAGMA user_version;');
      final currentVersion = versionResult.first.values.first as int;
      expect(currentVersion, equals(1));

      // Verify foreign keys are enabled
      final fkResult = await db.rawQuery('PRAGMA foreign_keys;');
      final fkEnabled = fkResult.first.values.first as int;
      expect(fkEnabled, equals(1));

      // Verify text_snapshots table exists
      final snapshotTableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
        [DatabaseConstants.tableSnapshots],
      );
      expect(snapshotTableCheck, isNotEmpty);

      // Verify saved_reports table exists
      final reportTableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
        [DatabaseConstants.tableReports],
      );
      expect(reportTableCheck, isNotEmpty);

      // Verify indexes exist
      final indexCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?;",
        [DatabaseConstants.tableReports],
      );
      final indexNames = indexCheck
          .map((row) => row['name'] as String)
          .toList();
      expect(indexNames, contains('idx_reports_account_id'));
      expect(indexNames, contains('idx_reports_created_at'));
      expect(indexNames, contains('idx_reports_snapshot_id'));

      await db.close();
    });

    test('foreign key constraint prevents inserting report with non-existent snapshot', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: migrator.onConfigure,
          onCreate: migrator.onCreate,
        ),
      );

      expect(
        () => db.insert(DatabaseConstants.tableReports, {
          DatabaseConstants.colReportId: 'rep-orphan',
          DatabaseConstants.colReportSchemaVersion: 1,
          DatabaseConstants.colReportSnapshotId: 'non-existent-snap-id',
          DatabaseConstants.colReportAnalyzedAt: '2026-10-15T12:00:00.000Z',
          DatabaseConstants.colReportSavedAt: '2026-10-15T12:00:00.000Z',
          DatabaseConstants.colReportHasAiAnalysis: 0,
          DatabaseConstants.colReportFindingsCount: 0,
          DatabaseConstants.colReportOutcomeState: 'noIndicatorsMatched',
          DatabaseConstants.colReportPreviewText: 'preview',
          DatabaseConstants.colReportPayload: '{}',
        }),
        throwsA(isA<DatabaseException>()),
      );

      await db.close();
    });

    test('onDowngrade throws UnsupportedDatabaseVersionException without wiping database', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      expect(
        () => migrator.onDowngrade(
          db,
          4, // oldVersion (from newer app)
          3, // supportedVersion (current app)
        ),
        throwsA(isA<UnsupportedDatabaseVersionException>()),
      );
      await db.close();
    });

    test('initializes clean database to Schema Version 3 with feedback table and indexes', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseConstants.currentDatabaseVersion,
          onConfigure: migrator.onConfigure,
          onCreate: migrator.onCreate,
          onUpgrade: migrator.onUpgrade,
          onDowngrade: migrator.onDowngrade,
        ),
      );

      final versionResult = await db.rawQuery('PRAGMA user_version;');
      final currentVersion = versionResult.first.values.first as int;
      expect(currentVersion, equals(3));

      // Verify local_feedback table exists
      final feedbackTableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
        [DatabaseConstants.tableFeedback],
      );
      expect(feedbackTableCheck, isNotEmpty);

      // Verify feedback indexes exist
      final indexCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?;",
        [DatabaseConstants.tableFeedback],
      );
      final indexNames = indexCheck
          .map((row) => row['name'] as String)
          .toList();
      expect(indexNames, contains('idx_feedback_created_at'));
      expect(indexNames, contains('idx_feedback_target'));

      await db.close();
    });

    test('upgrades database sequentially from Version 1 to Version 3 preserving data', () async {
      // 1. Create DB at Version 1
      final dbV1 = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: migrator.onConfigure,
          onCreate: migrator.onCreate,
        ),
      );

      await dbV1.insert(DatabaseConstants.tableSnapshots, {
        DatabaseConstants.colSnapshotId: 'snap-1',
        DatabaseConstants.colSnapshotText: 'Test text',
        DatabaseConstants.colSnapshotInputSource: 'messageText',
        DatabaseConstants.colSnapshotCreatedAt: '2026-10-15T12:00:00.000Z',
        DatabaseConstants.colSnapshotSha256: 'hash1',
      });

      // 2. Perform sequential upgrade from Version 1 to Version 3
      await migrator.onUpgrade(dbV1, 1, 3);
      await dbV1.execute('PRAGMA user_version = 3;');

      final versionResult = await dbV1.rawQuery('PRAGMA user_version;');
      expect(versionResult.first.values.first as int, equals(3));

      // Verify V1 row preserved
      final rows = await dbV1.query(DatabaseConstants.tableSnapshots);
      expect(rows.length, equals(1));
      expect(rows.first[DatabaseConstants.colSnapshotId], equals('snap-1'));

      // Verify V2 and V3 tables exist
      final syncTableCheck = await dbV1.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
        [DatabaseConstants.tableSyncMetadata],
      );
      expect(syncTableCheck, isNotEmpty);

      final feedbackTableCheck = await dbV1.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
        [DatabaseConstants.tableFeedback],
      );
      expect(feedbackTableCheck, isNotEmpty);

      await dbV1.close();
    });
  });
}
