import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/feedback/domain/contracts/feedback_repository.dart';
import 'package:trustcue_mobile/features/feedback/domain/models/app_feedback.dart';
import 'package:trustcue_mobile/features/feedback/presentation/controllers/feedback_controller.dart';
import 'package:trustcue_mobile/features/feedback/presentation/widgets/feedback_dialog.dart';
import 'package:trustcue_mobile/features/localization/presentation/translations/app_translations.dart';

class _MockFeedbackRepository implements FeedbackRepository {
  final List<AppFeedback> items = [];

  @override
  Future<void> saveFeedback(AppFeedback feedback) async {
    items.add(feedback);
  }

  @override
  Future<List<AppFeedback>> getAllFeedback({
    int limit = 50,
    int offset = 0,
  }) async {
    return items.skip(offset).take(limit).toList();
  }

  List<AppFeedback> getFeedbackForTarget({
    required FeedbackTargetType targetType,
    required String targetId,
  }) {
    return items
        .where((f) => f.targetType == targetType && f.targetId == targetId)
        .toList();
  }

  @override
  Future<int> getFeedbackCount() async => items.length;

  @override
  Future<void> clearAllFeedback() async => items.clear();
}

void main() {
  tearDown(() {
    Get.reset();
  });

  Widget buildTestHost({
    required FeedbackRepository repository,
    required VoidCallback onOpen,
  }) {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Get.put<FeedbackController>(
                FeedbackController(
                  repository: repository,
                  idGenerator: () => 'fb_mock_123',
                ),
              );
              onOpen();
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    );
  }

  group('FeedbackDialog UI Tests', () {
    testWidgets('renders non-reporting notice, ratings, and boundaries', (
      tester,
    ) async {
      final repo = _MockFeedbackRepository();

      await tester.pumpWidget(
        buildTestHost(
          repository: repo,
          onOpen: () {
            FeedbackDialog.show(
              Get.context!,
              targetType: FeedbackTargetType.educationTopic,
              targetId: 'edu.urgency',
              targetTitle: 'Urgency Pattern',
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Was this helpful?'), findsOneWidget);
      expect(find.text('Urgency Pattern'), findsOneWidget);

      // Non-reporting authority disclaimer
      expect(
        find.text(
          'TrustCue is an educational tool, not a law enforcement agency or reporting authority. Submitting feedback will NOT report a scam to authorities or protect against fraud.',
        ),
        findsOneWidget,
      );

      // Rating options
      expect(find.text('Helpful'), findsOneWidget);
      expect(find.text('Not helpful'), findsOneWidget);
      expect(find.text('Neutral'), findsOneWidget);

      // Action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('validation prevents submit without rating selection', (
      tester,
    ) async {
      final repo = _MockFeedbackRepository();

      await tester.pumpWidget(
        buildTestHost(
          repository: repo,
          onOpen: () {
            FeedbackDialog.show(
              Get.context!,
              targetType: FeedbackTargetType.educationTopic,
              targetId: 'edu.urgency',
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap Save without rating
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please select a rating.'), findsOneWidget);
      expect(repo.items, isEmpty);
    });

    testWidgets(
      'submitting rating, reason chip, and comment saves to local repository and displays confirmation',
      (tester) async {
        final repo = _MockFeedbackRepository();

        await tester.pumpWidget(
          buildTestHost(
            repository: repo,
            onOpen: () {
              FeedbackDialog.show(
                Get.context!,
                targetType: FeedbackTargetType.educationTopic,
                targetId: 'edu.urgency',
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Select Helpful
        await tester.tap(find.text('Helpful'));
        await tester.pumpAndSettle();

        // Reason chips for Helpful should appear
        expect(find.text('Clear explanation'), findsOneWidget);
        await tester.tap(find.text('Clear explanation'));
        await tester.pumpAndSettle();

        // Enter optional comment
        final commentField = find.byType(TextField);
        await tester.enterText(
          commentField,
          'This explanation helped clarify urgency deadlines.',
        );
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Verification of save
        expect(repo.items.length, equals(1));
        final saved = repo.items.first;
        expect(saved.id, equals('fb_mock_123'));
        expect(saved.targetType, equals(FeedbackTargetType.educationTopic));
        expect(saved.targetId, equals('edu.urgency'));
        expect(saved.rating, equals(FeedbackRating.helpful));
        expect(saved.reasonChip, equals(FeedbackReasonChip.clearExplanation));
        expect(
          saved.comment,
          equals('This explanation helped clarify urgency deadlines.'),
        );

        // UI displays local confirmation
        expect(
          find.text('Feedback saved locally on this device.'),
          findsOneWidget,
        );
        expect(
          find.text('Your feedback is stored anonymously on this device only.'),
          findsOneWidget,
        );
        expect(find.text('Close'), findsOneWidget);

        // Tap Close to dismiss
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(
          find.text('Feedback saved locally on this device.'),
          findsNothing,
        );
      },
    );
  });
}
