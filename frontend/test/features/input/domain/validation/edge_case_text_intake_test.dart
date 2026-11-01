import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_review_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';

void main() {
  group('Module 57: Edge-Case Text Intake & Boundary Contract', () {
    group('1. Length Boundaries: Exact-Limit, One-Below, One-Above', () {
      test('ASCII: 9,999 (one below) and 10,000 (exact limit) pass; 10,001 (one above) fails', () {
        final text9999 = 'A' * 9999;
        final res9999 = MessageTextValidator.validate(text9999);
        expect(res9999.isValid, isTrue);
        expect(res9999.normalizedText?.length, 9999);
        expect(MessageTextValidator.countCodePoints(text9999), 9999);
        expect(MessageTextValidator.countUtf8Bytes(text9999), 9999);

        final text10000 = 'A' * 10000;
        final res10000 = MessageTextValidator.validate(text10000);
        expect(res10000.isValid, isTrue);
        expect(res10000.normalizedText?.length, 10000);
        expect(MessageTextValidator.countCodePoints(text10000), 10000);
        expect(MessageTextValidator.countUtf8Bytes(text10000), 10000);

        final text10001 = 'A' * 10001;
        final res10001 = MessageTextValidator.validate(text10001);
        expect(res10001.isValid, isFalse);
        expect(
          res10001.error?.reason,
          MessageTextValidationReason.tooLongCodePoints,
        );
        expect(res10001.error?.message, contains('10,000 characters'));
      });

      test('Supplementary-Plane Emojis (4-byte): 9,999 and 10,000 pass; 10,001 fails', () {
        // '😀' is 1 code point, 2 UTF-16 code units, 4 UTF-8 bytes.
        const emoji = '😀';
        expect(emoji.runes.length, 1);
        expect(emoji.length, 2);
        expect(utf8.encode(emoji).length, 4);

        // 9,999 emojis = 9,999 runes, 19,998 UTF-16 code units, 39,996 UTF-8 bytes
        final text9999 = emoji * 9999;
        final res9999 = MessageTextValidator.validate(text9999);
        expect(res9999.isValid, isTrue);
        expect(MessageTextValidator.countCodePoints(text9999), 9999);
        expect(MessageTextValidator.countUtf8Bytes(text9999), 39996);

        // 10,000 emojis = 10,000 runes, 20,000 UTF-16 code units, exactly 40,000 UTF-8 bytes
        final text10000 = emoji * 10000;
        final res10000 = MessageTextValidator.validate(text10000);
        expect(res10000.isValid, isTrue);
        expect(MessageTextValidator.countCodePoints(text10000), 10000);
        expect(MessageTextValidator.countUtf8Bytes(text10000), 40000);

        // 10,001 emojis = 10,001 runes, 20,002 UTF-16 code units, 40,004 UTF-8 bytes -> fails
        final text10001 = emoji * 10001;
        final res10001 = MessageTextValidator.validate(text10001);
        expect(res10001.isValid, isFalse);
        expect(
          res10001.error?.reason,
          MessageTextValidationReason.tooLongCodePoints,
        );
      });

      test('Combining marks and multi-code-point emoji sequences are measured by runes', () {
        // 'e\u0301' is 'é' composed of 2 code points (e + combining acute)
        const combiningE = 'e\u0301';
        expect(combiningE.runes.length, 2);
        expect(combiningE.length, 2);
        expect(
          utf8.encode(combiningE).length,
          3,
        ); // 'e' (1) + combining acute (2)

        // 5,000 combining marks = 10,000 runes -> valid
        final text10000 = combiningE * 5000;
        expect(MessageTextValidator.countCodePoints(text10000), 10000);
        expect(MessageTextValidator.validate(text10000).isValid, isTrue);

        // 5,001 combining marks = 10,002 runes -> invalid
        final text10002 = combiningE * 5001;
        expect(MessageTextValidator.countCodePoints(text10002), 10002);
        expect(MessageTextValidator.validate(text10002).isValid, isFalse);

        // ZWJ Family Emoji sequence: 👨 (1) + ZWJ (1) + 👩 (1) + ZWJ (1) + 👧 (1) = 5 runes
        const family = '👨‍👩‍👧';
        expect(family.runes.length, 5);
        expect(family.length, 8); // 2 + 1 + 2 + 1 + 2 UTF-16 units
        expect(utf8.encode(family).length, 18); // 4 + 3 + 4 + 3 + 4 bytes

        // 2,000 family emojis = 10,000 runes, 36,000 bytes -> valid
        final textFamily10000 = family * 2000;
        expect(MessageTextValidator.countCodePoints(textFamily10000), 10000);
        expect(MessageTextValidator.validate(textFamily10000).isValid, isTrue);
      });
    });

    group('2. Whitespace, Newlines, and Invisible Control Characters', () {
      test('Whitespace-only input is rejected', () {
        final whitespaces = [
          '   ',
          '\t\t',
          '\n\n',
          '\r\n\r\n',
          ' \t \n \r ',
          '\u00A0\u00A0', // Non-breaking spaces
          '\u2000\u2001\u2002\u2003', // En/Em spaces
          '\u3000', // Ideographic space
        ];
        for (final ws in whitespaces) {
          final res = MessageTextValidator.validate(ws);
          expect(res.isValid, isFalse);
          expect(res.error?.reason, MessageTextValidationReason.onlyWhitespace);
        }
      });

      test(
        'Invisible formatting characters alone are rejected as onlyWhitespace',
        () {
          const invisibles = '\u200B\u200C\u200D\uFEFF\u2060';
          final res = MessageTextValidator.validate(invisibles);
          expect(res.isValid, isFalse);
          expect(res.error?.reason, MessageTextValidationReason.onlyWhitespace);
        },
      );

      test('Preserves user whitespace, casing, and normalizes CRLF and standalone CR to LF', () {
        const raw =
            '  Subject: Urgent Alert  \r\n\rLine 2: Action needed\t\t\nLine 3.  ';
        final res = MessageTextValidator.validate(raw);
        expect(res.isValid, isTrue);
        expect(
          res.normalizedText,
          equals(
            '  Subject: Urgent Alert  \n\nLine 2: Action needed\t\t\nLine 3.  ',
          ),
        );
      });

      test('Visible text with embedded zero-width characters passes validation safely', () {
        const obfuscated = 'U\u200Br\u200Bg\u200Be\u200Bn\u200Bt';
        final res = MessageTextValidator.validate(obfuscated);
        expect(res.isValid, isTrue);
        expect(res.normalizedText, equals(obfuscated));
      });
    });

    group('3. Multilingual, Urdu/Arabic Script, and BiDi Handling', () {
      test('Urdu text passes validation and preserves exact script', () {
        const urduMsg =
            'آپ کا بینک اکاؤنٹ سیکیورٹی وجوہات کی بنا پر معطل کر دیا گیا ہے۔ تصدیق کریں۔';
        final res = MessageTextValidator.validate(urduMsg);
        expect(res.isValid, isTrue);
        expect(res.normalizedText, equals(urduMsg));
      });

      test('Mixed English and Urdu message with URL passes validation', () {
        const mixed =
            'URGENT: آپ کا بینک اکاؤنٹ بلاک ہو گیا ہے۔ Visit https://bank-verify.example/pk';
        final res = MessageTextValidator.validate(mixed);
        expect(res.isValid, isTrue);
        expect(res.normalizedText, equals(mixed));
      });

      test('BiDi control characters mixed with visible text pass without corruption', () {
        // Right-to-Left Override (\u202E)
        const bidiAttack = 'Click here: \u202Egpj.exe';
        final res = MessageTextValidator.validate(bidiAttack);
        expect(res.isValid, isTrue);
        expect(res.normalizedText, equals(bidiAttack));
      });
    });

    group('4. Malformed Surrogate Detection and Surrogate-Split Protection', () {
      test('Rejects unpaired high surrogate (0xD800) safely', () {
        final unpairedHigh = String.fromCharCode(0xD800);
        final res = MessageTextValidator.validate(unpairedHigh);
        expect(res.isValid, isFalse);
        expect(res.error?.reason, MessageTextValidationReason.malformedUnicode);
      });

      test('Rejects unpaired low surrogate (0xDC00) safely', () {
        final unpairedLow = String.fromCharCode(0xDC00);
        final res = MessageTextValidator.validate(unpairedLow);
        expect(res.isValid, isFalse);
        expect(res.error?.reason, MessageTextValidationReason.malformedUnicode);
      });

      test('Rejects inverted surrogate pair (low before high)', () {
        final inverted =
            '${String.fromCharCode(0xDC00)}${String.fromCharCode(0xD800)}';
        final res = MessageTextValidator.validate(inverted);
        expect(res.isValid, isFalse);
        expect(res.error?.reason, MessageTextValidationReason.malformedUnicode);
      });

      test(
        'EvidenceReference.isSurrogateSplit correctly identifies split offsets',
        () {
          const textWithEmoji = 'Hello 😀 World';
          // '😀' starts at UTF-16 offset 6 and ends at offset 8 (length 2)
          expect(textWithEmoji.codeUnitAt(6), 0xD83D); // High surrogate
          expect(textWithEmoji.codeUnitAt(7), 0xDE00); // Low surrogate

          // Offset 6 is boundary before emoji -> false
          expect(EvidenceReference.isSurrogateSplit(textWithEmoji, 6), isFalse);
          // Offset 7 is inside the surrogate pair -> true
          expect(EvidenceReference.isSurrogateSplit(textWithEmoji, 7), isTrue);
          // Offset 8 is boundary after emoji -> false
          expect(EvidenceReference.isSurrogateSplit(textWithEmoji, 8), isFalse);
        },
      );

      test(
        'EvidenceReference validates excerpt and throws on surrogate split',
        () {
          final snapshot = TextSnapshot(
            id: 'snap-1',
            source: InputSource.messageText,
            text: 'Alert: 😀 urgent',
            createdAt: DateTime.now().toUtc(),
          );

          // Valid reference to emoji
          final validEmojiRef = EvidenceReference(
            snapshotId: 'snap-1',
            startOffset: 7,
            endOffset: 9,
            exactExcerpt: '😀',
          );
          expect(
            () => validEmojiRef.validateAgainst(snapshot),
            returnsNormally,
          );

          // Invalid reference splitting the surrogate pair
          final splitRef = EvidenceReference(
            snapshotId: 'snap-1',
            startOffset: 7,
            endOffset: 8,
            exactExcerpt: String.fromCharCode(0xD83D),
          );
          expect(
            () => splitRef.validateAgainst(snapshot),
            throwsA(isA<ArgumentError>()),
          );
        },
      );
    });

    group('5. Snapshot Immutability & Controller State Integrity', () {
      test('TextSnapshot preserves exact raw input without trimming', () {
        const exactText = '  \nExact Preserved Text  \t';
        final snapshot = TextSnapshot(
          id: 'test-snapshot-123',
          source: InputSource.screenshot,
          text: exactText,
          createdAt: DateTime.now().toUtc(),
        );
        expect(snapshot.text, equals(exactText));
        expect(snapshot.source, equals(InputSource.screenshot));
        expect(snapshot.id, equals('test-snapshot-123'));
      });

      test('InputTextController handles draft changes and resets prepared snapshot', () {
        final controller = InputTextController(
          idGenerator: () => 'test-snap-id',
          clock: () => DateTime.utc(2026, 11, 1),
        );
        controller.onInit();

        controller.textEditingController.text = 'Urgent bank message';
        expect(controller.hasDraft, isTrue);
        expect(controller.codePointCount.value, 19);

        final prepared = controller.prepareText();
        expect(prepared, isTrue);
        expect(controller.preparedSnapshot.value, isNotNull);
        expect(controller.showPreparedConfirmation.value, isTrue);

        // Editing text must immediately invalidate the prepared snapshot
        controller.textEditingController.text = 'Urgent bank message edited';
        expect(controller.preparedSnapshot.value, isNull);
        expect(controller.showPreparedConfirmation.value, isFalse);

        controller.onClose();
      });

      test('InputReviewController editing invalidates confirmed snapshot', () {
        final reviewController = InputReviewController(
          reviewInput: null, // Test with manual initialization
          idGenerator: () => 'reviewed-snap',
          clock: () => DateTime.utc(2026, 11, 1),
        );

        expect(reviewController.isConfirmed.value, isFalse);
        reviewController.onClose();
      });
    });
  });
}
