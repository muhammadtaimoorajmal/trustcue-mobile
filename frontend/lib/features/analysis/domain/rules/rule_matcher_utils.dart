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

/// Exception thrown when a rule's distinct matches exceed the maximum allowed
/// findings threshold, preventing silent truncation and memory exhaustion.
class RuleLimitExceededException implements Exception {
  final String ruleId;
  final int limit;

  const RuleLimitExceededException({required this.ruleId, required this.limit});

  @override
  String toString() =>
      'RuleLimitExceededException: Rule "$ruleId" exceeded match limit of $limit.';
}

/// Pure-Dart helper utilities for rule evaluation, clause splitting,
/// negation filtering, and exact evidence reference creation.
class RuleMatcherUtils {
  const RuleMatcherUtils._();

  /// Maximum findings a single rule will produce before signaling overflow.
  /// Aligned with the engine's default finding limit.
  static const int maxMatchesPerRule = 100;

  /// Safety ceiling on raw candidate matches to prevent runaway memory
  /// allocation on extreme adversarial inputs before deduplication.
  static const int maxRawCandidateLimit = 500;

  /// Checks if a character code unit is an unconditional clause delimiter.
  /// ASCII codes: \n (10), \r (13), ! (33), , (44), ; (59), ? (63).
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

  /// Context-aware delimiter detection that prevents false clause splitting on:
  /// - Decimal numbers (e.g. "$10.50", "0.05")
  /// - Times (e.g. "10:30")
  /// - URL scheme prefixes (e.g. "https://")
  static bool isDelimiterAtIndex(String text, int index) {
    final code = text.codeUnitAt(index);

    // Unconditional punctuation delimiters
    if (code == 10 ||
        code == 13 ||
        code == 33 ||
        code == 44 ||
        code == 59 ||
        code == 63) {
      return true;
    }

    // Period . (46): NOT a delimiter if flanked by digits (decimal amounts)
    if (code == 46) {
      final prevIsDigit = index > 0 && _isDigit(text.codeUnitAt(index - 1));
      final nextIsDigit =
          index + 1 < text.length && _isDigit(text.codeUnitAt(index + 1));
      if (prevIsDigit && nextIsDigit) {
        return false;
      }
      return true;
    }

    // Colon : (58): NOT a delimiter if flanked by digits (e.g. time) or part of scheme ("://")
    if (code == 58) {
      final prevIsDigit = index > 0 && _isDigit(text.codeUnitAt(index - 1));
      final nextIsDigit =
          index + 1 < text.length && _isDigit(text.codeUnitAt(index + 1));
      if (prevIsDigit && nextIsDigit) {
        return false;
      }
      if (index + 2 < text.length &&
          text.codeUnitAt(index + 1) == 47 &&
          text.codeUnitAt(index + 2) == 47) {
        return false;
      }
      return true;
    }

    return false;
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;

  /// Evaluates multiple [patterns] against [snapshot.text], applying negation
  /// and exclusion checks, deduplicating overlapping ranges, and producing
  /// immutable [AnalysisFinding]s backed by exact [EvidenceReference]s.
  ///
  /// Throws [RuleLimitExceededException] if distinct non-overlapping findings
  /// exceed [maxMatches] or if raw candidate matches exceed [maxRawCandidateLimit],
  /// preserving the engine's typed-failure contract without silent truncation.
  static List<AnalysisFinding> evaluatePatterns({
    required TextSnapshot snapshot,
    required String ruleId,
    required String categoryId,
    required String explanation,
    required List<RegExp> patterns,
    List<RegExp> negationPatterns = const [],
    List<RegExp> exclusionPatterns = const [],
    int maxMatches = maxMatchesPerRule,
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

          // If the match itself contains an adversarial conjunction (e.g. "password, but send it to..."),
          // the leading negation does not suppress the actionable request.
          if (isNegated) {
            final matchText = text.substring(start, end);
            final hasConjunctionInMatch = RegExp(
              r'\b(?:but|however|yet|nevertheless)\b',
              caseSensitive: false,
            ).hasMatch(matchText);
            if (hasConjunctionInMatch) {
              isNegated = false;
            }
          }
        }
        if (isNegated) continue;

        rawRanges.add(MatchRange(start, end));

        // Early cutoff for extreme adversarial inputs (e.g. thousands of matches)
        if (rawRanges.length > maxRawCandidateLimit) {
          throw RuleLimitExceededException(ruleId: ruleId, limit: maxMatches);
        }
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

    // Explicit overflow check: if deduplicated findings exceed limit,
    // propagate overflow instead of silently discarding matches.
    if (deduplicated.length > maxMatches) {
      throw RuleLimitExceededException(ruleId: ruleId, limit: maxMatches);
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
      if (isDelimiterAtIndex(text, i)) {
        return i + 1;
      }
    }
    return 0;
  }

  /// Locates the end of the clause containing [offset].
  static int findClauseEnd(String text, int offset) {
    if (offset >= text.length) return text.length;
    for (var i = offset; i < text.length; i++) {
      if (isDelimiterAtIndex(text, i)) {
        return i;
      }
    }
    return text.length;
  }
}
