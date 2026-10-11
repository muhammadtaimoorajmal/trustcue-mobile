import 'dart:math' as math;

import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_candidate.dart';
import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_type.dart';

/// Pure-Dart detector that heuristically identifies potential sensitive data
/// (emails, phone numbers, payment card numbers, and contextual verification codes)
/// for user review and optional redaction.
///
/// Notice:
/// - This detector uses bounded heuristic pattern matching on the local device.
/// - It does not connect to any network, use AI, or guarantee exhaustive discovery.
/// - Ordinary text may be flagged (false positives) and sensitive text may be missed (false negatives).
class LocalSensitiveDataDetector {
  const LocalSensitiveDataDetector();

  /// Standard email regex matching bounded address formats.
  static final RegExp _emailRegExp = RegExp(
    r'[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+',
  );

  /// Payment-card candidate pattern: 13 to 19 digits with optional spaces or dashes.
  static final RegExp _cardCandidateRegExp = RegExp(
    r'\b(?:\d[ -]?){12,18}\d\b',
  );

  /// Verification code pattern: 4 to 8 digits bounded by word boundaries.
  static final RegExp _otpCandidateRegExp = RegExp(r'\b\d{4,8}\b');

  /// Phone number pattern: international prefix or formatted numbers with separators.
  static final RegExp _phoneRegExp = RegExp(
    r'(?:(?:\+|00)\d{1,3}[\s.-]?)?(?:\(?\d{2,5}\)?[\s.-]?)?\d{3,4}[\s.-]?\d{3,4}\b',
  );

  /// Context triggers required within ~35 characters of a candidate verification code.
  static final List<String> _otpContextTriggers = <String>[
    'otp',
    'code',
    'verification',
    'verification code',
    'one-time code',
    'one time code',
    'security code',
    'login code',
    'auth code',
    'confirmation code',
    'confirm code',
    'your code is',
    'passcode',
    'pin code',
    'pin',
  ];

  /// Scans the provided [text] and returns non-overlapping sensitive data candidates
  /// ordered by start index.
  List<SensitiveDataCandidate> detect({
    required String text,
    required String revision,
  }) {
    if (text.isEmpty) return const [];

    final rawCandidates = <SensitiveDataCandidate>[];
    int candidateSeq = 1;

    // 1. Detect Payment Cards (highest priority)
    for (final match in _cardCandidateRegExp.allMatches(text)) {
      final rawMatch = match.group(0)!;
      final digitsOnly = rawMatch.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length >= 13 &&
          digitsOnly.length <= 19 &&
          isValidLuhn(digitsOnly)) {
        final start = match.start;
        final end = match.end;
        if (!_splitsSurrogate(text, start) && !_splitsSurrogate(text, end)) {
          final lastFour = digitsOnly.length >= 4
              ? digitsOnly.substring(digitsOnly.length - 4)
              : digitsOnly;
          rawCandidates.add(
            SensitiveDataCandidate(
              id: 'cand-${candidateSeq++}',
              type: SensitiveDataType.paymentCard,
              startIndex: start,
              endIndex: end,
              matchedText: text.substring(start, end),
              maskedLabel: '•••• $lastFour',
              contextSummary: _buildContextSnippet(
                text,
                start,
                end,
                '•••• $lastFour',
              ),
              revision: revision,
            ),
          );
        }
      }
    }

    // 2. Detect Verification Codes (OTP) with nearby context
    for (final match in _otpCandidateRegExp.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      final candidateStr = text.substring(start, end);

      if (_isPartOfFormattedNumber(text, start, end)) {
        continue;
      }

      if (_hasOtpContext(text, start, end)) {
        if (!_splitsSurrogate(text, start) && !_splitsSurrogate(text, end)) {
          final masked =
              '•••• ${candidateStr.substring(math.max(0, candidateStr.length - 3))}';
          rawCandidates.add(
            SensitiveDataCandidate(
              id: 'cand-${candidateSeq++}',
              type: SensitiveDataType.verificationCode,
              startIndex: start,
              endIndex: end,
              matchedText: candidateStr,
              maskedLabel: masked,
              contextSummary: _buildContextSnippet(text, start, end, masked),
              revision: revision,
            ),
          );
        }
      }
    }

    // 3. Detect Email Addresses
    for (final match in _emailRegExp.allMatches(text)) {
      var rawMatch = match.group(0)!;
      var start = match.start;
      var end = match.end;

      // Trim trailing punctuation like '.' or ',' if matched at sentence boundaries
      while (rawMatch.endsWith('.') ||
          rawMatch.endsWith(',') ||
          rawMatch.endsWith('!')) {
        rawMatch = rawMatch.substring(0, rawMatch.length - 1);
        end--;
      }

      if (rawMatch.contains('@') &&
          !_splitsSurrogate(text, start) &&
          !_splitsSurrogate(text, end)) {
        final parts = rawMatch.split('@');
        final local = parts[0];
        final domain = parts.length > 1 ? parts[1] : '';
        final maskedLocal = local.length > 2
            ? '${local[0]}***${local[local.length - 1]}'
            : '${local[0]}***';
        final masked = '$maskedLocal@$domain';

        rawCandidates.add(
          SensitiveDataCandidate(
            id: 'cand-${candidateSeq++}',
            type: SensitiveDataType.email,
            startIndex: start,
            endIndex: end,
            matchedText: text.substring(start, end),
            maskedLabel: masked,
            contextSummary: _buildContextSnippet(text, start, end, masked),
            revision: revision,
          ),
        );
      }
    }

    // 4. Detect Phone Numbers
    for (final match in _phoneRegExp.allMatches(text)) {
      var rawMatch = match.group(0)!;
      var start = match.start;
      var end = match.end;

      // Trim punctuation at ends
      while (rawMatch.endsWith('.') ||
          rawMatch.endsWith(',') ||
          rawMatch.endsWith(';')) {
        rawMatch = rawMatch.substring(0, rawMatch.length - 1);
        end--;
      }
      while (rawMatch.startsWith('.') || rawMatch.startsWith(',')) {
        rawMatch = rawMatch.substring(1);
        start++;
      }

      final digitsOnly = rawMatch.replaceAll(RegExp(r'\D'), '');
      // Valid phone numbers typically have 7 to 15 digits
      if (digitsOnly.length >= 7 && digitsOnly.length <= 15) {
        // Exclude common false positives: dates (e.g. 2026-10-11, 11/10/2026), prices
        if (!_isDateOrPrice(text, start, end, rawMatch)) {
          if (!_splitsSurrogate(text, start) && !_splitsSurrogate(text, end)) {
            final lastFour = digitsOnly.length >= 4
                ? digitsOnly.substring(digitsOnly.length - 4)
                : digitsOnly;
            final masked = '•••• $lastFour';

            rawCandidates.add(
              SensitiveDataCandidate(
                id: 'cand-${candidateSeq++}',
                type: SensitiveDataType.phone,
                startIndex: start,
                endIndex: end,
                matchedText: text.substring(start, end),
                maskedLabel: masked,
                contextSummary: _buildContextSnippet(text, start, end, masked),
                revision: revision,
              ),
            );
          }
        }
      }
    }

    // 5. Resolve overlaps and deduplicate deterministically
    return resolveOverlaps(rawCandidates);
  }

  /// Resolves overlapping candidates deterministically using category priority,
  /// candidate length, and offset order.
  static List<SensitiveDataCandidate> resolveOverlaps(
    List<SensitiveDataCandidate> candidates,
  ) {
    if (candidates.isEmpty) return const [];

    // Sort candidates by priority DESC, length DESC, startIndex ASC
    final sorted = List<SensitiveDataCandidate>.from(candidates)
      ..sort((a, b) {
        final pComp = b.type.priority.compareTo(a.type.priority);
        if (pComp != 0) return pComp;
        final lComp = b.length.compareTo(a.length);
        if (lComp != 0) return lComp;
        return a.startIndex.compareTo(b.startIndex);
      });

    final accepted = <SensitiveDataCandidate>[];
    for (final candidate in sorted) {
      final hasOverlap = accepted.any(
        (existing) => existing.overlaps(candidate),
      );
      if (!hasOverlap) {
        accepted.add(candidate);
      }
    }

    // Re-sort accepted candidates in sequential reading order (startIndex ASC)
    accepted.sort((a, b) => a.startIndex.compareTo(b.startIndex));
    return List.unmodifiable(accepted);
  }

  /// Applies selected candidate redactions in descending offset order so earlier
  /// replacement offsets remain uncorrupted.
  String applyRedactions({
    required String text,
    required Set<String> selectedCandidateIds,
    required List<SensitiveDataCandidate> candidates,
  }) {
    if (selectedCandidateIds.isEmpty || candidates.isEmpty) {
      return text;
    }

    final toApply = candidates
        .where((c) => selectedCandidateIds.contains(c.id))
        .toList();

    // Verify candidates are valid in current text
    for (final c in toApply) {
      if (!c.isValidIn(text)) {
        throw StateError('Candidate ${c.id} does not match current text span');
      }
    }

    // Check for any mutually overlapping selections
    for (int i = 0; i < toApply.length; i++) {
      for (int j = i + 1; j < toApply.length; j++) {
        if (toApply[i].overlaps(toApply[j])) {
          throw StateError(
            'Cannot apply overlapping redactions for ${toApply[i].id} and ${toApply[j].id}',
          );
        }
      }
    }

    // Sort descending by startIndex
    toApply.sort((a, b) => b.startIndex.compareTo(a.startIndex));

    var result = text;
    for (final candidate in toApply) {
      result =
          result.substring(0, candidate.startIndex) +
          candidate.type.placeholder +
          result.substring(candidate.endIndex);
    }

    return result;
  }

  /// Implements standard Luhn algorithm checksum verification.
  static bool isValidLuhn(String rawDigits) {
    final digits = rawDigits.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 13 || digits.length > 19) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) {
          n -= 9;
        }
      }
      sum += n;
      alternate = !alternate;
    }
    return (sum % 10 == 0);
  }

  /// Checks if the text surrounding a 4-8 digit number contains explicit OTP context.
  static bool _hasOtpContext(String text, int start, int end) {
    const windowSize = 40;
    final contextStart = math.max(0, start - windowSize);
    final contextEnd = math.min(text.length, end + windowSize);
    final window = text.substring(contextStart, contextEnd).toLowerCase();

    for (final trigger in _otpContextTriggers) {
      if (window.contains(trigger)) {
        return true;
      }
    }
    return false;
  }

  /// Heuristically identifies common date formats (e.g. YYYY-MM-DD, DD/MM/YYYY)
  /// or prices to avoid misclassifying them as phone numbers.
  static bool _isDateOrPrice(String text, int start, int end, String match) {
    // Check for standard date pattern: e.g. 2026-10-11 or 11/10/2026
    if (RegExp(r'^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$').hasMatch(match) ||
        RegExp(r'^\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}$').hasMatch(match)) {
      return true;
    }

    // Check for currency symbols or words nearby
    final prefixStart = math.max(0, start - 5);
    final prefix = text.substring(prefixStart, start).trim();
    if (prefix.endsWith('\$') ||
        prefix.endsWith('€') ||
        prefix.endsWith('£') ||
        prefix.endsWith('¥') ||
        prefix.toLowerCase().endsWith('rs') ||
        prefix.toLowerCase().endsWith('pkr') ||
        prefix.toLowerCase().endsWith('usd')) {
      return true;
    }

    return false;
  }

  static bool _isPartOfFormattedNumber(String text, int start, int end) {
    if (start > 0) {
      final prevChar = text[start - 1];
      if (prevChar == '-' || prevChar == '.' || prevChar == ')') {
        final prefix = text.substring(math.max(0, start - 6), start - 1);
        if (RegExp(r'\d').hasMatch(prefix)) {
          return true;
        }
      }
    }
    if (end < text.length) {
      final nextChar = text[end];
      if (nextChar == '-' || nextChar == '.') {
        final suffix = text.substring(end + 1, math.min(text.length, end + 6));
        if (RegExp(r'\d').hasMatch(suffix)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _splitsSurrogate(String text, int index) {
    if (index <= 0 || index >= text.length) return false;
    final prev = text.codeUnitAt(index - 1);
    final curr = text.codeUnitAt(index);
    return (prev >= 0xD800 && prev <= 0xDBFF) &&
        (curr >= 0xDC00 && curr <= 0xDFFF);
  }

  static String _buildContextSnippet(
    String text,
    int start,
    int end,
    String maskedLabel,
  ) {
    const contextChars = 15;
    final prefixStart = math.max(0, start - contextChars);
    final suffixEnd = math.min(text.length, end + contextChars);

    final prefix = text.substring(prefixStart, start);
    final suffix = text.substring(end, suffixEnd);

    final leftEllipsis = prefixStart > 0 ? '...' : '';
    final rightEllipsis = suffixEnd < text.length ? '...' : '';

    return '$leftEllipsis$prefix$maskedLabel$suffix$rightEllipsis'.replaceAll(
      '\n',
      ' ',
    );
  }
}
