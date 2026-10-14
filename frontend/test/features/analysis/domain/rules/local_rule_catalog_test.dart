import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';

void main() {
  group('LocalRuleCatalog', () {
    test('creates 5 core rules and 5 extended rules', () {
      final coreRules = LocalRuleCatalog.createCoreRules();
      final extendedRules = LocalRuleCatalog.createExtendedRules();
      final allRules = LocalRuleCatalog.createAllRules();

      expect(coreRules, hasLength(5));
      expect(extendedRules, hasLength(5));
      expect(allRules, hasLength(10));
    });

    test('guarantees all 10 registered rule IDs are globally unique', () {
      final allRules = LocalRuleCatalog.createAllRules();
      final ids = allRules.map((r) => r.id).toSet();
      expect(ids, hasLength(10));
    });

    test('covers all 10 defined IndicatorCategory taxonomy families', () {
      final allRules = LocalRuleCatalog.createAllRules();
      final categories = allRules.map((r) => r.category).toSet();
      expect(categories, hasLength(10));
      expect(categories, containsAll(IndicatorCategory.values));
    });

    test(
      'instantiates complete 10-rule registry without duplicate exceptions',
      () {
        final registry = LocalRuleCatalog.createRegistry();
        expect(registry.rules, hasLength(10));
      },
    );

    test('instantiates 5-rule extended registry cleanly', () {
      final registry = LocalRuleCatalog.createExtendedRegistry();
      expect(registry.rules, hasLength(5));
    });
  });
}
