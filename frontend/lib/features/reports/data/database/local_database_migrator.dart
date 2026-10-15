import 'package:sqflite/sqflite.dart';
import 'package:trustcue_mobile/features/reports/data/database/database_constants.dart';

/// Exception thrown when opening a database created by a newer version of TrustCue.
///
/// Prevents data loss by refusing to execute or silently drop the database.
class UnsupportedDatabaseVersionException implements Exception {
  final int actualVersion;
  final int supportedVersion;
  final String message;

  UnsupportedDatabaseVersionException({
    required this.actualVersion,
    required this.supportedVersion,
  }) : message =
           'Database version $actualVersion is newer than supported version $supportedVersion. Please update the application.';

  @override
  String toString() => 'UnsupportedDatabaseVersionException: $message';
}

/// Manages ordered, transactional SQLite schema migrations.
///
/// Invariants & Guarantees:
/// - Fresh installs initialize schema version 1 completely with indexes and foreign keys.
/// - Upgrades execute sequentially and transactionally from (oldVersion + 1) to targetVersion.
/// - Downgrades are strictly rejected without dropping or modifying the database.
/// - Failed migration steps roll back the transaction and do not advance user_version.
class LocalDatabaseMigrator {
  const LocalDatabaseMigrator();

  /// Called when the SQLite database is first created on a clean installation.
  Future<void> onCreate(DatabaseExecutor db, int version) async {
    for (var v = 1; v <= version; v++) {
      await _applyMigration(db, v);
    }
  }

  /// Called when an existing database with a lower version is opened.
  Future<void> onUpgrade(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      await _applyMigration(db, v);
    }
  }

  /// Called if a database with a higher version than supported is opened.
  ///
  /// Strictly prohibits dropping tables or resetting data.
  Future<void> onDowngrade(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    throw UnsupportedDatabaseVersionException(
      actualVersion: oldVersion,
      supportedVersion: newVersion,
    );
  }

  /// Configures SQLite runtime options such as foreign keys.
  Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _applyMigration(DatabaseExecutor db, int targetVersion) async {
    switch (targetVersion) {
      case 1:
        await _applyMigrationV1(db);
        break;
      default:
        throw ArgumentError(
          'Unrecognized migration target version: $targetVersion',
        );
    }
  }

  Future<void> _applyMigrationV1(DatabaseExecutor db) async {
    // 1. Text snapshots table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableSnapshots} (
        ${DatabaseConstants.colSnapshotId} TEXT PRIMARY KEY NOT NULL,
        ${DatabaseConstants.colSnapshotText} TEXT NOT NULL,
        ${DatabaseConstants.colSnapshotInputSource} TEXT NOT NULL,
        ${DatabaseConstants.colSnapshotCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colSnapshotSha256} TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_snapshots_created_at
      ON ${DatabaseConstants.tableSnapshots} (${DatabaseConstants.colSnapshotCreatedAt});
    ''');

    // 2. Saved reports table with foreign key constraint
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableReports} (
        ${DatabaseConstants.colReportId} TEXT PRIMARY KEY NOT NULL,
        ${DatabaseConstants.colReportSchemaVersion} INTEGER NOT NULL,
        ${DatabaseConstants.colReportSnapshotId} TEXT NOT NULL,
        ${DatabaseConstants.colReportAccountId} TEXT,
        ${DatabaseConstants.colReportAnalyzedAt} TEXT NOT NULL,
        ${DatabaseConstants.colReportSavedAt} TEXT NOT NULL,
        ${DatabaseConstants.colReportHasAiAnalysis} INTEGER NOT NULL DEFAULT 0,
        ${DatabaseConstants.colReportAiProvider} TEXT,
        ${DatabaseConstants.colReportAiModel} TEXT,
        ${DatabaseConstants.colReportFindingsCount} INTEGER NOT NULL DEFAULT 0,
        ${DatabaseConstants.colReportOutcomeState} TEXT NOT NULL,
        ${DatabaseConstants.colReportPreviewText} TEXT NOT NULL,
        ${DatabaseConstants.colReportPayload} TEXT NOT NULL,
        FOREIGN KEY (${DatabaseConstants.colReportSnapshotId})
          REFERENCES ${DatabaseConstants.tableSnapshots}(${DatabaseConstants.colSnapshotId})
          ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reports_account_id
      ON ${DatabaseConstants.tableReports} (${DatabaseConstants.colReportAccountId});
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reports_created_at
      ON ${DatabaseConstants.tableReports} (${DatabaseConstants.colReportSavedAt} DESC);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reports_snapshot_id
      ON ${DatabaseConstants.tableReports} (${DatabaseConstants.colReportSnapshotId});
    ''');
  }
}
