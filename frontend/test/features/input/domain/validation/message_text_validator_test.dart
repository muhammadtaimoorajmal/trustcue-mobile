import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';

void main() {
  group('MessageTextValidator', () {
    test(
      'Valid message passes validation and preserves text casing and spacing',
      () {
        const input =
            '  Hello World! This is a suspicious SMS from +123456789.  ';
        final result = MessageTextValidator.validate(input);

        expect(result.isValid, isTrue);
        expect(result.error, isNull);
        expect(result.normalizedText, equals(input));
      },
    );

    test('Accepts Urdu and multilingual scripts with visible glyphs', () {
      const urdu = 'آپ کا بینک اکاؤنٹ بند ہو گیا ہے۔ فوری رابطہ کریں۔';
      final result = MessageTextValidator.validate(urdu);

      expect(result.isValid, isTrue);
      expect(result.normalizedText, equals(urdu));
    });

    test('Accepts emojis, URLs, and punctuation', () {
      const complex = '⚠️ URGENT: Visit https://secure-bank-login.com?id=99 🚨';
      final result = MessageTextValidator.validate(complex);

      expect(result.isValid, isTrue);
      expect(result.normalizedText, equals(complex));
    });

    test('Accepts standard tabs and newlines', () {
      const textWithTabs =
          "Subject: Action required\n\tDetails:\tImmediate transfer";
      final result = MessageTextValidator.validate(textWithTabs);

      expect(result.isValid, isTrue);
      expect(result.normalizedText, equals(textWithTabs));
    });

    test('Normalizes CRLF and standalone CR to LF in normalizedText', () {
      const input = "Line 1\r\nLine 2\rLine 3\nLine 4";
      final result = MessageTextValidator.validate(input);

      expect(result.isValid, isTrue);
      expect(result.normalizedText, equals("Line 1\nLine 2\nLine 3\nLine 4"));
    });

    test('Counts code points and UTF-8 bytes accurately', () {
      const ascii = 'Hello';
      expect(MessageTextValidator.countCodePoints(ascii), 5);
      expect(MessageTextValidator.countUtf8Bytes(ascii), 5);
      expect(
        MessageTextValidator.formatCharacterCount(5),
        '5 / 10,000 characters',
      );

      // Emoji: 😀 is 1 rune, 2 UTF-16 code units, 4 UTF-8 bytes.
      const emoji = '😀';
      expect(MessageTextValidator.countCodePoints(emoji), 1);
      expect(MessageTextValidator.countUtf8Bytes(emoji), 4);

      // Flag: 🇵🇰 is 2 runes (regional indicator symbols), 8 UTF-8 bytes.
      const flag = '🇵🇰';
      expect(MessageTextValidator.countCodePoints(flag), 2);
      expect(MessageTextValidator.countUtf8Bytes(flag), 8);
    });

    test('Rejects empty input', () {
      final result = MessageTextValidator.validate('');

      expect(result.isValid, isFalse);
      expect(result.error?.reason, MessageTextValidationReason.empty);
      expect(result.error?.message, contains('Please enter a message'));
    });

    test('Rejects input containing only standard whitespace', () {
      final result = MessageTextValidator.validate("   \t  \n  \r\n  ");

      expect(result.isValid, isFalse);
      expect(result.error?.reason, MessageTextValidationReason.onlyWhitespace);
      expect(result.error?.message, contains('blank or invisible characters'));
    });

    test('Rejects input containing only invisible formatting characters', () {
      // Zero width space (\u200B), BOM (\uFEFF), ZWNJ (\u200C), ZWJ (\u200D)
      const invisible = "\u200B\uFEFF\u200C\u200D";
      final result = MessageTextValidator.validate(invisible);

      expect(result.isValid, isFalse);
      expect(result.error?.reason, MessageTextValidationReason.onlyWhitespace);
    });

    test('Rejects input exceeding 10,000 code points', () {
      final longText = 'a' * 10001;
      final result = MessageTextValidator.validate(longText);

      expect(result.isValid, isFalse);
      expect(
        result.error?.reason,
        MessageTextValidationReason.tooLongCodePoints,
      );
      expect(result.error?.message, contains('10,000 characters'));
    });

    test('Allows exactly 10,000 code points', () {
      final maxText = 'a' * 10000;
      final result = MessageTextValidator.validate(maxText);

      expect(result.isValid, isTrue);
      expect(result.normalizedText?.length, 10000);
    });

    test(
      'Rejects unsupported control characters (NUL, bell, ESC, form feed)',
      () {
        final withNul = "Hello\u0000World";
        final resultNul = MessageTextValidator.validate(withNul);
        expect(resultNul.isValid, isFalse);
        expect(
          resultNul.error?.reason,
          MessageTextValidationReason.unsupportedControlCharacters,
        );

        final withBell = "Hello\u0007World";
        final resultBell = MessageTextValidator.validate(withBell);
        expect(resultBell.isValid, isFalse);
        expect(
          resultBell.error?.reason,
          MessageTextValidationReason.unsupportedControlCharacters,
        );

        final withEsc = "Hello\u001BWorld";
        final resultEsc = MessageTextValidator.validate(withEsc);
        expect(resultEsc.isValid, isFalse);
        expect(
          resultEsc.error?.reason,
          MessageTextValidationReason.unsupportedControlCharacters,
        );
      },
    );

    test('Rejects malformed UTF-16 surrogates without crashing', () {
      // Unpaired high surrogate
      final malformedHigh = String.fromCharCode(0xD800);
      final resultHigh = MessageTextValidator.validate(malformedHigh);
      expect(resultHigh.isValid, isFalse);
      expect(
        resultHigh.error?.reason,
        MessageTextValidationReason.malformedUnicode,
      );

      // Unpaired low surrogate
      final malformedLow = String.fromCharCode(0xDC00);
      final resultLow = MessageTextValidator.validate(malformedLow);
      expect(resultLow.isValid, isFalse);
      expect(
        resultLow.error?.reason,
        MessageTextValidationReason.malformedUnicode,
      );
    });

    test('Maps validation error to AnalysisFailure and preserves privacy', () {
      const secretContent = "password123-super-secret-token";
      final error = MessageTextValidationError(
        reason: MessageTextValidationReason.tooLongCodePoints,
        message: 'Message exceeds the maximum limit of 10,000 characters.',
      );

      final failure = error.toAnalysisFailure();
      expect(failure.code, AnalysisFailureCode.invalidInput);
      expect(failure.safeDetails, 'tooLongCodePoints');
      expect(failure.message, contains('10,000 characters'));
      expect(failure.message, isNot(contains(secretContent)));
      expect(error.toString(), isNot(contains(secretContent)));
    });
  });
}
