import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/category_educational_catalog.dart';

void main() {
  group('CategoryEducationalCatalog Canonical Categories Coverage', () {
    test(
      'provides complete educational context for all 10 canonical categories',
      () {
        for (final category in IndicatorCategory.values) {
          final context = CategoryEducationalCatalog.getContext(category.id);

          expect(context.id, 'edu.${category.id}');
          expect(context.categoryId, category.id);
          expect(
            context.whatObserved.isNotEmpty,
            isTrue,
            reason: 'Missing whatObserved for ${category.id}',
          );
          expect(
            context.whyAttention.isNotEmpty,
            isTrue,
            reason: 'Missing whyAttention for ${category.id}',
          );
          expect(
            context.whatCannotEstablish.isNotEmpty,
            isTrue,
            reason: 'Missing whatCannotEstablish for ${category.id}',
          );
          expect(
            context.independentVerificationStep.isNotEmpty,
            isTrue,
            reason: 'Missing independentVerificationStep for ${category.id}',
          );

          // Verify explicit boundary acknowledgement
          expect(
            context.whatCannotEstablish.toLowerCase(),
            anyOf(
              contains('does not determine'),
              contains('does not establish'),
              contains('does not verify'),
              contains('cannot verify'),
              contains('cannot inspect'),
              contains('cannot authenticate'),
              contains('does not assess'),
            ),
            reason:
                'whatCannotEstablish must state limitations for ${category.id}',
          );

          // Verify NO country-specific emergency numbers or invented contacts
          expect(context.independentVerificationStep, isNot(contains('911')));
          expect(context.independentVerificationStep, isNot(contains('999')));
          expect(context.independentVerificationStep, isNot(contains('112')));
          expect(
            context.independentVerificationStep,
            isNot(contains('@trustcue')),
          );
        }
      },
    );

    test('generates expected actions for each canonical category', () {
      for (final category in IndicatorCategory.values) {
        final actions = CategoryEducationalCatalog.getActionsForCategory(
          categoryId: category.id,
          findingIds: ['f-${category.id}-1'],
        );

        expect(
          actions.isNotEmpty,
          isTrue,
          reason: 'Missing actions for ${category.id}',
        );

        for (final action in actions) {
          expect(action.id.startsWith('action.'), isTrue);
          expect(action.title.isNotEmpty, isTrue);
          expect(action.description.isNotEmpty, isTrue);
          expect(action.supportingFindingIds, ['f-${category.id}-1']);
          expect(action.supportingCategoryIds, [category.id]);
        }
      }
    });

    test(
      'credentials and verification codes provide conditional post-actions',
      () {
        final credActions = CategoryEducationalCatalog.getActionsForCategory(
          categoryId: 'requests_for_credentials',
          findingIds: ['f-cred-1'],
        );
        final postCred = credActions
            .where((a) => a.isConditionalPostAction)
            .toList();
        expect(postCred, hasLength(1));
        expect(postCred.first.id, 'action.post_credential_disclosure');
        expect(postCred.first.title, contains('If you already shared'));
        expect(postCred.first.priority, AssessmentActionPriority.conditional);

        final codeActions = CategoryEducationalCatalog.getActionsForCategory(
          categoryId: 'requests_for_verification_codes',
          findingIds: ['f-code-1'],
        );
        final postCode = codeActions
            .where((a) => a.isConditionalPostAction)
            .toList();
        expect(postCode, hasLength(1));
        expect(postCode.first.id, 'action.post_code_disclosure');
        expect(postCode.first.title, contains('If you already shared'));
        expect(postCode.first.priority, AssessmentActionPriority.conditional);
      },
    );

    test('general caution action is available for clean evaluations', () {
      final action = CategoryEducationalCatalog.createGeneralCautionAction();
      expect(action.id, 'action.general_caution');
      expect(action.title, contains('caution'));
      expect(action.supportingFindingIds, isEmpty);
      expect(action.supportingCategoryIds, isEmpty);
      expect(action.priority, AssessmentActionPriority.recommended);
    });
  });

  group('CategoryEducationalCatalog Unknown Category Fallback', () {
    test('provides neutral educational fallback for unknown category IDs', () {
      final context = CategoryEducationalCatalog.getContext(
        'unknown_future_category',
      );

      expect(context.id, 'edu.unknown_indicator');
      expect(context.categoryId, 'unknown_future_category');
      expect(context.whatObserved, contains('unknown_future_category'));
      expect(
        context.whatCannotEstablish,
        contains('does not have specific heuristic guidance'),
      );
      expect(context.independentVerificationStep, contains('Exercise caution'));
    });

    test('generates neutral action for unknown category IDs', () {
      final actions = CategoryEducationalCatalog.getActionsForCategory(
        categoryId: 'unknown_future_category',
        findingIds: ['f-unk-1'],
      );

      expect(actions, hasLength(1));
      expect(actions.first.id, 'action.verify_independently');
      expect(actions.first.supportingFindingIds, ['f-unk-1']);
      expect(actions.first.supportingCategoryIds, ['unknown_future_category']);
    });
  });
}
