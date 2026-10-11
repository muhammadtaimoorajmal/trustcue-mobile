import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/input/data/serialization/text_snapshot_codec.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('TextSnapshotCodec Serialization Tests', () {
    const codec = TextSnapshotCodec();

    test('Encodes and decodes valid snapshot in exact round-trip', () {
      final snapshot = TextSnapshot(
        id: 'snap-roundtrip',
        source: InputSource.link,
        text: 'https://security-verify.example.com/login?token=abc',
        createdAt: DateTime.utc(2026, 10, 11, 15, 45, 30),
      );

      final encoded = codec.encode(snapshot);
      expect(encoded['id'], 'snap-roundtrip');
      expect(encoded['source'], 'link');
      expect(
        encoded['text'],
        'https://security-verify.example.com/login?token=abc',
      );
      expect(encoded['createdAt'], '2026-10-11T15:45:30.000Z');

      final decoded = codec.decode(encoded);
      expect(decoded, equals(snapshot));
    });

    test(
      'Preserves Unicode, Urdu characters, emojis, and newlines exactly',
      () {
        final snapshot = TextSnapshot(
          id: 'snap-urdu-emoji',
          source: InputSource.messageText,
          text: 'سلام! آپ کا پاس ورڈ ختم ہو چکا ہے 🛑\nنئے لنک پر جائیں: https://example.com',
          createdAt: DateTime.utc(2026, 10, 11, 8, 30),
        );

        final encoded = codec.encode(snapshot);
        final decoded = codec.decode(encoded);

        expect(decoded.text, snapshot.text);
        expect(decoded, equals(snapshot));
      },
    );

    test('Normalizes valid non-UTC timezone offset to UTC on decode', () {
      final json = {
        'id': 'snap-offset',
        'source': 'qrCode',
        'text': 'PAYMENT_QR_CODE',
        'createdAt': '2026-10-11T17:00:00+05:00', // 12:00:00 UTC
      };

      final decoded = codec.decode(json);
      expect(decoded.createdAt.isUtc, isTrue);
      expect(decoded.createdAt.hour, 12);
      expect(decoded.createdAt.minute, 0);
    });

    test('Rejects timestamps without explicit timezone indicator', () {
      final json = {
        'id': 'snap-no-tz',
        'source': 'messageText',
        'text': 'Hello',
        'createdAt': '2026-10-11T12:00:00', // missing Z or offset
      };

      expect(() => codec.decode(json), throwsFormatException);
    });

    test('Rejects missing required fields', () {
      expect(
        () => codec.decode({
          'source': 'messageText',
          'text': 'Hello',
          'createdAt': '2026-10-11T12:00:00Z',
        }),
        throwsFormatException,
      );

      expect(
        () => codec.decode({
          'id': 'id-1',
          'text': 'Hello',
          'createdAt': '2026-10-11T12:00:00Z',
        }),
        throwsFormatException,
      );

      expect(
        () => codec.decode({
          'id': 'id-1',
          'source': 'messageText',
          'createdAt': '2026-10-11T12:00:00Z',
        }),
        throwsFormatException,
      );

      expect(
        () => codec.decode({
          'id': 'id-1',
          'source': 'messageText',
          'text': 'Hello',
        }),
        throwsFormatException,
      );
    });

    test('Rejects incorrect field types', () {
      expect(
        () => codec.decode({
          'id': 12345, // int instead of String
          'source': 'messageText',
          'text': 'Hello',
          'createdAt': '2026-10-11T12:00:00Z',
        }),
        throwsFormatException,
      );

      expect(
        () => codec.decode({
          'id': 'id-1',
          'source': 99, // int instead of String
          'text': 'Hello',
          'createdAt': '2026-10-11T12:00:00Z',
        }),
        throwsFormatException,
      );
    });

    test('Rejects unknown enum value for source', () {
      final json = {
        'id': 'id-1',
        'source': 'carrierPigeon',
        'text': 'Hello',
        'createdAt': '2026-10-11T12:00:00Z',
      };

      expect(() => codec.decode(json), throwsFormatException);
    });

    test('Ignores unknown extra fields in version 1', () {
      final json = {
        'id': 'snap-extra',
        'source': 'screenshot',
        'text': 'Recognized text',
        'createdAt': '2026-10-11T12:00:00Z',
        'futureMetadata': {'debugFlag': true, 'confidenceScore': 0.99},
        'unrecognizedProperty': 'ignored',
      };

      final decoded = codec.decode(json);
      expect(decoded.id, 'snap-extra');
      expect(decoded.source, InputSource.screenshot);
    });
  });
}
