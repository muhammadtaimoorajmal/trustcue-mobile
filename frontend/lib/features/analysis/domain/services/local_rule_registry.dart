import '../contracts/local_rule.dart';
import '../contracts/rule_registry.dart';

/// In-memory implementation of [RuleRegistry] maintaining registered local rules.
///
/// Ensures identifier uniqueness and deterministic retrieval order.
class LocalRuleRegistry implements RuleRegistry {
  LocalRuleRegistry([Iterable<LocalRule>? initialRules]) {
    if (initialRules != null) {
      registerAll(initialRules);
    }
  }

  final Map<String, LocalRule> _rules = <String, LocalRule>{};

  @override
  List<LocalRule> get rules => List.unmodifiable(_rules.values);

  @override
  void register(LocalRule rule) {
    final ruleId = rule.id.trim();
    if (ruleId.isEmpty) {
      throw ArgumentError.value(rule.id, 'id', 'Rule ID must not be empty.');
    }
    if (_rules.containsKey(ruleId)) {
      throw ArgumentError(
        'Duplicate rule identifier registered: "$ruleId". Rule IDs must be unique.',
      );
    }
    _rules[ruleId] = rule;
  }

  @override
  void registerAll(Iterable<LocalRule> rules) {
    for (final rule in rules) {
      register(rule);
    }
  }

  @override
  LocalRule? getRule(String id) => _rules[id];

  @override
  bool containsRule(String id) => _rules.containsKey(id);
}
