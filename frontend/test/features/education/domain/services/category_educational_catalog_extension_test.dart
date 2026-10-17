import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/category_educational_catalog.dart';

void main() {
  group('CategoryEducationalCatalog EducationalTopic Extension Tests', () {
    test(
      'provides all 10 canonical EducationalTopic entries with rich content',
      () {
        final topics = CategoryEducationalCatalog.getAllTopics();
        expect(topics.length, equals(10));

        for (final topic in topics) {
          expect(topic.id, startsWith('edu.'));
          expect(topic.categoryId, isNotEmpty);
          expect(topic.title, isNotEmpty);
          expect(topic.whatObserved, isNotEmpty);
          expect(topic.whyAttention, isNotEmpty);
          expect(topic.whatCannotEstablish, isNotEmpty);
          expect(topic.independentVerificationStep, isNotEmpty);
          expect(topic.syntheticSuspiciousExample, isNotEmpty);
          expect(topic.contrastingOrdinaryExample, isNotEmpty);
          expect(topic.contrastingExplanation, isNotEmpty);
          expect(topic.primarySourceTitle, isNotEmpty);
          expect(topic.primarySourceUrl, startsWith('https://'));
          expect(topic.reviewDate, equals('October 2026'));
        }
      },
    );

    test('retrieves matching EducationalTopic for every IndicatorCategory', () {
      for (final category in IndicatorCategory.values) {
        final topic = CategoryEducationalCatalog.getTopic(category.id);
        expect(topic.categoryId, equals(category.id));
        expect(topic.syntheticSuspiciousExample, isNotEmpty);
        expect(topic.contrastingOrdinaryExample, isNotEmpty);
      }
    });

    test('returns neutral fallback for uncataloged category', () {
      final fallback = CategoryEducationalCatalog.getTopic('custom_cat_xyz');
      expect(fallback.categoryId, equals('custom_cat_xyz'));
      expect(fallback.title, equals('Uncataloged indicator'));
      expect(
        fallback.whatCannotEstablish,
        contains('does not have specific heuristic guidance'),
      );
      expect(fallback.syntheticSuspiciousExample, contains('custom_cat_xyz'));
    });
  });
}
