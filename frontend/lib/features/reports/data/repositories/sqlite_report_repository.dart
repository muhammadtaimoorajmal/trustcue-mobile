import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/data/database/database_constants.dart';
import 'package:trustcue_mobile/features/reports/data/database/local_database_migrator.dart';
import 'package:trustcue_mobile/features/reports/data/serialization/saved_report_codec.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

/// Pure-local SQLite implementation of [LocalReportRepository].
///
/// Invariants & Guarantees:
/// - 100% offline; zero network requests or cloud telemetry during all operations.
/// - Atomic ACID transactions: report record and snapshot text are committed together or rolled back.
/// - Duplicate protection: repeated save of identical report and snapshot is safe and idempotent.
///   Attempting to overwrite an existing report with a different snapshot returns an error.
/// - Bounded summary queries: [getReportSummaries] queries only indexed summary columns without
///   buffering full report payloads or large text bodies into memory.
/// - Invariant verification: reports are strictly validated against their snapshot before saving
///   and after deserializing from SQLite.
/// - Account isolation: queries filter strictly by account UUID or guest (null) status.
class SqliteReportRepository implements LocalReportRepository {
  final Database? _injectedDatabase;
  final DatabaseFactory? _injectedFactory;
  final String? customDatabasePath;
  final SavedReportCodec codec;
  final LocalDatabaseMigrator migrator;

  Database? _db;

  SqliteReportRepository({
    Database? database,
    DatabaseFactory? databaseFactory,
    this.customDatabasePath,
    this.codec = const SavedReportCodec(),
    this.migrator = const LocalDatabaseMigrator(),
  }) : _injectedDatabase = database,
       _injectedFactory = databaseFactory;

  /// Visible for testing to check current connection state.
  bool get isOpen => _db != null && _db!.isOpen;

  @override
  Future<Result<void>> initialize() async {
    if (_db != null && _db!.isOpen) {
      return const Result.success(null);
    }

    if (_injectedDatabase != null) {
      _db = _injectedDatabase;
      return const Result.success(null);
    }

    try {
      final factory = _injectedFactory ?? databaseFactory;
      final String dbPath;
      final customPath = customDatabasePath;
      if (customPath != null) {
        dbPath = customPath;
      } else {
        final databasesDir = await factory.getDatabasesPath();
        dbPath = p.join(databasesDir, DatabaseConstants.databaseName);
      }

      _db = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: DatabaseConstants.currentDatabaseVersion,
          onConfigure: migrator.onConfigure,
          onCreate: migrator.onCreate,
          onUpgrade: migrator.onUpgrade,
          onDowngrade: migrator.onDowngrade,
        ),
      );

      return const Result.success(null);
    } on UnsupportedDatabaseVersionException catch (e) {
      return Result.failure(
        AnalysisFailure.storage('Unsupported database version: ${e.message}'),
      );
    } on DatabaseException catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Database initialization error: ${e.toString()}',
        ),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Unexpected error initializing database: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Result<SavedReport>> saveReport(SavedReport report) async {
    final db = _db;
    if (db == null || !db.isOpen) {
      return const Result.failure(
        AnalysisFailure.storage(
          'Database is not initialized. Call initialize() first.',
        ),
      );
    }

    // Verify invariants defensively before touching database
    try {
      report.localReport.validateAgainst(report.snapshot);
      if (report.aiReport != null) {
        report.aiReport!.validateAgainst(report.snapshot);
      }
    } on ArgumentError catch (e) {
      return Result.failure(
        AnalysisFailure.corruptData(
          'Report invariant validation failed: ${e.message}',
        ),
      );
    }

    try {
      return await db.transaction<Result<SavedReport>>((txn) async {
        // Check for existing report
        final existing = await txn.query(
          DatabaseConstants.tableReports,
          columns: [
            DatabaseConstants.colReportId,
            DatabaseConstants.colReportSnapshotId,
          ],
          where: '${DatabaseConstants.colReportId} = ?',
          whereArgs: [report.id],
        );

        if (existing.isNotEmpty) {
          final existingSnapshotId =
              existing.first[DatabaseConstants.colReportSnapshotId] as String?;
          if (existingSnapshotId == report.snapshot.id) {
            // Idempotent duplicate save: return existing
            return Result.success(report);
          } else {
            return Result.failure(
              AnalysisFailure.storage(
                'A report with ID "${report.id}" already exists with a different snapshot.',
              ),
            );
          }
        }

        // Compute sha256 for snapshot integrity verification
        final snapshotSha256 = sha256
            .convert(utf8.encode(report.snapshot.text))
            .toString();

        // 1. Insert snapshot if not already present
        await txn.insert(DatabaseConstants.tableSnapshots, {
          DatabaseConstants.colSnapshotId: report.snapshot.id,
          DatabaseConstants.colSnapshotText: report.snapshot.text,
          DatabaseConstants.colSnapshotInputSource: report.snapshot.source.name,
          DatabaseConstants.colSnapshotCreatedAt: report.snapshot.createdAt
              .toIso8601String(),
          DatabaseConstants.colSnapshotSha256: snapshotSha256,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // 2. Insert report with payload
        final payloadJson = codec.encodeJson(report);

        await txn.insert(DatabaseConstants.tableReports, {
          DatabaseConstants.colReportId: report.id,
          DatabaseConstants.colReportSchemaVersion: report.schemaVersion,
          DatabaseConstants.colReportSnapshotId: report.snapshot.id,
          DatabaseConstants.colReportAccountId: report.accountId,
          DatabaseConstants.colReportAnalyzedAt: report.analyzedAt
              .toIso8601String(),
          DatabaseConstants.colReportSavedAt: report.savedAt.toIso8601String(),
          DatabaseConstants.colReportHasAiAnalysis: report.hasAiAnalysis
              ? 1
              : 0,
          DatabaseConstants.colReportAiProvider: report.aiReport?.provider,
          DatabaseConstants.colReportAiModel: report.aiReport?.model,
          DatabaseConstants.colReportFindingsCount: report.totalFindingsCount,
          DatabaseConstants.colReportOutcomeState: report.outcomeState.name,
          DatabaseConstants.colReportPreviewText: report.previewText,
          DatabaseConstants.colReportPayload: payloadJson,
        }, conflictAlgorithm: ConflictAlgorithm.abort);

        return Result.success(report);
      });
    } on DatabaseException catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Database error while saving report: ${e.toString()}',
        ),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Unexpected error while saving report: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Result<SavedReport?>> getReportById(String id) async {
    final db = _db;
    if (db == null || !db.isOpen) {
      return const Result.failure(
        AnalysisFailure.storage(
          'Database is not initialized. Call initialize() first.',
        ),
      );
    }

    try {
      final reportRows = await db.query(
        DatabaseConstants.tableReports,
        where: '${DatabaseConstants.colReportId} = ?',
        whereArgs: [id],
      );

      if (reportRows.isEmpty) {
        return const Result.success(null);
      }

      final reportRow = reportRows.first;
      final snapshotId =
          reportRow[DatabaseConstants.colReportSnapshotId] as String;
      final payloadJson =
          reportRow[DatabaseConstants.colReportPayload] as String;

      final snapshotRows = await db.query(
        DatabaseConstants.tableSnapshots,
        where: '${DatabaseConstants.colSnapshotId} = ?',
        whereArgs: [snapshotId],
      );

      if (snapshotRows.isEmpty) {
        return Result.failure(
          AnalysisFailure.storage(
            'Data integrity error: Snapshot "$snapshotId" missing for report "$id".',
          ),
        );
      }

      final snapshotRow = snapshotRows.first;
      final snapshot = TextSnapshot(
        id: snapshotRow[DatabaseConstants.colSnapshotId] as String,
        text: snapshotRow[DatabaseConstants.colSnapshotText] as String,
        source: InputSource.values.byName(
          snapshotRow[DatabaseConstants.colSnapshotInputSource] as String,
        ),
        createdAt: DateTime.parse(
          snapshotRow[DatabaseConstants.colSnapshotCreatedAt] as String,
        ).toUtc(),
      );

      final report = codec.decodeJson(payloadJson, snapshot);
      return Result.success(report);
    } on FormatException catch (e) {
      return Result.failure(
        AnalysisFailure.corruptData(
          'Corrupt report record "$id": ${e.message}',
        ),
      );
    } on ArgumentError catch (e) {
      return Result.failure(
        AnalysisFailure.corruptData(
          'Report invariant violation "$id": ${e.message}',
        ),
      );
    } on DatabaseException catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Database error while retrieving report: ${e.toString()}',
        ),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Unexpected error while retrieving report: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Result<List<SavedReportSummary>>> getReportSummaries({
    String? accountId,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = _db;
    if (db == null || !db.isOpen) {
      return const Result.failure(
        AnalysisFailure.storage(
          'Database is not initialized. Call initialize() first.',
        ),
      );
    }

    try {
      final String whereClause;
      final List<dynamic> whereArgs;

      if (accountId == null) {
        whereClause = 'r.${DatabaseConstants.colReportAccountId} IS NULL';
        whereArgs = [];
      } else {
        whereClause = 'r.${DatabaseConstants.colReportAccountId} = ?';
        whereArgs = [accountId];
      }

      final sql =
          '''
        SELECT r.${DatabaseConstants.colReportId},
               r.${DatabaseConstants.colReportSchemaVersion},
               r.${DatabaseConstants.colReportSnapshotId},
               r.${DatabaseConstants.colReportAccountId},
               r.${DatabaseConstants.colReportAnalyzedAt},
               r.${DatabaseConstants.colReportSavedAt},
               r.${DatabaseConstants.colReportHasAiAnalysis},
               r.${DatabaseConstants.colReportAiProvider},
               r.${DatabaseConstants.colReportAiModel},
               r.${DatabaseConstants.colReportFindingsCount},
               r.${DatabaseConstants.colReportOutcomeState},
               r.${DatabaseConstants.colReportPreviewText},
               s.${DatabaseConstants.colSnapshotInputSource}
        FROM ${DatabaseConstants.tableReports} r
        JOIN ${DatabaseConstants.tableSnapshots} s
          ON r.${DatabaseConstants.colReportSnapshotId} = s.${DatabaseConstants.colSnapshotId}
        WHERE $whereClause
        ORDER BY r.${DatabaseConstants.colReportSavedAt} DESC
        LIMIT ? OFFSET ?
      ''';

      final rows = await db.rawQuery(sql, [...whereArgs, limit, offset]);

      final summaries = rows.map((row) {
        return SavedReportSummary(
          id: row[DatabaseConstants.colReportId] as String,
          schemaVersion: row[DatabaseConstants.colReportSchemaVersion] as int,
          snapshotId: row[DatabaseConstants.colReportSnapshotId] as String,
          accountId: row[DatabaseConstants.colReportAccountId] as String?,
          inputSource: InputSource.values.byName(
            row[DatabaseConstants.colSnapshotInputSource] as String,
          ),
          analyzedAt: DateTime.parse(
            row[DatabaseConstants.colReportAnalyzedAt] as String,
          ).toUtc(),
          savedAt: DateTime.parse(
            row[DatabaseConstants.colReportSavedAt] as String,
          ).toUtc(),
          hasAiAnalysis:
              (row[DatabaseConstants.colReportHasAiAnalysis] as int) == 1,
          aiProvider: row[DatabaseConstants.colReportAiProvider] as String?,
          aiModel: row[DatabaseConstants.colReportAiModel] as String?,
          findingsCount: row[DatabaseConstants.colReportFindingsCount] as int,
          outcomeState: AssessmentOutcomeState.values.byName(
            row[DatabaseConstants.colReportOutcomeState] as String,
          ),
          previewText: row[DatabaseConstants.colReportPreviewText] as String,
        );
      }).toList();

      return Result.success(summaries);
    } on DatabaseException catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Database error while retrieving summaries: ${e.toString()}',
        ),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Unexpected error while retrieving summaries: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Result<bool>> deleteReport(String id) async {
    final db = _db;
    if (db == null || !db.isOpen) {
      return const Result.failure(
        AnalysisFailure.storage(
          'Database is not initialized. Call initialize() first.',
        ),
      );
    }

    try {
      return await db.transaction<Result<bool>>((txn) async {
        final existing = await txn.query(
          DatabaseConstants.tableReports,
          columns: [DatabaseConstants.colReportSnapshotId],
          where: '${DatabaseConstants.colReportId} = ?',
          whereArgs: [id],
        );

        if (existing.isEmpty) {
          return const Result.success(false);
        }

        final snapshotId =
            existing.first[DatabaseConstants.colReportSnapshotId] as String;

        // 1. Delete the report record
        await txn.delete(
          DatabaseConstants.tableReports,
          where: '${DatabaseConstants.colReportId} = ?',
          whereArgs: [id],
        );

        // 2. Check if the snapshot is referenced by any remaining reports
        final remaining = await txn.query(
          DatabaseConstants.tableReports,
          columns: [DatabaseConstants.colReportId],
          where: '${DatabaseConstants.colReportSnapshotId} = ?',
          whereArgs: [snapshotId],
          limit: 1,
        );

        // 3. Prune orphan snapshot if no longer referenced
        if (remaining.isEmpty) {
          await txn.delete(
            DatabaseConstants.tableSnapshots,
            where: '${DatabaseConstants.colSnapshotId} = ?',
            whereArgs: [snapshotId],
          );
        }

        return const Result.success(true);
      });
    } on DatabaseException catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Database error while deleting report: ${e.toString()}',
        ),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Unexpected error while deleting report: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Result<int>> getReportCount({String? accountId}) async {
    final db = _db;
    if (db == null || !db.isOpen) {
      return const Result.failure(
        AnalysisFailure.storage(
          'Database is not initialized. Call initialize() first.',
        ),
      );
    }

    try {
      final String whereClause;
      final List<dynamic> whereArgs;

      if (accountId == null) {
        whereClause = '${DatabaseConstants.colReportAccountId} IS NULL';
        whereArgs = [];
      } else {
        whereClause = '${DatabaseConstants.colReportAccountId} = ?';
        whereArgs = [accountId];
      }

      final count = Sqflite.firstIntValue(
        await db.query(
          DatabaseConstants.tableReports,
          columns: ['COUNT(*)'],
          where: whereClause,
          whereArgs: whereArgs,
        ),
      );

      return Result.success(count ?? 0);
    } on DatabaseException catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Database error while counting reports: ${e.toString()}',
        ),
      );
    } catch (e) {
      return Result.failure(
        AnalysisFailure.storage(
          'Unexpected error while counting reports: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
