import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/rule_registry.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_registry.dart';

import 'account_threat_rule.dart';
import 'credential_request_rule.dart';
import 'payment_request_rule.dart';
import 'urgency_rule.dart';
import 'verification_code_request_rule.dart';

/// Central factory and catalog for Module 23's core warning-indicator rules.
///
/// Provides deterministic English-language heuristic rules for:
/// - `urgency_or_pressure` ([UrgencyRule])
/// - `requests_for_credentials` ([CredentialRequestRule])
/// - `requests_for_verification_codes` ([VerificationCodeRequestRule])
/// - `requests_for_payment` ([PaymentRequestRule])
/// - `account_suspension_or_threats` ([AccountThreatRule])
///
/// Suitable for direct dependency injection into [LocalRuleEngine] and extension in Module 24.
class CoreWarningRuleCatalog {
  const CoreWarningRuleCatalog._();

  /// Creates fresh instances of all core warning rules.
  static List<LocalRule> createRules() => [
    UrgencyRule(),
    CredentialRequestRule(),
    VerificationCodeRequestRule(),
    PaymentRequestRule(),
    AccountThreatRule(),
  ];

  /// Creates a populated [RuleRegistry] holding all core warning rules.
  static RuleRegistry createRegistry() => LocalRuleRegistry(createRules());
}
