import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/core_warning_rule_catalog.dart';

void main() {
  group('CoreWarningRuleCatalog', () {
    test('creates 5 core warning rules with distinct IDs', () {
      final rules = CoreWarningRuleCatalog.createRules();

      expect(rules, hasLength(5));
      final ids = rules.map((r) => r.id).toSet();
      expect(ids, hasLength(5), reason: 'Every rule must have a unique ID');

      final categories = rules.map((r) => r.category).toSet();
      expect(categories, contains(IndicatorCategory.urgencyOrPressure));
      expect(categories, contains(IndicatorCategory.requestsForCredentials));
      expect(
        categories,
        contains(IndicatorCategory.requestsForVerificationCodes),
      );
      expect(categories, contains(IndicatorCategory.requestsForPayment));
      expect(
        categories,
        contains(IndicatorCategory.accountSuspensionOrThreats),
      );
    });

    test('creates populated RuleRegistry without ID collisions', () {
      final registry = CoreWarningRuleCatalog.createRegistry();

      expect(registry.rules, hasLength(5));
      expect(registry.getRule('rule.urgency.immediate_action'), isNotNull);
      expect(registry.getRule('rule.credential.disclosure_request'), isNotNull);
      expect(
        registry.getRule('rule.verification_code.disclosure_request'),
        isNotNull,
      );
      expect(registry.getRule('rule.payment.solicitation'), isNotNull);
      expect(registry.getRule('rule.account.threat_or_suspension'), isNotNull);
    });

    test('supports retrieving rules and querying presence', () {
      final registry = CoreWarningRuleCatalog.createRegistry();

      expect(registry.containsRule('rule.urgency.immediate_action'), isTrue);
      expect(registry.containsRule('rule.non_existent'), isFalse);

      final urgencyRules = registry.rules
          .where((r) => r.category == IndicatorCategory.urgencyOrPressure)
          .toList();
      expect(urgencyRules, hasLength(1));
      expect(urgencyRules.first.id, 'rule.urgency.immediate_action');

      final englishRules = registry.rules
          .where((r) => r.supportedLanguages.contains('en'))
          .toList();
      expect(englishRules, hasLength(5));
    });
  });
}
