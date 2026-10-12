import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/models/incoming_share_payload.dart';

void main() {
  group('IncomingSharePayload Tests', () {
    test('Text payload properties and getters', () {
      final payload = IncomingSharePayload.text(
        eventId: 'evt-1',
        text: 'Suspicious bank link: https://example.com',
      );

      expect(payload.type, IncomingShareType.text);
      expect(payload.eventId, 'evt-1');
      expect(payload.text, 'Suspicious bank link: https://example.com');
      expect(payload.stagedImagePath, isNull);
      expect(payload.hasText, isTrue);
      expect(payload.hasImage, isFalse);
      expect(payload.isMixed, isFalse);
      expect(payload.isUnsupported, isFalse);
    });

    test('Image payload properties and getters', () {
      final payload = IncomingSharePayload.image(
        eventId: 'evt-2',
        stagedImagePath:
            '/data/user/0/cache/trustcue_incoming_shares/share_123.png',
        mimeType: 'image/png',
      );

      expect(payload.type, IncomingShareType.image);
      expect(payload.eventId, 'evt-2');
      expect(
        payload.stagedImagePath,
        '/data/user/0/cache/trustcue_incoming_shares/share_123.png',
      );
      expect(payload.mimeType, 'image/png');
      expect(payload.text, isNull);
      expect(payload.hasText, isFalse);
      expect(payload.hasImage, isTrue);
      expect(payload.isMixed, isFalse);
      expect(payload.isUnsupported, isFalse);
    });

    test('Mixed payload properties and getters', () {
      final payload = IncomingSharePayload.mixed(
        eventId: 'evt-3',
        text: 'Look at this screenshot',
        stagedImagePath:
            '/data/user/0/cache/trustcue_incoming_shares/share_456.jpg',
        mimeType: 'image/jpeg',
      );

      expect(payload.type, IncomingShareType.mixed);
      expect(payload.eventId, 'evt-3');
      expect(payload.text, 'Look at this screenshot');
      expect(
        payload.stagedImagePath,
        '/data/user/0/cache/trustcue_incoming_shares/share_456.jpg',
      );
      expect(payload.mimeType, 'image/jpeg');
      expect(payload.hasText, isTrue);
      expect(payload.hasImage, isTrue);
      expect(payload.isMixed, isTrue);
      expect(payload.isUnsupported, isFalse);
    });

    test('Unsupported payload properties and getters', () {
      final payload = IncomingSharePayload.unsupported(
        eventId: 'evt-4',
        errorMessage: 'Multiple images shared at once are not supported.',
      );

      expect(payload.type, IncomingShareType.unsupported);
      expect(payload.eventId, 'evt-4');
      expect(
        payload.errorMessage,
        'Multiple images shared at once are not supported.',
      );
      expect(payload.hasText, isFalse);
      expect(payload.hasImage, isFalse);
      expect(payload.isMixed, isFalse);
      expect(payload.isUnsupported, isTrue);
    });

    test('fromMap parses map representation correctly', () {
      final map = {
        'eventId': 'evt-map-1',
        'type': 'text',
        'text': 'Shared text note',
      };
      final payload = IncomingSharePayload.fromMap(map);

      expect(payload.eventId, 'evt-map-1');
      expect(payload.type, IncomingShareType.text);
      expect(payload.text, 'Shared text note');
    });

    test('fromMap parses image map correctly', () {
      final map = {
        'eventId': 'evt-map-2',
        'type': 'image',
        'stagedImagePath': '/cache/image.png',
        'mimeType': 'image/png',
      };
      final payload = IncomingSharePayload.fromMap(map);

      expect(payload.eventId, 'evt-map-2');
      expect(payload.type, IncomingShareType.image);
      expect(payload.stagedImagePath, '/cache/image.png');
      expect(payload.mimeType, 'image/png');
    });

    test('fromMap parses mixed map correctly', () {
      final map = {
        'eventId': 'evt-map-3',
        'type': 'mixed',
        'text': 'Attached caption',
        'stagedImagePath': '/cache/image.jpg',
        'mimeType': 'image/jpeg',
      };
      final payload = IncomingSharePayload.fromMap(map);

      expect(payload.eventId, 'evt-map-3');
      expect(payload.type, IncomingShareType.mixed);
      expect(payload.text, 'Attached caption');
      expect(payload.stagedImagePath, '/cache/image.jpg');
      expect(payload.mimeType, 'image/jpeg');
    });

    test('fromMap parses unsupported map correctly', () {
      final map = {
        'eventId': 'evt-map-4',
        'type': 'unsupported',
        'errorMessage': 'Unsupported content format',
      };
      final payload = IncomingSharePayload.fromMap(map);

      expect(payload.eventId, 'evt-map-4');
      expect(payload.type, IncomingShareType.unsupported);
      expect(payload.errorMessage, 'Unsupported content format');
    });
  });
}
