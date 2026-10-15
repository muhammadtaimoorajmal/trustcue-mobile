import 'package:trustcue_mobile/features/reports/data/repositories/sqlite_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';

/// Provides application-level access to the local database repository.
class AppDatabase {
  static LocalReportRepository? _instance;

  /// Returns the singleton [LocalReportRepository] instance, lazily initializing if needed.
  static LocalReportRepository getInstance() {
    _instance ??= SqliteReportRepository();
    return _instance!;
  }

  /// Sets or clears the active instance, primarily for unit and widget testing.
  static void setInstance(LocalReportRepository? repository) {
    _instance = repository;
  }
}
