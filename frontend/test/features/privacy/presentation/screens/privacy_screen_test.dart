import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/privacy/presentation/controllers/privacy_controller.dart';
import 'package:trustcue_mobile/features/privacy/presentation/screens/privacy_screen.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_preferences.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_service.dart';
import 'package:trustcue_mobile/features/reports/domain/models/retention_policy.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

import '../../../auth/mocks/fake_auth_repository.dart';
import '../../../reports/mocks/fake_report_repository.dart';

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
  group('PrivacyScreen Widget Tests', () {
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
      Get.put<PrivacyController>(controller);
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('renders all privacy sections and disclosures in guest mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await fakeRepo.saveReport(createSampleReport(id: 'rep-g1'));
      await controller.loadStatus();

      await tester.pumpWidget(const GetMaterialApp(home: PrivacyScreen()));
      await tester.pumpAndSettle();

      // Check AppBar and Title
      expect(find.text('Privacy & Data'), findsOneWidget);

      // Check Privacy Transparency Header
      expect(find.text('Privacy & Data Transparency'), findsOneWidget);

      // Check Data Storage Boundaries
      expect(find.text('Data Storage & Processing Boundaries'), findsOneWidget);
      expect(find.text('What remains on this device'), findsOneWidget);
      expect(find.text('What is sent for AI analysis'), findsOneWidget);
      expect(find.text('What optional cloud backup stores'), findsOneWidget);
      expect(find.text('Deletion semantics'), findsOneWidget);

      // Check Local Retention Card
      expect(find.text('Local Report Retention'), findsOneWidget);
      expect(find.text('Prune Expired Reports Now'), findsOneWidget);

      // Check Local Data Clearing Card
      expect(find.text('Clear Local Data'), findsOneWidget);
      expect(find.text('Clear Temporary Image Cache'), findsOneWidget);
      expect(find.text('Clear Guest Reports (1)'), findsOneWidget);

      // Check Cloud & Account Card
      expect(find.text('Cloud Backup & Account Lifecycle'), findsOneWidget);
      expect(find.text('Cloud Sync: Disabled (Local only)'), findsOneWidget);

      // Check Educational Guidance Card
      expect(find.text('Educational Guidance & Disclosures'), findsOneWidget);
      expect(find.text('Review Safe-Use Guidance'), findsOneWidget);
    });

    testWidgets('renders account report options when authenticated', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuth = FakeAuthRepository();
      final authController = AuthController(authRepository: fakeAuth);
      Get.put<AuthController>(authController);

      final user = AuthUser(
        id: 'acc-uuid-1',
        email: 'user@trustcue.test',
        emailVerified: true,
      );
      fakeAuth.setStatus(AuthStatus.authenticated, user: user);
      authController.user.value = user;
      authController.status.value = AuthStatus.authenticated;

      await fakeRepo.saveReport(
        createSampleReport(id: 'rep-a1', accountId: 'acc-uuid-1'),
      );
      await fakeRepo.saveReport(
        createSampleReport(id: 'rep-g1', accountId: null),
      );
      await controller.loadStatus();

      await tester.pumpWidget(const GetMaterialApp(home: PrivacyScreen()));
      await tester.pumpAndSettle();

      // Account reports button visible
      expect(find.text('Clear Account Reports (1)'), findsOneWidget);
      // Remaining guest reports button also visible
      expect(find.text('Clear Remaining Guest Reports (1)'), findsOneWidget);
      // Stop sync & delete cloud summaries visible
      expect(find.text('Stop Sync & Delete Cloud Summaries'), findsOneWidget);
    });
  });
}
