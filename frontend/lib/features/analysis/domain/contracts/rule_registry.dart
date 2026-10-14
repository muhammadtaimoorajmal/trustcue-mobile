import 'local_rule.dart';

/// Contract for managing and accessing registered deterministic local rules.
abstract class RuleRegistry {
  /// Unmodifiable collection of currently registered local rules.
  List<LocalRule> get rules;

  /// Registers an individual [LocalRule].
  ///
  /// Throws [ArgumentError] if a rule with the same identifier is already registered.
  void register(LocalRule rule);

  /// Registers multiple rules in sequence.
  void registerAll(Iterable<LocalRule> rules);

  /// Retrieves a rule by its identifier, or `null` if not registered.
  LocalRule? getRule(String id);

  /// Returns `true` if a rule with [id] is registered.
  bool containsRule(String id);
}
