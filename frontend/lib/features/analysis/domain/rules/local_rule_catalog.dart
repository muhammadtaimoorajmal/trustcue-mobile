import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/rule_registry.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_registry.dart';

import 'claimed_identity_rule.dart';
import 'core_warning_rule_catalog.dart';
import 'investment_return_rule.dart';
import 'job_offer_rule.dart';
import 'link_structural_rule.dart';
import 'reward_claim_rule.dart';

/// Central catalog and factory composing all on-device scam indicator rules
/// across Module 23 (core warning pack) and Module 24 (extended rule pack).
///
/// Features 10 distinct rule implementations covering all 10 [IndicatorCategory]
/// taxonomy families with zero duplicate registrations.
class LocalRuleCatalog {
  const LocalRuleCatalog._();

  /// Creates fresh instances of the 5 core warning rules (Module 23).
  static List<LocalRule> createCoreRules() =>
      CoreWarningRuleCatalog.createRules();

  /// Creates fresh instances of the 5 extended indicator rules (Module 24).
  static List<LocalRule> createExtendedRules() => [
    ClaimedIdentityRule(),
    JobOfferRule(),
    RewardClaimRule(),
    InvestmentReturnRule(),
    LinkStructuralRule(),
  ];

  /// Composes all 10 registered indicator rules from both packs without duplication.
  static List<LocalRule> createAllRules() => [
    ...createCoreRules(),
    ...createExtendedRules(),
  ];

  /// Creates a populated [RuleRegistry] containing all 10 on-device indicator rules.
  static RuleRegistry createRegistry() => LocalRuleRegistry(createAllRules());

  /// Creates a populated [RuleRegistry] containing only the 5 extended rules.
  static RuleRegistry createExtendedRegistry() =>
      LocalRuleRegistry(createExtendedRules());
}
