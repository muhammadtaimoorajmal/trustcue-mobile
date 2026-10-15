import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/presentation/controllers/saved_report_detail_controller.dart';
import 'package:trustcue_mobile/features/reports/presentation/screens/saved_report_detail_screen.dart';

import '../../../auth/mocks/fake_auth_repository.dart';
import '../../mocks/fake_report_repository.dart';

void main() {
  group('SavedReportDetailScreen UI Tests', () {
    late FakeReportRepository fakeRepo;
    late FakeAuthRepository fakeAuth;

    SavedReport createReport({
      required String id,
      required String text,
      InputSource source = InputSource.messageText,
      bool hasAi = false,
    }) {
      final snapshot = TextSnapshot(
        id: 'snap-$id',
        text: text,
        source: source,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      final excerpt = text.substring(0, text.length >= 6 ? 6 : text.length);
      final finding = AnalysisFinding(
        id: 'f-$id',
        category: 'urgency',
        explanation: 'Suspicious urgency detected in text',
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
        limitations: const ['Evaluated standard heuristics.'],
        suggestedActions: const ['Contact sender on known verified channel.'],
      );

      AiAnalysisReport? aiReport;
      if (hasAi) {
        aiReport = AiAnalysisReport(
          reportId: 'ai-$id',
          snapshotId: snapshot.id,
          provider: 'groq-cloud',
          model: 'qwen/qwen3.8-27b',
          analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 5),
          factualSummary: 'AI identified urgent call-to-action.',
          findings: [
            AnalysisFinding(
              id: 'ai-f-$id',
              category: 'urgency',
              explanation: 'Remote model flagged high pressure tactics.',
              origin: FindingOrigin.remoteAi,
              producerId: 'groq-cloud',
              evidence: [
                EvidenceReference(
                  snapshotId: snapshot.id,
                  startOffset: 0,
                  endOffset: excerpt.length,
                  exactExcerpt: excerpt,
                ),
              ],
            ),
          ],
          uncertaintyNotes: const ['Domain registrar unverified.'],
          suggestedActions: const [],
        );
      }

      return SavedReport(
        id: id,
        snapshot: snapshot,
        accountId: null,
        analyzedAt: localReport.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        localReport: localReport,
        aiReport: aiReport,
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

    Widget createTestApp(SavedReportDetailController ctrl) {
      Get.put<SavedReportDetailController>(ctrl);
      return const GetMaterialApp(home: SavedReportDetailScreen());
    }

    testWidgets(
      'renders local report details faithfully with exact snapshot and findings',
      (tester) async {
        final report = createReport(
          id: 'rep-det-local',
          text: 'Urgent: Wire money right away.',
        );
        await fakeRepo.saveReport(report);

        final controller = SavedReportDetailController(
          reportId: 'rep-det-local',
          repository: fakeRepo,
          authRepository: fakeAuth,
        );

        await tester.pumpWidget(createTestApp(controller));
        await tester.pumpAndSettle();

        expect(find.text('Saved Report Details'), findsOneWidget);
        expect(find.text('[On-device heuristic]'), findsOneWidget);
        expect(
          find.text('1 potential warning indicator detected'),
          findsOneWidget,
        );
        expect(find.text('Analyzed text snapshot'), findsOneWidget);
        expect(find.text('Urgent: Wire money right away.'), findsOneWidget);
        expect(find.text('Local on-device findings'), findsOneWidget);
        expect(
          find.text('Suspicious urgency detected in text'),
          findsOneWidget,
        );
        expect(find.text('Evaluated standard heuristics.'), findsOneWidget);
        expect(
          find.text('Contact sender on known verified channel.'),
          findsOneWidget,
        );
        expect(find.text('Delete report from this device'), findsOneWidget);
      },
    );

    testWidgets(
      'renders AI-enriched report with AI badge and factual summary',
      (tester) async {
        final report = createReport(
          id: 'rep-det-ai',
          text: 'Urgent: Wire money right away.',
          hasAi: true,
        );
        await fakeRepo.saveReport(report);

        final controller = SavedReportDetailController(
          reportId: 'rep-det-ai',
          repository: fakeRepo,
          authRepository: fakeAuth,
        );

        await tester.pumpWidget(createTestApp(controller));
        await tester.pumpAndSettle();

        expect(find.text('[AI-Assisted: groq-cloud]'), findsOneWidget);
        expect(find.text('Cloud AI findings (groq-cloud)'), findsOneWidget);
        expect(
          find.text('AI identified urgent call-to-action.'),
          findsOneWidget,
        );
        expect(
          find.text('Remote model flagged high pressure tactics.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'deletion confirmation dialog works from AppBar delete action',
      (tester) async {
        final report = createReport(
          id: 'rep-del-ui',
          text: 'Report to be deleted',
        );
        await fakeRepo.saveReport(report);

        final controller = SavedReportDetailController(
          reportId: 'rep-del-ui',
          repository: fakeRepo,
          authRepository: fakeAuth,
        );

        await tester.pumpWidget(createTestApp(controller));
        await tester.pumpAndSettle();

        final deleteIcon = find.byTooltip('Delete report from device');
        expect(deleteIcon, findsOneWidget);

        await tester.tap(deleteIcon);
        await tester.pumpAndSettle();

        expect(find.text('Delete saved report?'), findsOneWidget);
        expect(
          find.textContaining(
            'This removes the saved report from this device.',
          ),
          findsOneWidget,
        );

        // Cancel
        await tester.tap(find.text('Keep report'));
        await tester.pumpAndSettle();

        expect(fakeRepo.storage.containsKey('rep-del-ui'), isTrue);

        // Tap again and confirm
        await tester.tap(deleteIcon);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete from device'));
        await tester.pumpAndSettle();

        expect(fakeRepo.storage.containsKey('rep-del-ui'), isFalse);
      },
    );
  });
}
