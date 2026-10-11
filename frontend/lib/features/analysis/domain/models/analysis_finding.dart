import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'evidence_reference.dart';
import 'finding_origin.dart';

/// Immutable representation of an individual scam indicator finding.
///
/// Invariants:
/// - [id], [category], [explanation], and [producerId] must be non-empty strings.
/// - [origin] indicates whether the finding was derived from a deterministic local rule
///   or from remote AI analysis.
/// - [evidence] must contain at least one verifiable evidence reference.
/// - Does not fabricate scam probabilities, risk scores, or "definitely safe" claims.
class AnalysisFinding {
  final String id;
  final String category;
  final String explanation;
  final FindingOrigin origin;
  final String producerId;
  final List<EvidenceReference> evidence;

  AnalysisFinding({
    required this.id,
    required this.category,
    required this.explanation,
    required this.origin,
    required this.producerId,
    required List<EvidenceReference> evidence,
  }) : evidence = List.unmodifiable(evidence) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Finding ID must not be empty.');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError.value(
        category,
        'category',
        'Category identifier must not be empty.',
      );
    }
    if (explanation.trim().isEmpty) {
      throw ArgumentError.value(
        explanation,
        'explanation',
        'Explanation must not be empty.',
      );
    }
    if (producerId.trim().isEmpty) {
      throw ArgumentError.value(
        producerId,
        'producerId',
        'Producer ID must not be empty.',
      );
    }
    if (this.evidence.isEmpty) {
      throw ArgumentError(
        'Finding must contain at least one evidence reference.',
      );
    }
  }

  /// Validates all evidence references against the specified [snapshot].
  void validateAgainst(TextSnapshot snapshot) {
    for (final ref in evidence) {
      ref.validateAgainst(snapshot);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnalysisFinding) return false;
    if (other.id != id ||
        other.category != category ||
        other.explanation != explanation ||
        other.origin != origin ||
        other.producerId != producerId ||
        other.evidence.length != evidence.length) {
      return false;
    }
    for (var i = 0; i < evidence.length; i++) {
      if (evidence[i] != other.evidence[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    explanation,
    origin,
    producerId,
    Object.hashAll(evidence),
  );

  @override
  String toString() {
    return 'AnalysisFinding(id: $id, category: $category, origin: ${origin.name}, producer: $producerId, evidenceCount: ${evidence.length})';
  }
}
