/// Immutable educational context explaining a specific scam indicator category.
///
/// Principles:
/// - Provides factual, objective educational explanations for observed patterns.
/// - Does NOT pretend to know sender identity, authorization, maliciousness,
///   regulatory status, or whether an account or device is compromised.
/// - Guidance MUST NEVER cite country-specific emergency numbers, invented contacts,
///   or unsupported legal/financial conclusions.
class CategoryEducationalContext {
  final String id;
  final String categoryId;
  final String whatObserved;
  final String whyAttention;
  final String whatCannotEstablish;
  final String independentVerificationStep;

  const CategoryEducationalContext({
    required this.id,
    required this.categoryId,
    required this.whatObserved,
    required this.whyAttention,
    required this.whatCannotEstablish,
    required this.independentVerificationStep,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryEducationalContext &&
        other.id == id &&
        other.categoryId == categoryId &&
        other.whatObserved == whatObserved &&
        other.whyAttention == whyAttention &&
        other.whatCannotEstablish == whatCannotEstablish &&
        other.independentVerificationStep == independentVerificationStep;
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    whatObserved,
    whyAttention,
    whatCannotEstablish,
    independentVerificationStep,
  );

  @override
  String toString() {
    return 'CategoryEducationalContext(id: $id, categoryId: $categoryId)';
  }
}
