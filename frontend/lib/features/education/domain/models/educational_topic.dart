import 'package:flutter/material.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/category_educational_context.dart';

/// Rich domain model representing an educational topic in the TrustCue Scam Education Center.
///
/// Principles:
/// - Subtypes [CategoryEducationalContext] to preserve complete backward compatibility
///   with existing analysis synthesizers and results presentations.
/// - Contains realistic synthetic examples with fictional identities and reserved domains.
/// - Contains realistic contrasting ordinary examples explaining why legitimate messages
///   may exhibit similar wording without being fraudulent.
/// - Cites official consumer protection guidance (e.g. FTC, NCSC, CISA, APWG) with review dates.
/// - Guarantees offline availability without requiring authentication.
class EducationalTopic extends CategoryEducationalContext {
  final String title;
  final String syntheticSuspiciousExample;
  final String contrastingOrdinaryExample;
  final String contrastingExplanation;
  final String primarySourceTitle;
  final String primarySourceUrl;
  final String reviewDate;
  final IconData icon;

  const EducationalTopic({
    required super.id,
    required super.categoryId,
    required super.whatObserved,
    required super.whyAttention,
    required super.whatCannotEstablish,
    required super.independentVerificationStep,
    required this.title,
    required this.syntheticSuspiciousExample,
    required this.contrastingOrdinaryExample,
    required this.contrastingExplanation,
    required this.primarySourceTitle,
    required this.primarySourceUrl,
    required this.reviewDate,
    required this.icon,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EducationalTopic &&
        super == other &&
        other.title == title &&
        other.syntheticSuspiciousExample == syntheticSuspiciousExample &&
        other.contrastingOrdinaryExample == contrastingOrdinaryExample &&
        other.contrastingExplanation == contrastingExplanation &&
        other.primarySourceTitle == primarySourceTitle &&
        other.primarySourceUrl == primarySourceUrl &&
        other.reviewDate == reviewDate &&
        other.icon == icon;
  }

  @override
  int get hashCode => Object.hash(
    super.hashCode,
    title,
    syntheticSuspiciousExample,
    contrastingOrdinaryExample,
    contrastingExplanation,
    primarySourceTitle,
    primarySourceUrl,
    reviewDate,
    icon,
  );

  @override
  String toString() {
    return 'EducationalTopic(id: $id, categoryId: $categoryId, title: $title)';
  }
}
