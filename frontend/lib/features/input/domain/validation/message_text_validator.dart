import 'dart:convert';

import 'package:trustcue_mobile/core/errors/analysis_failure.dart';

/// Distinct categories of validation failure for message text input.
enum MessageTextValidationReason {
  empty,
  onlyWhitespace,
  tooLongCodePoints,
  tooLongBytes,
  unsupportedControlCharacters,
  malformedUnicode,
}

/// Immutable, privacy-safe validation error for message text input.
///
/// Guaranteed never to store or expose actual user message text in [message],
/// [reason], or [toString].
class MessageTextValidationError {
  final MessageTextValidationReason reason;
  final String message;

  const MessageTextValidationError({
    required this.reason,
    required this.message,
  });

  /// Maps this validation error to a standardized [AnalysisFailure].
  AnalysisFailure toAnalysisFailure() {
    return AnalysisFailure.invalidInput(message, reason.name);
  }

  @override
  String toString() =>
      'MessageTextValidationError(reason: ${reason.name}, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageTextValidationError &&
          other.reason == reason &&
          other.message == message);

  @override
  int get hashCode => Object.hash(reason, message);
}

/// Result of evaluating message text input for analysis preparation.
class MessageTextValidationResult {
  final bool isValid;
  final MessageTextValidationError? error;
  final String? normalizedText;

  const MessageTextValidationResult.valid(String this.normalizedText)
    : isValid = true,
      error = null;

  const MessageTextValidationResult.invalid(
    MessageTextValidationError this.error,
  ) : isValid = false,
      normalizedText = null;

  bool get isInvalid => !isValid;
}

/// Pure-Dart validator and normalizer for user-entered message text.
///
/// Policy highlights:
/// - Maximum 10,000 Unicode code points (runes).
/// - Maximum 40,000 UTF-8 encoded bytes.
/// - Limits are evaluated against the original input to prevent bypass.
/// - Disallows empty input, invisible-only content, unsupported control characters,
///   and malformed UTF-16 surrogates.
/// - Preserves leading/trailing whitespace, multilingual scripts (e.g. Urdu),
///   emojis, URLs, and casing.
/// - Normalizes line endings (`\r\n` and `\r` to `\n`) for snapshot storage.
class MessageTextValidator {
  const MessageTextValidator._();

  static const int maxCodePoints = 10000;
  static const int maxUtf8Bytes = 40000;

  /// Returns the number of Unicode code points (runes) in [text].
  static int countCodePoints(String text) {
    if (_hasUnpairedSurrogate(text)) {
      return text.length;
    }
    return text.runes.length;
  }

  /// Returns the number of UTF-8 encoded bytes in [text].
  static int countUtf8Bytes(String text) {
    try {
      return utf8.encode(text).length;
    } catch (_) {
      return text.length * 2;
    }
  }

  /// Formats the code-point counter string for the UI (e.g. "45 / 10,000 characters").
  static String formatCharacterCount(int count) {
    return '$count / 10,000 characters';
  }

  /// Normalizes line breaks to standard LF (`\n`).
  ///
  /// Standalone CR (`\r`) and CRLF (`\r\n`) become `\n`. All other content,
  /// whitespace, and casing are left unchanged.
  static String normalizeLineEndings(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Validates [rawText] against length limits, encoding integrity, and content rules.
  static MessageTextValidationResult validate(String rawText) {
    if (_hasUnpairedSurrogate(rawText)) {
      return const MessageTextValidationResult.invalid(
        MessageTextValidationError(
          reason: MessageTextValidationReason.malformedUnicode,
          message: 'Message contains malformed character encoding. Please re-copy the message.',
        ),
      );
    }

    if (rawText.isEmpty) {
      return const MessageTextValidationResult.invalid(
        MessageTextValidationError(
          reason: MessageTextValidationReason.empty,
          message: 'Please enter a message to review.',
        ),
      );
    }

    if (_hasUnsupportedControlCharacters(rawText)) {
      return const MessageTextValidationResult.invalid(
        MessageTextValidationError(
          reason: MessageTextValidationReason.unsupportedControlCharacters,
          message: 'Message contains unsupported control characters. Please remove any invalid binary characters.',
        ),
      );
    }

    final codePoints = rawText.runes.length;
    if (codePoints > maxCodePoints) {
      return const MessageTextValidationResult.invalid(
        MessageTextValidationError(
          reason: MessageTextValidationReason.tooLongCodePoints,
          message: 'Message exceeds the maximum limit of 10,000 characters.',
        ),
      );
    }

    final bytes = countUtf8Bytes(rawText);
    if (bytes > maxUtf8Bytes) {
      return const MessageTextValidationResult.invalid(
        MessageTextValidationError(
          reason: MessageTextValidationReason.tooLongBytes,
          message: 'Message exceeds the maximum byte size limit of 40 KB.',
        ),
      );
    }

    if (!_hasVisibleContent(rawText)) {
      return const MessageTextValidationResult.invalid(
        MessageTextValidationError(
          reason: MessageTextValidationReason.onlyWhitespace,
          message: 'Message contains only blank or invisible characters. Please enter visible message text.',
        ),
      );
    }

    final normalized = normalizeLineEndings(rawText);
    return MessageTextValidationResult.valid(normalized);
  }

  /// Detects unpaired UTF-16 surrogate code units.
  static bool _hasUnpairedSurrogate(String text) {
    final units = text.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        // High surrogate must be followed by a low surrogate.
        if (i + 1 >= units.length ||
            units[i + 1] < 0xDC00 ||
            units[i + 1] > 0xDFFF) {
          return true;
        }
        i++; // Skip the verified low surrogate.
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        // Low surrogate without a preceding high surrogate.
        return true;
      }
    }
    return false;
  }

  /// Checks for C0 (except \t, \n, \r), DEL, or C1 control characters.
  static bool _hasUnsupportedControlCharacters(String text) {
    for (final rune in text.runes) {
      if (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) {
        return true;
      }
      if (rune == 0x7F) {
        return true;
      }
      if (rune >= 0x80 && rune <= 0x9F) {
        return true;
      }
    }
    return false;
  }

  /// Determines whether [text] contains at least one visible, meaningful glyph.
  static bool _hasVisibleContent(String text) {
    for (final rune in text.runes) {
      if (!_isInvisibleOrWhitespace(rune)) {
        return true;
      }
    }
    return false;
  }

  /// Identifies whitespace code points and invisible formatting marks.
  static bool _isInvisibleOrWhitespace(int rune) {
    // Standard ASCII whitespace and controls.
    if (rune <= 0x20) return true;
    if (rune == 0x7F) return true;

    // Unicode whitespace separators.
    if (rune == 0x00A0 || // NO-BREAK SPACE
        rune == 0x1680 || // OGHAM SPACE MARK
        (rune >= 0x2000 && rune <= 0x200A) || // EN QUAD .. HAIR SPACE
        rune == 0x2028 || // LINE SEPARATOR
        rune == 0x2029 || // PARAGRAPH SEPARATOR
        rune == 0x202F || // NARROW NO-BREAK SPACE
        rune == 0x205F || // MEDIUM MATHEMATICAL SPACE
        rune == 0x3000) {
      // IDEOGRAPHIC SPACE
      return true;
    }

    // Zero-width and formatting controls.
    if (rune == 0x200B || // ZERO WIDTH SPACE
        rune == 0x200C || // ZERO WIDTH NON-JOINER
        rune == 0x200D || // ZERO WIDTH JOINER
        rune == 0x200E || // LEFT-TO-RIGHT MARK
        rune == 0x200F || // RIGHT-TO-LEFT MARK
        (rune >= 0x202A && rune <= 0x202E) || // Bidi formatting
        rune == 0x2060 || // WORD JOINER
        (rune >= 0x2061 && rune <= 0x2064) || // Invisible math operators
        (rune >= 0x2066 && rune <= 0x2069) || // Bidi isolates
        rune == 0xFEFF || // ZERO WIDTH NO-BREAK SPACE / BOM
        (rune >= 0xFFF9 && rune <= 0xFFFB)) {
      // Interlinear annotations
      return true;
    }

    return false;
  }
}
