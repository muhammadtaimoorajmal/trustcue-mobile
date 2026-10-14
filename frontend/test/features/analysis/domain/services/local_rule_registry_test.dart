import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_registry.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

class _SyntheticTestRule implements LocalRule {
  @override
  final String id;
  @override
  final int version = 1;
  @override
  final IndicatorCategory category = IndicatorCategory.urgencyOrPressure;
  @override
  final List<String> supportedLanguages = const ['en'];
  @override
  final List<String> limitations = const ['Test-only rule.'];

  const _SyntheticTestRule({required this.id});

  @override
  List<AnalysisFinding> evaluate(TextSnapshot snapshot) => const [];
}

void main() {
  group('LocalRuleRegistry Tests', () {
    test('Initial registry is empty', () {
      final registry = LocalRuleRegistry();
      expect(registry.rules, isEmpty);
      expect(registry.containsRule('any'), isFalse);
      expect(registry.getRule('any'), isNull);
    });

    test('Registers unique rules properly', () {
      final registry = LocalRuleRegistry();
      const rule1 = _SyntheticTestRule(id: 'rule.test.1');
      const rule2 = _SyntheticTestRule(id: 'rule.test.2');

      registry.register(rule1);
      registry.register(rule2);

      expect(registry.rules.length, 2);
      expect(registry.containsRule('rule.test.1'), isTrue);
      expect(registry.containsRule('rule.test.2'), isTrue);
      expect(registry.getRule('rule.test.1'), same(rule1));
    });

    test('Rejects duplicate rule identifiers with ArgumentError', () {
      final registry = LocalRuleRegistry();
      const rule = _SyntheticTestRule(id: 'rule.duplicate');
      const duplicateRule = _SyntheticTestRule(id: 'rule.duplicate');

      registry.register(rule);

      expect(
        () => registry.register(duplicateRule),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Duplicate rule identifier registered'),
          ),
        ),
      );
    });

    test('Rejects empty or whitespace rule identifiers', () {
      final registry = LocalRuleRegistry();

      expect(
        () => registry.register(const _SyntheticTestRule(id: '')),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => registry.register(const _SyntheticTestRule(id: '   ')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Rules collection is unmodifiable', () {
      final registry = LocalRuleRegistry();
      registry.register(const _SyntheticTestRule(id: 'rule.one'));

      final list = registry.rules;
      expect(
        () => list.add(const _SyntheticTestRule(id: 'rule.two')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('Initializes with collection of rules safely', () {
      final registry = LocalRuleRegistry([
        const _SyntheticTestRule(id: 'rule.a'),
        const _SyntheticTestRule(id: 'rule.b'),
      ]);

      expect(registry.rules.length, 2);
      expect(registry.containsRule('rule.a'), isTrue);
      expect(registry.containsRule('rule.b'), isTrue);
    });
  });
}
