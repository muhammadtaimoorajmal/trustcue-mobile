/// Constants defining SQLite table, column, and index names for TrustCue local storage.
abstract class DatabaseConstants {
  static const String databaseName = 'trustcue_local.db';
  static const int currentDatabaseVersion = 1;

  // Table: text_snapshots
  static const String tableSnapshots = 'text_snapshots';
  static const String colSnapshotId = 'id';
  static const String colSnapshotText = 'text';
  static const String colSnapshotInputSource = 'input_source';
  static const String colSnapshotCreatedAt = 'created_at';
  static const String colSnapshotSha256 = 'sha256';

  // Table: saved_reports
  static const String tableReports = 'saved_reports';
  static const String colReportId = 'id';
  static const String colReportSchemaVersion = 'schema_version';
  static const String colReportSnapshotId = 'snapshot_id';
  static const String colReportAccountId = 'account_id';
  static const String colReportAnalyzedAt = 'analyzed_at';
  static const String colReportSavedAt = 'created_at';
  static const String colReportHasAiAnalysis = 'has_ai_analysis';
  static const String colReportAiProvider = 'ai_provider';
  static const String colReportAiModel = 'ai_model';
  static const String colReportFindingsCount = 'findings_count';
  static const String colReportOutcomeState = 'outcome_state';
  static const String colReportPreviewText = 'preview_text';
  static const String colReportPayload = 'report_payload';
}
