/// Target categories for user feedback.
enum FeedbackTargetType {
  educationTopic('education_topic'),
  analysisFinding('analysis_finding'),
  appExperience('app_experience');

  const FeedbackTargetType(this.value);
  final String value;

  static FeedbackTargetType fromValue(String value) {
    return FeedbackTargetType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FeedbackTargetType.appExperience,
    );
  }
}

/// Usefulness rating options for local anonymous feedback.
enum FeedbackRating {
  helpful('helpful'),
  unhelpful('unhelpful'),
  neutral('neutral');

  const FeedbackRating(this.value);
  final String value;

  static FeedbackRating fromValue(String value) {
    return FeedbackRating.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FeedbackRating.neutral,
    );
  }
}

/// Structured reason chips for local feedback categorization.
enum FeedbackReasonChip {
  clearExplanation('clear_explanation', 'Clear explanation'),
  goodExample('good_example', 'Good example'),
  easyToVerify('easy_to_verify', 'Clear verification steps'),
  confusingTerms('confusing_terms', 'Confusing terminology'),
  tooTechnical('too_technical', 'Too technical'),
  exampleMismatch('example_mismatch', 'Example mismatch'),
  missingSteps('missing_steps', 'Missing verification step'),
  other('other', 'Other');

  const FeedbackReasonChip(this.value, this.label);
  final String value;
  final String label;

  static FeedbackReasonChip? fromValue(String? value) {
    if (value == null) return null;
    for (final chip in FeedbackReasonChip.values) {
      if (chip.value == value) return chip;
    }
    return null;
  }
}

/// Domain model representing an anonymous, locally-stored feedback entry.
///
/// Invariants:
/// - Stored strictly on-device in local SQLite.
/// - Never transmitted over the network or to remote servers.
/// - Contains zero PII: no raw message text, no screenshot data, no credentials,
///   no tokens, no full reports, no prompts.
/// - Comment is bounded to a maximum of 200 characters.
class AppFeedback {
  final String id;
  final FeedbackTargetType targetType;
  final String targetId;
  final FeedbackRating rating;
  final FeedbackReasonChip? reasonChip;
  final String? comment;
  final DateTime createdAt;

  AppFeedback({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.rating,
    this.reasonChip,
    this.comment,
    DateTime? createdAt,
  }) : createdAt = (createdAt ?? DateTime.now().toUtc()).toUtc(),
       assert(
         comment == null || comment.length <= 200,
         'Feedback comment cannot exceed 200 characters',
       );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'target_type': targetType.value,
      'target_id': targetId,
      'rating': rating.value,
      'reason_chip': reasonChip?.value,
      'comment': comment?.trim(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppFeedback.fromMap(Map<String, dynamic> map) {
    return AppFeedback(
      id: map['id'] as String,
      targetType: FeedbackTargetType.fromValue(map['target_type'] as String),
      targetId: map['target_id'] as String,
      rating: FeedbackRating.fromValue(map['rating'] as String),
      reasonChip: FeedbackReasonChip.fromValue(map['reason_chip'] as String?),
      comment: map['comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppFeedback &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          targetType == other.targetType &&
          targetId == other.targetId &&
          rating == other.rating &&
          reasonChip == other.reasonChip &&
          comment == other.comment &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    targetType,
    targetId,
    rating,
    reasonChip,
    comment,
    createdAt,
  );
}
