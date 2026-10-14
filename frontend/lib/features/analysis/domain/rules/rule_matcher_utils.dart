import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Internal data container representing a candidate text match range.
class MatchRange {
  final int start;
  final int end;

  const MatchRange(this.start, this.end);
}

/// Pure-Dart helper utilities for rule evaluation, clause splitting,
/// negation filtering, and exact evidence reference creation.
class RuleMatcherUtils {
  const RuleMatcherUtils._();

  /// Maximum matches a single rule will evaluate before halting to prevent
  /// runaway memory allocation on adversarial repetitive inputs.
  static const int maxMatchesPerRule = 105;

  /// Delimiters that define clause or sentence boundaries.
  /// ASCII codes: \n (10), \r (13), ! (33), , (44), . (46), : (58), ; (59), ? (63).
  static bool isClauseDelimiter(int codeUnit) {
    return codeUnit == 10 ||
        codeUnit == 13 ||
        codeUnit == 33 ||
        codeUnit == 44 ||
        codeUnit == 46 ||
        codeUnit == 58 ||
        codeUnit == 59 ||
        codeUnit == 63;
  }

  /// Evaluates multiple [patterns] against [snapshot.text], applying negation
  /// and exclusion checks, deduplicating overlapping ranges, and producing
  /// immutable [AnalysisFinding]s backed by exact [EvidenceReference]s.
  static List<AnalysisFinding> evaluatePatterns({
    required TextSnapshot snapshot,
    required String ruleId,
    required String categoryId,
    required String explanation,
    required List<RegExp> patterns,
    List<RegExp> negationPatterns = const [],
    List<RegExp> exclusionPatterns = const [],
  }) {
    final text = snapshot.text;
    if (text.isEmpty) return const [];

    final rawRanges = <MatchRange>[];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final start = match.start;
        final end = match.end;

        if (start >= end) continue;

        // Guard against splitting UTF-16 surrogate pairs
        if (EvidenceReference.isSurrogateSplit(text, start) ||
            EvidenceReference.isSurrogateSplit(text, end)) {
          continue;
        }

        // Determine clause boundaries for contextual validation
        final clauseStart = findClauseStart(text, start);
        final clauseEnd = findClauseEnd(text, end);
        final prefixText = text.substring(clauseStart, start);
        final fullClause = text.substring(clauseStart, clauseEnd);

        // Check clause against exclusion patterns (e.g. receipts or completed actions)
        var isExcluded = false;
        for (final exclusion in exclusionPatterns) {
          if (exclusion.hasMatch(fullClause)) {
            isExcluded = true;
            break;
          }
        }
        if (isExcluded) continue;

        // Check if prefix contains safety advice negation, accounting for adversarial reversals
        var isNegated = false;
        if (negationPatterns.isNotEmpty) {
          // If the prefix contains an adversarial conjunction ("but", "however", "yet"),
          // take only the sub-clause following the conjunction.
          final conjunctionMatch = RegExp(
            r'\b(?:but|however|yet|nevertheless)\b',
            caseSensitive: false,
          ).allMatches(prefixText);

          final effectivePrefix = conjunctionMatch.isNotEmpty
              ? prefixText.substring(conjunctionMatch.last.end)
              : prefixText;

          for (final negation in negationPatterns) {
            if (negation.hasMatch(effectivePrefix)) {
              isNegated = true;
              break;
            }
          }
        }
        if (isNegated) continue;

        rawRanges.add(MatchRange(start, end));

        if (rawRanges.length >= maxMatchesPerRule) {
          break;
        }
      }
      if (rawRanges.length >= maxMatchesPerRule) {
        break;
      }
    }

    if (rawRanges.isEmpty) return const [];

    // Sort ranges: earlier start first; for identical start, longer span first
    rawRanges.sort((a, b) {
      final startCmp = a.start.compareTo(b.start);
      if (startCmp != 0) return startCmp;
      return b.end.compareTo(a.end);
    });

    // Deduplicate overlapping ranges within this rule
    final deduplicated = <MatchRange>[];
    for (final range in rawRanges) {
      if (deduplicated.isEmpty) {
        deduplicated.add(range);
        continue;
      }

      final last = deduplicated.last;
      // If the current candidate overlaps with the last accepted range, discard it
      if (range.start < last.end) {
        continue;
      }

      deduplicated.add(range);
    }

    final findings = <AnalysisFinding>[];
    for (final range in deduplicated) {
      final evidence = EvidenceValidator.createReference(
        snapshot: snapshot,
        startOffset: range.start,
        endOffset: range.end,
      );

      findings.add(
        AnalysisFinding(
          id: '${ruleId}_${range.start}_${range.end}',
          category: categoryId,
          explanation: explanation,
          origin: FindingOrigin.localRule,
          producerId: ruleId,
          evidence: [evidence],
        ),
      );
    }

    return List.unmodifiable(findings);
  }

  /// Locates the beginning of the clause containing [offset].
  static int findClauseStart(String text, int offset) {
    if (offset <= 0) return 0;
    for (var i = offset - 1; i >= 0; i--) {
      if (isClauseDelimiter(text.codeUnitAt(i))) {
        return i + 1;
      }
    }
    return 0;
  }

  /// Locates the end of the clause containing [offset].
  static int findClauseEnd(String text, int offset) {
    if (offset >= text.length) return text.length;
    for (var i = offset; i < text.length; i++) {
      if (isClauseDelimiter(text.codeUnitAt(i))) {
        return i;
      }
    }
    return text.length;
  }
}
