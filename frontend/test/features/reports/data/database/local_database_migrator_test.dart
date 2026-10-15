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
          2, // oldVersion (from newer app)
          1, // supportedVersion (current app)
        ),
        throwsA(isA<UnsupportedDatabaseVersionException>()),
      );
      await db.close();
    });
  });
}
