import 'indicator_category.dart';

/// Immutable record documenting rule coverage and scope constraints of a local analysis execution.
///
/// Principles:
/// - A nonempty catalog, an empty catalog, and skipped rules MUST NOT produce identical coverage claims.
/// - Does not invent language detection; states rule-pack language support explicitly.
/// - Explicitly acknowledges that local checks evaluate only configured indicators, not all possible deception techniques.
class AssessmentCoverageInfo {
  final List<String> executedRuleIds;
  final List<IndicatorCategory> evaluatedCategories;
  final List<String> skippedRuleIds;
  final List<String> supportedLanguages;
  final String coverageDescription;

  AssessmentCoverageInfo({
    required List<String> executedRuleIds,
    required List<IndicatorCategory> evaluatedCategories,
    List<String> skippedRuleIds = const [],
    List<String> supportedLanguages = const ['en', '*'],
    String? coverageDescription,
  }) : executedRuleIds = List.unmodifiable(executedRuleIds),
       evaluatedCategories = List.unmodifiable(evaluatedCategories),
       skippedRuleIds = List.unmodifiable(skippedRuleIds),
       supportedLanguages = List.unmodifiable(supportedLanguages),
       coverageDescription =
           coverageDescription ??
           _generateCoverageDescription(
             executedCount: executedRuleIds.length,
             categoryCount: evaluatedCategories.length,
             skippedCount: skippedRuleIds.length,
           );

  /// True if no rules were registered or executed in the evaluation catalog.
  bool get isCatalogEmpty => executedRuleIds.isEmpty && skippedRuleIds.isEmpty;

  /// True if coverage was constrained by an empty catalog or skipped rules.
  bool get hasLimitedCoverage => isCatalogEmpty || skippedRuleIds.isNotEmpty;

  static String _generateCoverageDescription({
    required int executedCount,
    required int categoryCount,
    required int skippedCount,
  }) {
    if (executedCount == 0 && skippedCount == 0) {
      return 'No local indicator rules were registered or evaluated. Coverage was unavailable.';
    }
    final buffer = StringBuffer(
      'Evaluated $executedCount on-device rule(s) across $categoryCount category family(ies). '
      'Rules primarily evaluate English text patterns and structural URL anomalies.',
    );
    if (skippedCount > 0) {
      buffer.write(
        ' $skippedCount rule(s) were skipped due to unsupported input scope.',
      );
    }
    buffer.write(
      ' These checks evaluate only specific known patterns and do not cover every possible scam technique.',
    );
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AssessmentCoverageInfo) return false;
    if (other.coverageDescription != coverageDescription ||
        other.executedRuleIds.length != executedRuleIds.length ||
        other.evaluatedCategories.length != evaluatedCategories.length ||
        other.skippedRuleIds.length != skippedRuleIds.length ||
        other.supportedLanguages.length != supportedLanguages.length) {
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
    for (var i = 0; i < supportedLanguages.length; i++) {
      if (supportedLanguages[i] != other.supportedLanguages[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    coverageDescription,
    Object.hashAll(executedRuleIds),
    Object.hashAll(evaluatedCategories),
    Object.hashAll(skippedRuleIds),
    Object.hashAll(supportedLanguages),
  );

  @override
  String toString() {
    return 'AssessmentCoverageInfo(executedRules: ${executedRuleIds.length}, categories: ${evaluatedCategories.length}, skippedRules: ${skippedRuleIds.length}, isCatalogEmpty: $isCatalogEmpty)';
  }
}
