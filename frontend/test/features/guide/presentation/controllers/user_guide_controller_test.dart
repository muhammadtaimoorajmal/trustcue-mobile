import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/guide/domain/services/guide_catalog.dart';
import 'package:trustcue_mobile/features/guide/presentation/controllers/user_guide_controller.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/review_input.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';
import 'package:trustcue_mobile/features/localization/presentation/translations/app_translations.dart';

void main() {
  tearDown(() {
    Get.reset();
  });

  group('UserGuideController Unit & Navigation Tests', () {
    test('toggles topic expansion state correctly', () {
      final controller = UserGuideController();

      expect(controller.isTopicExpanded('start_check'), isFalse);
      controller.toggleTopic('start_check');
      expect(controller.isTopicExpanded('start_check'), isTrue);
      controller.toggleTopic('start_check');
      expect(controller.isTopicExpanded('start_check'), isFalse);
    });

    testWidgets(
      'launchPractice without active draft navigates to review directly',
      (tester) async {
        ReviewInput? receivedReviewInput;

        await tester.pumpWidget(
          GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            initialRoute: '/guide',
            getPages: [
              GetPage(
                name: '/guide',
                page: () => const Scaffold(body: Text('Guide Screen Mock')),
              ),
              GetPage(
                name: AppRoutes.inputReview,
                page: () {
                  receivedReviewInput = Get.arguments as ReviewInput?;
                  return const Scaffold(body: Text('Review Screen Mock'));
                },
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final controller = UserGuideController();
        final example = GuideCatalog.practiceExamples.first;

        final context = tester.element(find.text('Guide Screen Mock'));
        await controller.launchPractice(example, context);
        await tester.pumpAndSettle();

        expect(find.text('Review Screen Mock'), findsOneWidget);
        expect(receivedReviewInput, isNotNull);
        expect(
          receivedReviewInput!.snapshot.source,
          equals(InputSource.messageText),
        );
        expect(
          receivedReviewInput!.snapshot.text,
          equals(example.syntheticText),
        );
      },
    );

    testWidgets('launchPractice with active draft prompts before replacing', (
      tester,
    ) async {
      ReviewInput? receivedReviewInput;
      final textController = InputTextController();
      textController.textEditingController.text =
          'My existing unsaved draft message';
      Get.put<InputTextController>(textController);

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          initialRoute: '/guide',
          getPages: [
            GetPage(
              name: '/guide',
              page: () => const Scaffold(body: Text('Guide Screen Mock')),
            ),
            GetPage(
              name: AppRoutes.inputReview,
              page: () {
                receivedReviewInput = Get.arguments as ReviewInput?;
                return const Scaffold(body: Text('Review Screen Mock'));
              },
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final controller = UserGuideController();
      final example = GuideCatalog.practiceExamples.first;
      final context = tester.element(find.text('Guide Screen Mock'));

      // Launch practice - should trigger dialog
      controller.launchPractice(example, context);
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.text('Replace active draft?'), findsOneWidget);
      expect(find.text('Keep My Draft'), findsOneWidget);
      expect(find.text('Replace & Start Practice'), findsOneWidget);

      // If user taps cancel, draft is kept and no navigation occurs
      await tester.tap(find.text('Keep My Draft'));
      await tester.pumpAndSettle();

      expect(find.text('Guide Screen Mock'), findsOneWidget);
      expect(receivedReviewInput, isNull);
      expect(
        textController.text.value,
        equals('My existing unsaved draft message'),
      );

      // Now launch again and confirm replacement
      controller.launchPractice(example, context);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Replace & Start Practice'));
      await tester.pumpAndSettle();

      expect(find.text('Review Screen Mock'), findsOneWidget);
      expect(receivedReviewInput, isNotNull);
      expect(receivedReviewInput!.snapshot.text, equals(example.syntheticText));
      expect(textController.text.value, equals(example.syntheticText));
    });
  });
}
