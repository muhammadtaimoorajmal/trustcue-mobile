import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_preferences.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_service.dart';
import 'package:trustcue_mobile/features/reports/domain/models/retention_policy.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

import '../../mocks/fake_report_repository.dart';

class FakeRetentionPreferences implements RetentionPreferences {
  RetentionPolicy policy = RetentionPolicy.never;

  @override
  Future<RetentionPolicy> getRetentionPolicy() async => policy;

  @override
  Future<void> setRetentionPolicy(RetentionPolicy newPolicy) async {
    policy = newPolicy;
  }
}

void main() {
  group('RetentionService Tests', () {
    late FakeRetentionPreferences fakePreferences;
    late FakeReportRepository fakeRepository;
    late RetentionService retentionService;

    final baseTime = DateTime.utc(2026, 10, 16, 12, 0, 0);

    SavedReport createSampleReport({
      required String id,
      required DateTime savedAt,
      String? accountId,
    }) {
      final snapshot = TextSnapshot(
        id: 'snap-$id',
        text: 'Content $id',
        source: InputSource.messageText,
        createdAt: savedAt,
      );
      final localReport = AnalysisReport(
        id: id,
        snapshot: snapshot,
        analyzedAt: savedAt,
        findings: const [],
        limitations: const ['Test heuristic coverage'],
        suggestedActions: const ['Verify sender'],
      );
      return SavedReport(
        id: id,
        snapshot: snapshot,
        accountId: accountId,
        analyzedAt: savedAt,
        savedAt: savedAt,
        localReport: localReport,
      );
    }

    setUp(() {
      fakePreferences = FakeRetentionPreferences();
      fakeRepository = FakeReportRepository();
      retentionService = RetentionService(
        preferences: fakePreferences,
        repository: fakeRepository,
      );
    });

    test('default policy is never and does not prune reports', () async {
      final oldReport = createSampleReport(
        id: 'rep-old',
        savedAt: baseTime.subtract(const Duration(days: 45)),
      );
      await fakeRepository.saveReport(oldReport);

      final policy = await retentionService.getPolicy();
      expect(policy, equals(RetentionPolicy.never));

      final pruneResult = await retentionService.pruneExpiredReports(
        now: baseTime,
      );
      expect(pruneResult.isSuccess, isTrue);
      expect(pruneResult.valueOrNull, equals(0));

      final count = await fakeRepository.getReportCount();
      expect(count.valueOrNull, equals(1));
    });

    test('updates and persists retention policy correctly', () async {
      await retentionService.setPolicy(RetentionPolicy.days30);
      expect(
        await retentionService.getPolicy(),
        equals(RetentionPolicy.days30),
      );

      await retentionService.setPolicy(RetentionPolicy.days90);
      expect(
        await retentionService.getPolicy(),
        equals(RetentionPolicy.days90),
      );
    });

    test('prunes reports older than 30 days when policy is days30', () async {
      await retentionService.setPolicy(RetentionPolicy.days30);

      final expiredReport = createSampleReport(
        id: 'rep-expired',
        savedAt: baseTime.subtract(const Duration(days: 35)),
      );
      final validReport = createSampleReport(
        id: 'rep-valid',
        savedAt: baseTime.subtract(const Duration(days: 10)),
      );

      await fakeRepository.saveReport(expiredReport);
      await fakeRepository.saveReport(validReport);

      final pruneResult = await retentionService.pruneExpiredReports(
        now: baseTime,
        includeGuest: true,
      );

      expect(pruneResult.isSuccess, isTrue);
      expect(pruneResult.valueOrNull, equals(1));

      final summaries = await fakeRepository.searchReportSummaries(query: '');
      final remaining = summaries.valueOrNull!;
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('rep-valid'));
    });

    test('respects accountId scoping during pruning', () async {
      await retentionService.setPolicy(RetentionPolicy.days30);

      final accountReport = createSampleReport(
        id: 'rep-acc',
        savedAt: baseTime.subtract(const Duration(days: 40)),
        accountId: 'acc-123',
      );
      final guestReport = createSampleReport(
        id: 'rep-guest',
        savedAt: baseTime.subtract(const Duration(days: 40)),
        accountId: null,
      );

      await fakeRepository.saveReport(accountReport);
      await fakeRepository.saveReport(guestReport);

      // Prune only for account-123 without guest
      final pruneResult = await retentionService.pruneExpiredReports(
        now: baseTime,
        currentAccountId: 'acc-123',
        includeGuest: false,
      );

      expect(pruneResult.isSuccess, isTrue);
      expect(pruneResult.valueOrNull, equals(1));

      // Guest report should still exist
      final guestReportCheck = await fakeRepository.getReportById('rep-guest');
      expect(guestReportCheck.valueOrNull, isNotNull);

      // Account report should be pruned
      final accountReportCheck = await fakeRepository.getReportById('rep-acc');
      expect(accountReportCheck.valueOrNull, isNull);
    });

    test('protects against clock backward anomaly without data loss', () async {
      await retentionService.setPolicy(RetentionPolicy.days30);

      final report = createSampleReport(
        id: 'rep-1',
        savedAt: baseTime.subtract(const Duration(days: 10)),
      );
      await fakeRepository.saveReport(report);

      final result = await retentionService.pruneExpiredReports(now: baseTime);
      expect(result.isSuccess, isTrue);
    });

    test('handles repository errors gracefully', () async {
      await retentionService.setPolicy(RetentionPolicy.days30);
      fakeRepository.shouldFailDelete = true;
      fakeRepository.failureMessage = 'Disk I/O error';

      final result = await retentionService.pruneExpiredReports(now: baseTime);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('Disk I/O error'));
    });
  });
}
