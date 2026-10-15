import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/analysis/presentation/screens/analysis_results_screen.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import '../controllers/analysis_results_controller_persistence_test.dart';

void main() {
  group('AnalysisResultsScreen Persistence UI Tests', () {
    late LocalAnalysisPipeline pipeline;
    late TextSnapshot snapshot;
    late ReviewedTextResult reviewResult;
    late FakeLocalReportRepository fakeReportRepo;

    setUp(() {
      Get.reset();

      final registry = LocalRuleCatalog.createRegistry();
      final engine = LocalRuleEngine(registry: registry);
      final synthesizer = LocalAssessmentSynthesizer();
      pipeline = LocalAnalysisPipeline(
        engine: engine,
        synthesizer: synthesizer,
        registry: registry,
      );

      snapshot = TextSnapshot(
        id: 'snap-ui-001',
        text: 'Urgent: Wire \$1000 right now to prevent account closure.',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      reviewResult = ReviewedTextResult(
        snapshot: snapshot,
        sourceSnapshotId: 'src-1',
        sourceRevision: 'rev-1',
        reviewedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      fakeReportRepo = FakeLocalReportRepository();
    });

    tearDown(() {
      Get.reset();
    });

    Widget createTestApp(AnalysisResultsController controller) {
      Get.put<AnalysisResultsController>(controller);
      return const GetMaterialApp(home: AnalysisResultsScreen());
    }

    testWidgets('renders Save on this device button initially and handles tap', (
      tester,
    ) async {
      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: reviewResult),
        reportRepository: fakeReportRepo,
      );

      await tester.pumpWidget(createTestApp(controller));
      await tester.pumpAndSettle();

      // Verify "Save on this device" button is present
      final saveButton = find.text('Save on this device');
      expect(saveButton, findsOneWidget);

      // Scroll into view before tap
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Should now show "Saved on this device" banner
      final savedBanner = find.text('Saved on this device');
      await tester.ensureVisible(savedBanner);
      await tester.pumpAndSettle();

      expect(savedBanner, findsOneWidget);
      expect(
        find.text(
          'Only reviewed text and findings are stored locally on your device.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders error banner and retry button on save failure', (
      tester,
    ) async {
      fakeReportRepo.shouldFailSave = true;
      fakeReportRepo.failureMessage =
          'Disk write failed due to simulated low storage.';

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: reviewResult),
        reportRepository: fakeReportRepo,
      );

      await tester.pumpWidget(createTestApp(controller));
      await tester.pumpAndSettle();

      final saveButton = find.text('Save on this device');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify failure banner is displayed
      final retryButton = find.text('Retry saving to device');
      await tester.ensureVisible(retryButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Disk write failed due to simulated low storage.'),
        findsOneWidget,
      );
      expect(retryButton, findsOneWidget);

      // Resolve failure and tap retry
      fakeReportRepo.shouldFailSave = false;
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      final savedBanner = find.text('Saved on this device');
      await tester.ensureVisible(savedBanner);
      await tester.pumpAndSettle();

      expect(savedBanner, findsOneWidget);
    });

    testWidgets('renders saving state while persistence write is executing', (
      tester,
    ) async {
      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: reviewResult),
        reportRepository: fakeReportRepo,
      );

      await tester.pumpWidget(createTestApp(controller));
      await tester.pumpAndSettle();

      // Artificially set saving status to verify UI presentation
      controller.saveStatus.value = ReportSaveStatus.saving;
      await tester.pump();

      expect(find.text('Saving to device...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
