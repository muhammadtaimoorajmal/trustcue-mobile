import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/export/data/services/export_storage_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/privacy/presentation/controllers/privacy_controller.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_preferences.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_service.dart';
import 'package:trustcue_mobile/features/reports/domain/models/retention_policy.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

import '../../../auth/mocks/fake_auth_repository.dart';
import '../../../reports/mocks/fake_report_repository.dart';

class FakeExportStorageService implements ExportStorageService {
  int cleanedCount = 0;

  @override
  Future<int> cleanupAllExports({
    bool force = false,
    Duration activeGraceDuration = Duration.zero,
  }) async => cleanedCount;

  @override
  Future<int> pruneOldExports({
    Duration maxAge = const Duration(hours: 2),
  }) async => 0;

  @override
  Future<File> writePdfReport(Uint8List bytes, {DateTime? timestamp}) =>
      throw UnimplementedError();

  @override
  Future<File> writePlainTextReport(String content, {DateTime? timestamp}) =>
      throw UnimplementedError();

  @override
  void acquireLease(String filePath) {}

  @override
  void releaseLease(String filePath) {}

  @override
  bool isLeased(String filePath) => false;
}

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
  group('PrivacyController Tests', () {
    late FakeReportRepository fakeRepo;
    late FakeRetentionPreferences fakePrefs;
    late RetentionService retentionService;
    late PrivacyController controller;

    final now = DateTime.utc(2026, 10, 16, 12, 0, 0);

    SavedReport createSampleReport({required String id, String? accountId}) {
      final snapshot = TextSnapshot(
        id: 'snap-$id',
        text: 'Content $id',
        source: InputSource.messageText,
        createdAt: now,
      );
      final localReport = AnalysisReport(
        id: id,
        snapshot: snapshot,
        analyzedAt: now,
        findings: const [],
        limitations: const ['Test heuristic coverage'],
        suggestedActions: const ['Verify sender'],
      );
      return SavedReport(
        id: id,
        snapshot: snapshot,
        accountId: accountId,
        analyzedAt: now,
        savedAt: now,
        localReport: localReport,
      );
    }

    setUp(() {
      Get.testMode = true;
      Get.reset();

      fakeRepo = FakeReportRepository();
      fakePrefs = FakeRetentionPreferences();
      retentionService = RetentionService(
        preferences: fakePrefs,
        repository: fakeRepo,
      );

      controller = PrivacyController(
        repository: fakeRepo,
        retentionService: retentionService,
      );
    });

    tearDown(() {
      Get.reset();
    });

    test(
      'initializes with default never policy and 0 counts when empty',
      () async {
        await controller.loadStatus();

        expect(controller.currentPolicy.value, equals(RetentionPolicy.never));
        expect(controller.accountReportCount.value, equals(0));
        expect(controller.guestReportCount.value, equals(0));
        expect(controller.isAuthenticated, isFalse);
      },
    );

    test(
      'loads guest report counts correctly without authenticated user',
      () async {
        await fakeRepo.saveReport(createSampleReport(id: 'rep-g1'));
        await fakeRepo.saveReport(createSampleReport(id: 'rep-g2'));

        await controller.loadStatus();

        expect(controller.guestReportCount.value, equals(2));
        expect(controller.accountReportCount.value, equals(0));
      },
    );

    test('updates retention policy through controller', () async {
      await controller.setRetentionPolicy(RetentionPolicy.days60);

      expect(controller.currentPolicy.value, equals(RetentionPolicy.days60));
      expect(
        await fakePrefs.getRetentionPolicy(),
        equals(RetentionPolicy.days60),
      );
    });

    test(
      'tracks authenticated state and counts when AuthController is registered',
      () async {
        final fakeAuth = FakeAuthRepository();
        final authController = AuthController(authRepository: fakeAuth);
        Get.put<AuthController>(authController);

        final user = AuthUser(
          id: 'acc-uuid-999',
          email: 'user@example.com',
          emailVerified: true,
        );
        fakeAuth.setStatus(AuthStatus.authenticated, user: user);
        authController.user.value = user;
        authController.status.value = AuthStatus.authenticated;

        await fakeRepo.saveReport(
          createSampleReport(id: 'rep-a1', accountId: 'acc-uuid-999'),
        );
        await fakeRepo.saveReport(
          createSampleReport(id: 'rep-g1', accountId: null),
        );

        await controller.loadStatus();

        expect(controller.isAuthenticated, isTrue);
        expect(controller.currentAccountId, equals('acc-uuid-999'));
        expect(controller.accountReportCount.value, equals(1));
        expect(controller.guestReportCount.value, equals(1));
      },
    );

    test(
      'clearTemporaryFiles cleans up export files and reports status',
      () async {
        final fakeExport = FakeExportStorageService();
        fakeExport.cleanedCount = 4;

        final testCtrl = PrivacyController(
          repository: fakeRepo,
          retentionService: retentionService,
          exportStorageService: fakeExport,
        );

        await testCtrl.clearTemporaryFiles();

        expect(testCtrl.isLoading.value, isFalse);
      },
    );
  });
}
