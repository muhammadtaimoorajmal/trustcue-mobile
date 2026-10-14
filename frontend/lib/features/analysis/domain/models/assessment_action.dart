/// Priority ranking for recommended verification and safety actions.
///
/// Principles:
/// - Priority indicates the protective urgency of an action (e.g. not disclosing secrets).
/// - It MUST NEVER be presented as a fraud probability, confidence score, or risk level.
enum AssessmentActionPriority {
  /// Immediate protective actions (e.g. pausing before reacting, withholding credentials or verification codes).
  immediate,

  /// Recommended independent verification steps (e.g. checking an official careers portal or bank website).
  recommended,

  /// Conditional safety guidance applicable only if the user already acted or disclosed sensitive information.
  conditional;

  String toSerializedString() => name;
}

/// Immutable, deduplicated actionable verification or safety step.
///
/// Invariants:
/// - [id] must be non-empty and stable across releases (e.g. `'action.protect_credentials'`).
/// - [title] and [description] provide factual, safe guidance.
/// - Guidance MUST NEVER reuse contacts, emails, phone numbers, or links extracted from the evaluated content.
/// - Guidance MUST NEVER interpolate raw passwords, verification codes, or user-info credentials.
/// - [supportingFindingIds] and [supportingCategoryIds] trace which findings prompted this action.
/// - Unmodifiable collections preserve immutability.
class AssessmentAction {
  final String id;
  final String title;
  final String description;
  final AssessmentActionPriority priority;
  final List<String> supportingFindingIds;
  final List<String> supportingCategoryIds;
  final bool isConditionalPostAction;

  AssessmentAction({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required List<String> supportingFindingIds,
    required List<String> supportingCategoryIds,
    this.isConditionalPostAction = false,
  }) : supportingFindingIds = List.unmodifiable(supportingFindingIds),
       supportingCategoryIds = List.unmodifiable(supportingCategoryIds) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Action ID must not be empty.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Action title must not be empty.',
      );
    }
    if (description.trim().isEmpty) {
      throw ArgumentError.value(
        description,
        'description',
        'Action description must not be empty.',
      );
    }
  }

  /// Creates a copy of this action with merged supporting finding and category IDs.
  AssessmentAction mergeSupportingReferences({
    required List<String> additionalFindingIds,
    required List<String> additionalCategoryIds,
  }) {
    final mergedFindings = <String>{
      ...supportingFindingIds,
      ...additionalFindingIds,
    }.toList()..sort();
    final mergedCategories = <String>{
      ...supportingCategoryIds,
      ...additionalCategoryIds,
    }.toList()..sort();
    return AssessmentAction(
      id: id,
      title: title,
      description: description,
      priority: priority,
      supportingFindingIds: mergedFindings,
      supportingCategoryIds: mergedCategories,
      isConditionalPostAction: isConditionalPostAction,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AssessmentAction) return false;
    if (other.id != id ||
        other.title != title ||
        other.description != description ||
        other.priority != priority ||
        other.isConditionalPostAction != isConditionalPostAction ||
        other.supportingFindingIds.length != supportingFindingIds.length ||
        other.supportingCategoryIds.length != supportingCategoryIds.length) {
      return false;
    }
    for (var i = 0; i < supportingFindingIds.length; i++) {
      if (supportingFindingIds[i] != other.supportingFindingIds[i]) {
        return false;
      }
    }
    for (var i = 0; i < supportingCategoryIds.length; i++) {
      if (supportingCategoryIds[i] != other.supportingCategoryIds[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    priority,
    isConditionalPostAction,
    Object.hashAll(supportingFindingIds),
    Object.hashAll(supportingCategoryIds),
  );

  @override
  String toString() {
    // Diagnostic output avoids exposing sensitive message excerpts or interpolated data.
    return 'AssessmentAction(id: $id, priority: ${priority.name}, findingsCount: ${supportingFindingIds.length}, isConditional: $isConditionalPostAction)';
  }
}
