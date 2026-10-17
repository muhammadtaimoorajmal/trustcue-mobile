import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:trustcue_mobile/features/feedback/domain/contracts/feedback_repository.dart';
import 'package:trustcue_mobile/features/feedback/domain/models/app_feedback.dart';
import 'package:trustcue_mobile/features/reports/data/database/database_constants.dart';
import 'package:trustcue_mobile/features/reports/data/database/local_database_migrator.dart';

/// SQLite implementation of [FeedbackRepository] storing feedback locally and anonymously.
///
/// Invariants:
/// - 100% offline. Zero network calls.
/// - Does not collect personal data, credentials, or message contents.
/// - Comment field is bounded and sanitized.
class SqliteFeedbackRepository implements FeedbackRepository {
  final Database? _injectedDatabase;
  final DatabaseFactory? _injectedFactory;
  final String? customDatabasePath;
  final LocalDatabaseMigrator migrator;

  Database? _db;

  SqliteFeedbackRepository({
    Database? database,
    DatabaseFactory? databaseFactory,
    this.customDatabasePath,
    this.migrator = const LocalDatabaseMigrator(),
  }) : _injectedDatabase = database,
       _injectedFactory = databaseFactory;

  bool get isOpen => _db != null && _db!.isOpen;

  Future<Database> _getDb() async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    if (_injectedDatabase != null) {
      _db = _injectedDatabase;
      return _db!;
    }

    final factory = _injectedFactory ?? databaseFactory;
    final String dbPath;
    if (customDatabasePath != null) {
      dbPath = customDatabasePath!;
    } else {
      final defaultDatabasesPath = await factory.getDatabasesPath();
      dbPath = p.join(defaultDatabasesPath, DatabaseConstants.databaseName);
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
    return _db!;
  }

  @override
  Future<void> saveFeedback(AppFeedback feedback) async {
    final db = await _getDb();
    await db.insert(
      DatabaseConstants.tableFeedback,
      feedback.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<int> getFeedbackCount() async {
    final db = await _getDb();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableFeedback};',
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<AppFeedback>> getAllFeedback({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _getDb();
    final rows = await db.query(
      DatabaseConstants.tableFeedback,
      orderBy: '${DatabaseConstants.colFeedbackCreatedAt} DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(AppFeedback.fromMap).toList();
  }

  @override
  Future<void> clearAllFeedback() async {
    final db = await _getDb();
    await db.delete(DatabaseConstants.tableFeedback);
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
