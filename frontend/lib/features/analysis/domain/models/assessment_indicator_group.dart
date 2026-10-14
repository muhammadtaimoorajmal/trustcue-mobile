import 'analysis_finding.dart';
import 'category_educational_context.dart';
import 'indicator_category.dart';

/// Immutable grouping of findings under a single scam indicator category.
///
/// Invariants:
/// - [categoryId] must match all contained [findings].
/// - [findings] must not be empty and must preserve distinct occurrences without loss of evidence.
/// - [educationalContext] provides objective guidance tailored to this category family.
/// - Unmodifiable collections preserve immutability across consumer boundaries.
class AssessmentIndicatorGroup {
  final String categoryId;
  final IndicatorCategory? category;
  final String categoryLabel;
  final List<AnalysisFinding> findings;
  final CategoryEducationalContext educationalContext;

  AssessmentIndicatorGroup({
    required this.categoryId,
    this.category,
    required this.categoryLabel,
    required List<AnalysisFinding> findings,
    required this.educationalContext,
  }) : findings = List.unmodifiable(findings) {
    if (categoryId.trim().isEmpty) {
      throw ArgumentError.value(
        categoryId,
        'categoryId',
        'Category ID must not be empty.',
      );
    }
    if (categoryLabel.trim().isEmpty) {
      throw ArgumentError.value(
        categoryLabel,
        'categoryLabel',
        'Category label must not be empty.',
      );
    }
    if (this.findings.isEmpty) {
      throw ArgumentError(
        'AssessmentIndicatorGroup must contain at least one finding.',
      );
    }
    for (final finding in this.findings) {
      if (finding.category != categoryId) {
        throw ArgumentError(
          'Finding "${finding.id}" category "${finding.category}" does not match group category "$categoryId".',
        );
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AssessmentIndicatorGroup) return false;
    if (other.categoryId != categoryId ||
        other.category != category ||
        other.categoryLabel != categoryLabel ||
        other.educationalContext != educationalContext ||
        other.findings.length != findings.length) {
      return false;
    }
    for (var i = 0; i < findings.length; i++) {
      if (findings[i] != other.findings[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    categoryId,
    category,
    categoryLabel,
    educationalContext,
    Object.hashAll(findings),
  );

  @override
  String toString() {
    return 'AssessmentIndicatorGroup(categoryId: $categoryId, category: ${category?.name}, findingsCount: ${findings.length})';
  }
}
