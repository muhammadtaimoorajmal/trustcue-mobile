import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/presentation/controllers/history_controller.dart';
import 'package:trustcue_mobile/features/reports/presentation/screens/history_screen.dart';
import 'package:trustcue_mobile/features/reports/presentation/widgets/history_report_card.dart';

import '../../../auth/mocks/fake_auth_repository.dart';
import '../../mocks/fake_report_repository.dart';

void main() {
  group('HistoryScreen UI Tests', () {
    late FakeReportRepository fakeRepo;
    late FakeAuthRepository fakeAuth;
    late HistoryController controller;

    SavedReport createReport({
      required String id,
      required String text,
      InputSource source = InputSource.messageText,
      DateTime? savedAt,
    }) {
      final snapshot = TextSnapshot(
        id: 'snap-$id',
        text: text,
        source: source,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      final excerpt = text.substring(0, text.length >= 5 ? 5 : text.length);
      final finding = AnalysisFinding(
        id: 'f-$id',
        category: 'urgency',
        explanation: 'Suspicious urgency detected',
        origin: FindingOrigin.localRule,
        producerId: 'rule.urgency',
        evidence: [
          EvidenceReference(
            snapshotId: snapshot.id,
            startOffset: 0,
            endOffset: excerpt.length,
            exactExcerpt: excerpt,
          ),
        ],
      );

      final localReport = AnalysisReport(
        id: id,
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        findings: [finding],
        limitations: const ['Test heuristic coverage'],
        suggestedActions: const ['Verify sender independently'],
      );

      return SavedReport(
        id: id,
        snapshot: snapshot,
        accountId: null,
        analyzedAt: localReport.analyzedAt,
        savedAt: savedAt ?? DateTime.utc(2026, 10, 15, 12, 0, 0),
        localReport: localReport,
      );
    }

    setUp(() {
      Get.reset();
      fakeRepo = FakeReportRepository();
      fakeAuth = FakeAuthRepository();
    });

    tearDown(() {
      Get.reset();
    });

    Widget createTestApp(HistoryController ctrl) {
      Get.put<HistoryController>(ctrl);
      return const GetMaterialApp(home: HistoryScreen());
    }

    testWidgets('renders empty history layout with helpful call-to-action', (
      tester,
    ) async {
      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );

      await tester.pumpWidget(createTestApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Saved Reports'), findsOneWidget);
      expect(find.text('On-device storage'), findsOneWidget);
      expect(find.text('No saved reports yet'), findsOneWidget);
      expect(find.text('Start new check'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Sources'), findsOneWidget);
      expect(find.text('All Checks'), findsOneWidget);
    });

    testWidgets(
      'renders list of saved reports with non-sensitive summary metadata',
      (tester) async {
        await fakeRepo.saveReport(
          createReport(
            id: 'rep-1',
            text: 'Urgent wire transfer needed immediately',
            source: InputSource.messageText,
          ),
        );
        await fakeRepo.saveReport(
          createReport(
            id: 'rep-2',
            text: 'https://fake-login-portal.example.com',
            source: InputSource.link,
          ),
        );

        controller = HistoryController(
          repository: fakeRepo,
          authRepository: fakeAuth,
        );

        await tester.pumpWidget(createTestApp(controller));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryReportCard), findsNWidgets(2));
        expect(
          find.descendant(
            of: find.byType(HistoryReportCard),
            matching: find.text('Text'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(HistoryReportCard),
            matching: find.text('Link'),
          ),
          findsOneWidget,
        );
        expect(find.text('[On-device heuristic]'), findsNWidgets(2));
        expect(find.text('2 saved report(s)'), findsOneWidget);
      },
    );

    testWidgets('filtering by search input updates displayed cards', (
      tester,
    ) async {
      await fakeRepo.saveReport(
        createReport(
          id: 'rep-wire',
          text: 'Urgent wire transfer needed immediately',
        ),
      );
      await fakeRepo.saveReport(
        createReport(
          id: 'rep-lottery',
          text: 'Congratulations! You won 100% free lottery prize!',
        ),
      );

      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );

      await tester.pumpWidget(createTestApp(controller));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryReportCard), findsNWidgets(2));

      // Enter search text
      await tester.enterText(find.byType(TextField), 'lottery');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryReportCard), findsOneWidget);
      expect(
        find.text('Congratulations! You won 100% free lottery prize!'),
        findsOneWidget,
      );
    });

    testWidgets(
      'delete button triggers confirmation dialog and deletes on confirm',
      (tester) async {
        await fakeRepo.saveReport(
          createReport(
            id: 'rep-del',
            text: 'Delete this synthetic test report',
          ),
        );

        controller = HistoryController(
          repository: fakeRepo,
          authRepository: fakeAuth,
        );

        await tester.pumpWidget(createTestApp(controller));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryReportCard), findsOneWidget);

        // Tap delete icon on card
        final deleteIconFinder = find.byTooltip('Delete report from device');
        expect(deleteIconFinder, findsOneWidget);
        await tester.tap(deleteIconFinder);
        await tester.pumpAndSettle();

        // Verify DeleteConfirmationDialog
        expect(find.text('Delete saved report?'), findsOneWidget);
        expect(
          find.textContaining(
            'This removes the saved report from this device.',
          ),
          findsOneWidget,
        );

        // Confirm deletion
        await tester.tap(find.text('Delete from device'));
        await tester.pumpAndSettle();

        // Card is removed and empty state is rendered
        expect(find.byType(HistoryReportCard), findsNothing);
        expect(find.text('No saved reports yet'), findsOneWidget);
      },
    );

    testWidgets('cancelling deletion dialog keeps report intact', (
      tester,
    ) async {
      await fakeRepo.saveReport(
        createReport(
          id: 'rep-keep',
          text: 'Preserve this synthetic test report',
        ),
      );

      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );

      await tester.pumpWidget(createTestApp(controller));
      await tester.pumpAndSettle();

      // Tap delete icon
      await tester.tap(find.byTooltip('Delete report from device'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Keep report'));
      await tester.pumpAndSettle();

      // Card remains intact
      expect(find.byType(HistoryReportCard), findsOneWidget);
      expect(fakeRepo.storage.containsKey('rep-keep'), isTrue);
    });
  });
}
