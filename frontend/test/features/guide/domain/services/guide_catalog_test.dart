import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/guide/domain/services/guide_catalog.dart';

void main() {
  group('GuideCatalog Unit Tests', () {
    test('contains exactly 6 comprehensive reference topics', () {
      final topics = GuideCatalog.getTopics();
      expect(topics.length, equals(6));

      final topicIds = topics.map((t) => t.id).toList();
      expect(
        topicIds,
        equals([
          'start_check',
          'review_prepare',
          'understand_results',
          'save_find_share',
          'account_cloud',
          'troubleshooting',
        ]),
      );

      for (final topic in topics) {
        expect(topic.titleKey, isNotEmpty);
        expect(topic.subtitleKey, isNotEmpty);
        expect(topic.sections, isNotEmpty);
        for (final section in topic.sections) {
          expect(section.titleKey, isNotEmpty);
          expect(section.bodyKey, isNotEmpty);
        }
      }
    });

    test('topics 2, 3, and 5 define custom illustration builders', () {
      final topics = GuideCatalog.getTopics();
      final topic2 = topics.firstWhere((t) => t.id == 'review_prepare');
      final topic3 = topics.firstWhere((t) => t.id == 'understand_results');
      final topic5 = topics.firstWhere((t) => t.id == 'account_cloud');

      expect(topic2.illustrationBuilder, isNotNull);
      expect(topic3.illustrationBuilder, isNotNull);
      expect(topic5.illustrationBuilder, isNotNull);
    });

    test('contains exactly 2 synthetic guided practice examples', () {
      final examples = GuideCatalog.practiceExamples;
      expect(examples.length, equals(2));

      // Example 1: Urgent threat
      final ex1 = examples[0];
      expect(ex1.id, equals('practice_warning_threat'));
      expect(ex1.isWarningSample, isTrue);
      expect(ex1.syntheticText, contains('bank account has been suspended'));
      expect(ex1.syntheticText, contains('login credentials'));
      expect(ex1.expectedRuleIds.length, equals(3));

      // Example 2: Calm benign
      final ex2 = examples[1];
      expect(ex2.id, equals('practice_benign_friendly'));
      expect(ex2.isWarningSample, isFalse);
      expect(ex2.syntheticText, contains('bring groceries home'));
      expect(ex2.expectedRuleIds, isEmpty);
    });
  });
}
