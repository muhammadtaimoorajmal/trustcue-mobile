import 'export_format.dart';

/// User-controlled configuration options for report export and sharing.
///
/// Invariants & Privacy Guarantees:
/// - By default, exports contain ONLY high-level summaries, categorized indicator
///   findings, limitations, and verification actions.
/// - [includeReviewedText] is FALSE by default to avoid accidental disclosure of user communications.
/// - [includeEvidenceQuotes] is FALSE by default to avoid quoting message excerpts in public shares.
/// - [includeAiExplanations] is FALSE by default unless the user explicitly wants AI reasoning exported.
/// - Never includes raw OCR drafts, screenshot images, account emails, auth tokens,
///   or database paths.
class ExportOptions {
  final ExportFormat format;
  final bool includeReviewedText;
  final bool includeEvidenceQuotes;
  final bool includeAiExplanations;

  const ExportOptions({
    this.format = ExportFormat.plainText,
    this.includeReviewedText = false,
    this.includeEvidenceQuotes = false,
    this.includeAiExplanations = false,
  });

  ExportOptions copyWith({
    ExportFormat? format,
    bool? includeReviewedText,
    bool? includeEvidenceQuotes,
    bool? includeAiExplanations,
  }) {
    return ExportOptions(
      format: format ?? this.format,
      includeReviewedText: includeReviewedText ?? this.includeReviewedText,
      includeEvidenceQuotes:
          includeEvidenceQuotes ?? this.includeEvidenceQuotes,
      includeAiExplanations:
          includeAiExplanations ?? this.includeAiExplanations,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ExportOptions) return false;
    return other.format == format &&
        other.includeReviewedText == includeReviewedText &&
        other.includeEvidenceQuotes == includeEvidenceQuotes &&
        other.includeAiExplanations == includeAiExplanations;
  }

  @override
  int get hashCode => Object.hash(
    format,
    includeReviewedText,
    includeEvidenceQuotes,
    includeAiExplanations,
  );
}

