import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/upload_consent.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('UploadConsent Domain Model Tests', () {
    late TextSnapshot testSnapshot;
    const testAccountId = 'user-12345-uuid';

    setUp(() {
      testSnapshot = TextSnapshot(
        id: 'snapshot-abc-001',
        text: 'Urgent: Wire \$500 to account 987654321 immediately.',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );
    });

    test('affirmative consent initializes with valid defaults', () {
      final consent = UploadConsent.affirmative(
        snapshot: testSnapshot,
        accountId: testAccountId,
      );

      expect(consent.granted, isTrue);
      expect(consent.disclosureVersion, equals('1.0.0'));
      expect(consent.recipient, equals('trustcue-backend'));
      expect(consent.provider, equals('groq-cloud'));
      expect(consent.snapshotId, equals(testSnapshot.id));
      expect(consent.text, equals(testSnapshot.text));
      expect(consent.accountId, equals(testAccountId));
      expect(consent.timestamp, isNotNull);
    });

    test('declined consent sets granted to false', () {
      final consent = UploadConsent.declined(
        snapshot: testSnapshot,
        accountId: testAccountId,
      );

      expect(consent.granted, isFalse);
      expect(
        consent.isValidFor(testSnapshot, candidateAccountId: testAccountId),
        isFalse,
      );
    });

    test('isValidFor passes on exact snapshot and account match', () {
      final consent = UploadConsent.affirmative(
        snapshot: testSnapshot,
        accountId: testAccountId,
      );

      expect(
        consent.isValidFor(testSnapshot, candidateAccountId: testAccountId),
        isTrue,
      );
    });

    test('isValidFor fails if snapshotId differs', () {
      final consent = UploadConsent.affirmative(
        snapshot: testSnapshot,
        accountId: testAccountId,
      );

      final differentSnapshot = TextSnapshot(
        id: 'snapshot-different-999',
        text: testSnapshot.text,
        source: testSnapshot.source,
        createdAt: testSnapshot.createdAt,
      );

      expect(
        consent.isValidFor(
          differentSnapshot,
          candidateAccountId: testAccountId,
        ),
        isFalse,
      );
    });

    test('isValidFor fails if text is altered even by 1 character', () {
      final consent = UploadConsent.affirmative(
        snapshot: testSnapshot,
        accountId: testAccountId,
      );

      final editedSnapshot = TextSnapshot(
        id: testSnapshot.id,
        text: '${testSnapshot.text} ',
        source: testSnapshot.source,
        createdAt: testSnapshot.createdAt,
      );

      expect(
        consent.isValidFor(editedSnapshot, candidateAccountId: testAccountId),
        isFalse,
      );
    });

    test('isValidFor fails if user account changes or signs out', () {
      final consent = UploadConsent.affirmative(
        snapshot: testSnapshot,
        accountId: testAccountId,
      );

      // Switched account
      expect(
        consent.isValidFor(
          testSnapshot,
          candidateAccountId: 'different-user-777',
        ),
        isFalse,
      );

      // Signed out (null account)
      expect(
        consent.isValidFor(testSnapshot, candidateAccountId: null),
        isFalse,
      );
    });

    test('isValidFor fails if disclosureVersion is outdated', () {
      final outdatedConsent = UploadConsent(
        granted: true,
        disclosureVersion: '0.9.0',
        timestamp: DateTime.now().toUtc(),
        recipient: 'trustcue-backend',
        provider: 'groq-cloud',
        snapshotId: testSnapshot.id,
        text: testSnapshot.text,
        accountId: testAccountId,
      );

      expect(
        outdatedConsent.isValidFor(
          testSnapshot,
          candidateAccountId: testAccountId,
        ),
        isFalse,
      );
    });

    test(
      'toJson produces expected schema structure for backend transmission',
      () {
        final nowUtc = DateTime.utc(2026, 10, 15, 14, 30, 0);
        final consent = UploadConsent(
          granted: true,
          disclosureVersion: '1.0.0',
          timestamp: nowUtc,
          recipient: 'trustcue-backend',
          provider: 'groq-cloud',
          snapshotId: testSnapshot.id,
          text: testSnapshot.text,
          accountId: testAccountId,
        );

        final json = consent.toJson();

        expect(
          json,
          equals({
            'granted': true,
            'disclosureVersion': '1.0.0',
            'timestamp': '2026-10-15T14:30:00.000Z',
            'recipient': 'trustcue-backend',
            'provider': 'groq-cloud',
          }),
        );
      },
    );
  });
}
