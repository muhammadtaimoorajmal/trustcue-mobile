import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/analysis/presentation/screens/analysis_results_screen.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/review_input.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_review_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_review_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    Get.reset();
  });

  ReviewInput createTestInput(String text) {
    return ReviewInput(
      snapshot: TextSnapshot(
        id: 'snap-intake-1',
        text: text,
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      sourceRevision: 'rev-1',
    );
  }

  Widget createFlowWidget({required ReviewInput input}) {
    final reviewController = InputReviewController(reviewInput: input);
    Get.put<InputReviewController>(reviewController);

    final registry = LocalRuleCatalog.createRegistry();
    final engine = LocalRuleEngine(registry: registry);
    final synthesizer = LocalAssessmentSynthesizer();
    final pipeline = LocalAnalysisPipeline(
      engine: engine,
      synthesizer: synthesizer,
      registry: registry,
    );
    Get.put<LocalAnalysisPipeline>(pipeline);

    return GetMaterialApp(
      initialRoute: AppRoutes.inputReview,
      getPages: [
        GetPage(
          name: AppRoutes.inputReview,
          page: () => const InputReviewScreen(),
        ),
        GetPage(
          name: AppRoutes.analysisResults,
          page: () => const AnalysisResultsScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut<AnalysisResultsController>(
              () => AnalysisResultsController(
                pipeline: Get.find<LocalAnalysisPipeline>(),
                args: Get.arguments is AnalysisResultsArgs
                    ? Get.arguments as AnalysisResultsArgs
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  group('InputReview to Local Analysis Flow Integration', () {
    testWidgets('unconfirmed review cannot start analysis until confirmed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final input = createTestInput(
        'Suspicious message: your password has expired.',
      );
      await tester.pumpWidget(createFlowWidget(input: input));
      await tester.pumpAndSettle();

      // Before confirmation: Analyze button is not present
      expect(find.text('Analyze on this device'), findsNothing);
      expect(find.text('Confirm reviewed text'), findsOneWidget);

      // Tap Confirm
      await tester.ensureVisible(find.text('Confirm reviewed text'));
      await tester.tap(find.text('Confirm reviewed text'));
      await tester.pumpAndSettle();

      // Now "Analyze on this device" and privacy explanation appear
      expect(find.text('Analyze on this device'), findsOneWidget);
      expect(
        find.text(
          'Checks the reviewed text using local rules. Nothing is uploaded.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'editing text invalidates prior confirmation and hides analyze button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final input = createTestInput('Original text to be checked.');
        await tester.pumpWidget(createFlowWidget(input: input));
        await tester.pumpAndSettle();

        // Confirm
        await tester.ensureVisible(find.text('Confirm reviewed text'));
        await tester.tap(find.text('Confirm reviewed text'));
        await tester.pumpAndSettle();
        expect(find.text('Analyze on this device'), findsOneWidget);

        // Edit text in TextField
        await tester.enterText(
          find.byType(TextField),
          'Modified text with new changes.',
        );
        await tester.pumpAndSettle();

        // Analyze button must disappear because confirmation is invalidated!
        expect(find.text('Analyze on this device'), findsNothing);
        expect(find.text('Confirm reviewed text'), findsOneWidget);
      },
    );

    testWidgets(
      'end-to-end: typed message -> review -> local analysis -> real results',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const suspiciousText =
            'CRITICAL: Your bank account is locked. Send your password to unlock immediately.';
        final input = createTestInput(suspiciousText);

        await tester.pumpWidget(createFlowWidget(input: input));
        await tester.pumpAndSettle();

        // Confirm reviewed text
        await tester.ensureVisible(find.text('Confirm reviewed text'));
        await tester.tap(find.text('Confirm reviewed text'));
        await tester.pumpAndSettle();

        // Tap Analyze on this device
        await tester.ensureVisible(find.text('Analyze on this device'));
        await tester.tap(find.text('Analyze on this device'));
        await tester.pumpAndSettle();

        // Verify we arrived on the Analysis Results screen
        expect(Get.currentRoute, AppRoutes.analysisResults);
        expect(find.text('Local on-device analysis'), findsOneWidget);
        expect(
          find.text(
            'Evaluated on this device using local rules. Nothing was uploaded.',
          ),
          findsOneWidget,
        );

        // Verify real indicators detected from real local rules
        expect(find.textContaining('warning indicator'), findsWidgets);
        expect(find.text('Evidence trail'), findsOneWidget);
        expect(find.text('Suggested next steps'), findsOneWidget);

        // Pop back to review screen
        await tester.ensureVisible(find.text('Return to review and edit text'));
        await tester.tap(find.text('Return to review and edit text'));
        await tester.pumpAndSettle();

        expect(Get.currentRoute, AppRoutes.inputReview);
        expect(find.text('Review text'), findsOneWidget);
      },
    );

    testWidgets('duplicate tap protection pushes results route only once', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final input = createTestInput('Verify your code now.');
      await tester.pumpWidget(createFlowWidget(input: input));
      await tester.pumpAndSettle();

      // Confirm
      await tester.ensureVisible(find.text('Confirm reviewed text'));
      await tester.tap(find.text('Confirm reviewed text'));
      await tester.pumpAndSettle();

      final controller = Get.find<InputReviewController>();
      expect(controller.isConfirmed.value, isTrue);

      // Call analyze twice rapidly
      controller.analyzeOnThisDevice();
      controller.analyzeOnThisDevice();
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.analysisResults);
      // System back should return directly to review screen in 1 step
      Get.back();
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.inputReview);
    });
  });
}
