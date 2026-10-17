import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/category_educational_catalog.dart';
import 'package:trustcue_mobile/features/education/domain/models/educational_topic.dart';
import 'package:trustcue_mobile/features/education/presentation/controllers/education_controller.dart';
import 'package:trustcue_mobile/features/education/presentation/screens/education_topic_detail_screen.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_text_screen.dart';
import 'package:trustcue_mobile/features/localization/presentation/translations/app_translations.dart';

void main() {
  tearDown(() {
    Get.reset();
  });

  final sampleTopic = CategoryEducationalCatalog.getTopic(
    'urgency_or_pressure',
  );

  Widget buildTestApp({
    EducationalTopic? topic,
    InputTextController? inputController,
  }) {
    final targetTopic = topic ?? sampleTopic;

    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      initialRoute: '/entry',
      getPages: [
        GetPage(
          name: '/entry',
          page: () => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Get.toNamed(
                    AppRoutes.educationTopic,
                    arguments: {'topic': targetTopic},
                  );
                },
                child: const Text('Navigate'),
              ),
            ),
          ),
        ),
        GetPage(
          name: AppRoutes.educationTopic,
          page: () => const EducationTopicDetailScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut<EducationController>(() => EducationController());
            if (inputController != null) {
              Get.put<InputTextController>(inputController);
            }
          }),
        ),
        GetPage(name: AppRoutes.inputText, page: () => const InputTextScreen()),
      ],
    );
  }

  Future<void> openTopicScreen(
    WidgetTester tester, {
    EducationalTopic? topic,
    InputTextController? inputController,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildTestApp(topic: topic, inputController: inputController),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Navigate'));
    await tester.pumpAndSettle();
  }

  group('EducationTopicDetailScreen UI Tests', () {
    testWidgets(
      'renders topic details, contrasting example, and primary source',
      (tester) async {
        await openTopicScreen(tester);

        // Header
        expect(find.text('Urgency or artificial pressure'), findsWidgets);

        // Section labels
        expect(find.text('What pattern is observed'), findsOneWidget);
        expect(find.text('Why it deserves attention'), findsOneWidget);
        expect(find.text('What this check cannot establish'), findsOneWidget);

        // Examples
        expect(find.text('Synthetic practice example'), findsOneWidget);
        expect(
          find.text(sampleTopic.syntheticSuspiciousExample),
          findsOneWidget,
        );

        // Scroll down to see contrasting example & citation
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();

        expect(find.text('Contrasting ordinary example'), findsOneWidget);
        expect(
          find.text(sampleTopic.contrastingOrdinaryExample),
          findsOneWidget,
        );

        // Scroll further
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Practical independent verification steps'),
          findsOneWidget,
        );
        expect(find.text(sampleTopic.primarySourceTitle), findsOneWidget);
        expect(find.text('Was this topic helpful?'), findsOneWidget);
      },
    );

    testWidgets(
      'Practice with this example populates InputTextController directly when no draft exists',
      (tester) async {
        final inputController = InputTextController();
        await openTopicScreen(tester, inputController: inputController);

        expect(inputController.textEditingController.text, isEmpty);

        // Find "Practice with this example" button and scroll to it
        final practiceBtn = find.text('Practice with this example');
        await tester.ensureVisible(practiceBtn);
        await tester.pumpAndSettle();

        await tester.tap(practiceBtn);
        await tester.pumpAndSettle();

        // Navigated to InputTextScreen and text populated
        expect(find.byType(InputTextScreen), findsOneWidget);
        expect(
          inputController.textEditingController.text,
          equals(sampleTopic.syntheticSuspiciousExample),
        );
      },
    );

    testWidgets(
      'Practice with this example shows DraftReplacementDialog when active draft exists and preserves when cancelled',
      (tester) async {
        final inputController = InputTextController();
        inputController.textEditingController.text =
            'My existing custom message';
        await openTopicScreen(tester, inputController: inputController);

        final practiceBtn = find.text('Practice with this example');
        await tester.ensureVisible(practiceBtn);
        await tester.pumpAndSettle();

        await tester.tap(practiceBtn);
        await tester.pumpAndSettle();

        // Draft replacement warning dialog shown
        expect(find.text('Replace current draft?'), findsOneWidget);
        expect(
          find.text(
            'You have text entered in the review input. Replacing it will overwrite your draft with this educational example.',
          ),
          findsOneWidget,
        );

        // Tap "Keep Existing Draft"
        final keepBtn = find.text('Keep Existing Draft');
        expect(keepBtn, findsOneWidget);
        await tester.tap(keepBtn);
        await tester.pumpAndSettle();

        // Dialog dismissed, text preserved, still on detail screen
        expect(find.text('Replace current draft?'), findsNothing);
        expect(
          inputController.textEditingController.text,
          equals('My existing custom message'),
        );
        expect(find.byType(EducationTopicDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Practice with this example confirms replacement when user confirms dialog',
      (tester) async {
        final inputController = InputTextController();
        inputController.textEditingController.text = 'My existing draft';
        await openTopicScreen(tester, inputController: inputController);

        final practiceBtn = find.text('Practice with this example');
        await tester.ensureVisible(practiceBtn);
        await tester.pumpAndSettle();

        await tester.tap(practiceBtn);
        await tester.pumpAndSettle();

        // Confirm replacement
        final replaceBtn = find.text('Replace Draft');
        expect(replaceBtn, findsOneWidget);
        await tester.tap(replaceBtn);
        await tester.pumpAndSettle();

        // Navigated to InputTextScreen with example loaded
        expect(find.byType(InputTextScreen), findsOneWidget);
        expect(
          inputController.textEditingController.text,
          equals(sampleTopic.syntheticSuspiciousExample),
        );
      },
    );
  });
}
