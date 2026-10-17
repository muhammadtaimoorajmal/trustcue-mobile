import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trustcue_mobile/features/feedback/data/repositories/sqlite_feedback_repository.dart';
import 'package:trustcue_mobile/features/feedback/domain/models/app_feedback.dart';

void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  group('SqliteFeedbackRepository Tests', () {
    late SqliteFeedbackRepository repository;

    setUp(() {
      repository = SqliteFeedbackRepository(
        databaseFactory: databaseFactory,
        customDatabasePath: inMemoryDatabasePath,
      );
    });

    tearDown(() async {
      await repository.close();
    });

    test('initial feedback count is zero', () async {
      final count = await repository.getFeedbackCount();
      expect(count, equals(0));
    });

    test('saves feedback and retrieves it with exact fields', () async {
      final feedback = AppFeedback(
        id: 'fb-101',
        targetType: FeedbackTargetType.educationTopic,
        targetId: 'edu.urgency_or_pressure',
        rating: FeedbackRating.helpful,
        reasonChip: FeedbackReasonChip.clearExplanation,
        comment: 'Very helpful explanation of urgency patterns.',
        createdAt: DateTime.parse('2026-10-17T12:00:00.000Z'),
      );

      await repository.saveFeedback(feedback);

      final count = await repository.getFeedbackCount();
      expect(count, equals(1));

      final items = await repository.getAllFeedback();
      expect(items.length, equals(1));
      expect(items.first.id, equals('fb-101'));
      expect(items.first.targetType, equals(FeedbackTargetType.educationTopic));
      expect(items.first.targetId, equals('edu.urgency_or_pressure'));
      expect(items.first.rating, equals(FeedbackRating.helpful));
      expect(
        items.first.reasonChip,
        equals(FeedbackReasonChip.clearExplanation),
      );
      expect(
        items.first.comment,
        equals('Very helpful explanation of urgency patterns.'),
      );
      expect(
        items.first.createdAt,
        equals(DateTime.parse('2026-10-17T12:00:00.000Z')),
      );
    });

    test('replaces existing feedback entry with same ID', () async {
      final feedback1 = AppFeedback(
        id: 'fb-same-id',
        targetType: FeedbackTargetType.analysisFinding,
        targetId: 'requests_for_payment',
        rating: FeedbackRating.unhelpful,
        reasonChip: FeedbackReasonChip.confusingTerms,
      );
      await repository.saveFeedback(feedback1);

      final feedback2 = AppFeedback(
        id: 'fb-same-id',
        targetType: FeedbackTargetType.analysisFinding,
        targetId: 'requests_for_payment',
        rating: FeedbackRating.helpful,
        reasonChip: FeedbackReasonChip.easyToVerify,
      );
      await repository.saveFeedback(feedback2);

      final count = await repository.getFeedbackCount();
      expect(count, equals(1));

      final items = await repository.getAllFeedback();
      expect(items.first.rating, equals(FeedbackRating.helpful));
      expect(items.first.reasonChip, equals(FeedbackReasonChip.easyToVerify));
    });

    test(
      'orders multiple feedback entries by creation date descending',
      () async {
        final fbOld = AppFeedback(
          id: 'fb-old',
          targetType: FeedbackTargetType.educationTopic,
          targetId: 'edu.urgency_or_pressure',
          rating: FeedbackRating.neutral,
          createdAt: DateTime.parse('2026-10-15T10:00:00.000Z'),
        );
        final fbNew = AppFeedback(
          id: 'fb-new',
          targetType: FeedbackTargetType.appExperience,
          targetId: 'general',
          rating: FeedbackRating.helpful,
          createdAt: DateTime.parse('2026-10-17T10:00:00.000Z'),
        );

        await repository.saveFeedback(fbOld);
        await repository.saveFeedback(fbNew);

        final items = await repository.getAllFeedback();
        expect(items.length, equals(2));
        expect(items[0].id, equals('fb-new'));
        expect(items[1].id, equals('fb-old'));
      },
    );

    test('clearAllFeedback wipes all records cleanly', () async {
      await repository.saveFeedback(
        AppFeedback(
          id: 'fb-1',
          targetType: FeedbackTargetType.educationTopic,
          targetId: 'edu.rewards_or_prizes',
          rating: FeedbackRating.helpful,
        ),
      );
      expect(await repository.getFeedbackCount(), equals(1));

      await repository.clearAllFeedback();
      expect(await repository.getFeedbackCount(), equals(0));
      expect(await repository.getAllFeedback(), isEmpty);
    });

    test('enforces 200 character comment limit on AppFeedback model', () {
      expect(
        () => AppFeedback(
          id: 'fb-overflow',
          targetType: FeedbackTargetType.educationTopic,
          targetId: 'edu.urgency_or_pressure',
          rating: FeedbackRating.helpful,
          comment: 'a' * 201,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
