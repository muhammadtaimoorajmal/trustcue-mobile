import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('TextSnapshot Model Tests', () {
    test('Constructs valid snapshot and normalizes createdAt to UTC', () {
      final localTime = DateTime(2026, 10, 11, 14, 30);
      final snapshot = TextSnapshot(
        id: 'snap-101',
        source: InputSource.messageText,
        text: 'Urgent: Verify your banking details now.',
        createdAt: localTime,
      );

      expect(snapshot.id, 'snap-101');
      expect(snapshot.source, InputSource.messageText);
      expect(snapshot.text, 'Urgent: Verify your banking details now.');
      expect(snapshot.createdAt.isUtc, isTrue);
      expect(snapshot.createdAt, equals(localTime.toUtc()));
    });

    test('Allows empty text as a valid draft', () {
      final snapshot = TextSnapshot(
        id: 'draft-001',
        source: InputSource.screenshot,
        text: '',
        createdAt: DateTime.utc(2026, 10, 11, 12, 0),
      );

      expect(snapshot.text, isEmpty);
      expect(snapshot.id, 'draft-001');
    });

    test('Rejects empty or whitespace-only identifier', () {
      expect(
        () => TextSnapshot(
          id: '',
          source: InputSource.link,
          text: 'https://example.com',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => TextSnapshot(
          id: '   \t\n',
          source: InputSource.qrCode,
          text: 'https://example.com',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('Supports all InputSource enum variants', () {
      const sources = [
        InputSource.messageText,
        InputSource.screenshot,
        InputSource.link,
        InputSource.qrCode,
      ];

      for (final src in sources) {
        final snap = TextSnapshot(
          id: 'id-${src.name}',
          source: src,
          text: 'Content',
          createdAt: DateTime.utc(2026, 10, 11),
        );
        expect(snap.source, src);
      }
    });

    test('Preserves multiline, Urdu, and emoji characters exactly', () {
      const complexText =
          'آپ کا اکاؤنٹ بلاک کر دیا گیا ہے۔\n'
          'Please click here: https://example.com/verify\n'
          'Warning 🚨 Urgent Action Required! 💳';

      final snap = TextSnapshot(
        id: 'snap-complex',
        source: InputSource.messageText,
        text: complexText,
        createdAt: DateTime.utc(2026, 10, 11),
      );

      expect(snap.text, complexText);
      expect(snap.text, contains('آپ کا اکاؤنٹ'));
      expect(snap.text, contains('🚨'));
    });

    test('Safe toString does not expose raw text payload', () {
      final snap = TextSnapshot(
        id: 'snap-confidential',
        source: InputSource.messageText,
        text: 'Private OTP 998877 for bank login',
        createdAt: DateTime.utc(2026, 10, 11, 12, 0),
      );

      final str = snap.toString();
      expect(str, contains('snap-confidential'));
      expect(str, contains('textLength: 33'));
      expect(str, isNot(contains('998877')));
      expect(str, isNot(contains('Private OTP')));
    });

    test('Equality and hashCode respect snapshot values', () {
      final snap1 = TextSnapshot(
        id: 'snap-1',
        source: InputSource.messageText,
        text: 'Text A',
        createdAt: DateTime.utc(2026, 10, 11, 10, 0),
      );
      final snap2 = TextSnapshot(
        id: 'snap-1',
        source: InputSource.messageText,
        text: 'Text A',
        createdAt: DateTime.utc(2026, 10, 11, 10, 0),
      );
      final snap3 = TextSnapshot(
        id: 'snap-2',
        source: InputSource.messageText,
        text: 'Text A',
        createdAt: DateTime.utc(2026, 10, 11, 10, 0),
      );

      expect(snap1, equals(snap2));
      expect(snap1.hashCode, equals(snap2.hashCode));
      expect(snap1, isNot(equals(snap3)));
    });
  });
}
