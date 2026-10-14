import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/rule_registry.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';

/// Explicit execution context providing actual execution and scope metadata
/// for local assessment synthesis.
///
/// Guarantees:
/// - Determines coverage from actual execution/configuration information rather
///   than inferring which rules ran solely from findings.
/// - Allows synthesis to distinguish an empty rule catalog from executed checks with zero matches.
/// - Retains optional trusted review/redaction metadata when available.
class AnalysisExecutionContext {
  final List<String> executedRuleIds;
  final List<IndicatorCategory> evaluatedCategories;
  final List<String> skippedRuleIds;
  final ReviewedTextResult? trustedReviewMetadata;

  AnalysisExecutionContext({
    required List<String> executedRuleIds,
    required List<IndicatorCategory> evaluatedCategories,
    List<String> skippedRuleIds = const [],
    this.trustedReviewMetadata,
  }) : executedRuleIds = List.unmodifiable(executedRuleIds),
       evaluatedCategories = List.unmodifiable(evaluatedCategories),
       skippedRuleIds = List.unmodifiable(skippedRuleIds);

  /// Builds execution context by inspecting a [RuleRegistry].
  factory AnalysisExecutionContext.fromRegistry(
    RuleRegistry registry, {
    ReviewedTextResult? reviewResult,
    List<String>? skippedRuleIds,
  }) {
    return AnalysisExecutionContext.fromRules(
      registry.rules,
      reviewResult: reviewResult,
      skippedRuleIds: skippedRuleIds,
    );
  }

  /// Builds execution context from an explicit list of [LocalRule]s.
  factory AnalysisExecutionContext.fromRules(
    List<LocalRule> rules, {
    ReviewedTextResult? reviewResult,
    List<String>? skippedRuleIds,
  }) {
    final executedIds = rules.map((r) => r.id).toList()..sort();
    final categoriesSet = <IndicatorCategory>{};
    for (final rule in rules) {
      categoriesSet.add(rule.category);
    }
    // Sort categories deterministically in canonical enum order
    final categoriesList = categoriesSet.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return AnalysisExecutionContext(
      executedRuleIds: executedIds,
      evaluatedCategories: categoriesList,
      skippedRuleIds: skippedRuleIds ?? const [],
      trustedReviewMetadata: reviewResult,
    );
  }

  /// Builds an empty execution context representing a zero-rule catalog.
  factory AnalysisExecutionContext.empty({ReviewedTextResult? reviewResult}) {
    return AnalysisExecutionContext(
      executedRuleIds: const [],
      evaluatedCategories: const [],
      skippedRuleIds: const [],
      trustedReviewMetadata: reviewResult,
    );
  }

  /// Returns true if no rules were registered in the catalog (both executed and skipped are empty).
  bool get isCatalogEmpty => executedRuleIds.isEmpty && skippedRuleIds.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnalysisExecutionContext) return false;
    if (other.trustedReviewMetadata != trustedReviewMetadata ||
        other.executedRuleIds.length != executedRuleIds.length ||
        other.evaluatedCategories.length != evaluatedCategories.length ||
        other.skippedRuleIds.length != skippedRuleIds.length) {
      return false;
    }
    for (var i = 0; i < executedRuleIds.length; i++) {
      if (executedRuleIds[i] != other.executedRuleIds[i]) return false;
    }
    for (var i = 0; i < evaluatedCategories.length; i++) {
      if (evaluatedCategories[i] != other.evaluatedCategories[i]) return false;
    }
    for (var i = 0; i < skippedRuleIds.length; i++) {
      if (skippedRuleIds[i] != other.skippedRuleIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    trustedReviewMetadata,
    Object.hashAll(executedRuleIds),
    Object.hashAll(evaluatedCategories),
    Object.hashAll(skippedRuleIds),
  );

  @override
  String toString() {
    return 'AnalysisExecutionContext(executedRules: ${executedRuleIds.length}, categories: ${evaluatedCategories.length}, skipped: ${skippedRuleIds.length}, hasReviewMetadata: ${trustedReviewMetadata != null})';
  }
}
