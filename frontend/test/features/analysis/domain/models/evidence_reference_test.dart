import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('EvidenceReference Model Tests', () {
    final baseSnapshot = TextSnapshot(
      id: 'snap-001',
      source: InputSource.messageText,
      text: 'Dear user, your bank account is suspended immediately.',
      createdAt: DateTime.utc(2026, 10, 11, 12, 0),
    );

    test(
      'Valid construction and successful validation against matching snapshot',
      () {
        final evidence = EvidenceReference(
          snapshotId: 'snap-001',
          startOffset: 16,
          endOffset: 41,
          exactExcerpt: 'bank account is suspended',
        );

        expect(evidence.snapshotId, 'snap-001');
        expect(evidence.startOffset, 16);
        expect(evidence.endOffset, 41);
        expect(evidence.exactExcerpt, 'bank account is suspended');

        // Validates cleanly against matching snapshot
        expect(() => evidence.validateAgainst(baseSnapshot), returnsNormally);
      },
    );

    test('Rejects empty snapshot ID', () {
      expect(
        () => EvidenceReference(
          snapshotId: '',
          startOffset: 0,
          endOffset: 4,
          exactExcerpt: 'Dear',
        ),
        throwsArgumentError,
      );
    });

    test('Rejects negative start offset', () {
      expect(
        () => EvidenceReference(
          snapshotId: 'snap-001',
          startOffset: -1,
          endOffset: 4,
          exactExcerpt: 'Dear',
        ),
        throwsArgumentError,
      );
    });

    test('Rejects end offset less than or equal to start offset', () {
      expect(
        () => EvidenceReference(
          snapshotId: 'snap-001',
          startOffset: 10,
          endOffset: 10,
          exactExcerpt: '',
        ),
        throwsArgumentError,
      );

      expect(
        () => EvidenceReference(
          snapshotId: 'snap-001',
          startOffset: 10,
          endOffset: 5,
          exactExcerpt: 'wrong',
        ),
        throwsArgumentError,
      );
    });

    test('Rejects excerpt length mismatch with offset range', () {
      expect(
        () => EvidenceReference(
          snapshotId: 'snap-001',
          startOffset: 0,
          endOffset: 4,
          exactExcerpt: 'Dear user', // length 9 != 4
        ),
        throwsArgumentError,
      );
    });

    test('Validation rejects snapshot ID mismatch', () {
      final evidence = EvidenceReference(
        snapshotId: 'snap-DIFFERENT',
        startOffset: 0,
        endOffset: 4,
        exactExcerpt: 'Dear',
      );

      expect(() => evidence.validateAgainst(baseSnapshot), throwsArgumentError);
    });

    test('Validation rejects end offset out of snapshot bounds', () {
      final shortSnapshot = TextSnapshot(
        id: 'snap-001',
        source: InputSource.messageText,
        text: 'Short',
        createdAt: DateTime.utc(2026, 10, 11),
      );

      final evidence = EvidenceReference(
        snapshotId: 'snap-001',
        startOffset: 0,
        endOffset: 10,
        exactExcerpt: '0123456789',
      );

      expect(
        () => evidence.validateAgainst(shortSnapshot),
        throwsArgumentError,
      );
    });

    test('Validation rejects excerpt mismatch at specified offsets', () {
      final evidence = EvidenceReference(
        snapshotId: 'snap-001',
        startOffset: 0,
        endOffset: 4,
        exactExcerpt: 'Fail', // Actual substring at [0, 4) is 'Dear'
      );

      expect(() => evidence.validateAgainst(baseSnapshot), throwsArgumentError);
    });

    test('Rejects boundaries that split UTF-16 surrogate pairs', () {
      // "Warning 🚨 now!"
      // 'Warning ' length = 8
      // '🚨' (U+1F6A8) in UTF-16 consists of 2 code units: [0xD83D, 0xDC68] at index 8 and 9.
      // ' now!' starts at index 10.
      final emojiSnapshot = TextSnapshot(
        id: 'snap-emoji',
        source: InputSource.messageText,
        text: 'Warning 🚨 now!',
        createdAt: DateTime.utc(2026, 10, 11),
      );

      // Start splits surrogate pair (index 9)
      final splitStart = EvidenceReference(
        snapshotId: 'snap-emoji',
        startOffset: 9,
        endOffset: 14,
        exactExcerpt: emojiSnapshot.text.substring(9, 14),
      );
      expect(
        () => splitStart.validateAgainst(emojiSnapshot),
        throwsArgumentError,
      );

      // End splits surrogate pair (index 9)
      final splitEnd = EvidenceReference(
        snapshotId: 'snap-emoji',
        startOffset: 0,
        endOffset: 9,
        exactExcerpt: emojiSnapshot.text.substring(0, 9),
      );
      expect(
        () => splitEnd.validateAgainst(emojiSnapshot),
        throwsArgumentError,
      );

      // Proper boundary enclosing the full emoji [8, 10) succeeds
      final validEmojiEvidence = EvidenceReference(
        snapshotId: 'snap-emoji',
        startOffset: 8,
        endOffset: 10,
        exactExcerpt: '🚨',
      );
      expect(
        () => validEmojiEvidence.validateAgainst(emojiSnapshot),
        returnsNormally,
      );
    });

    test('Safe toString does not dump excerpt text', () {
      final evidence = EvidenceReference(
        snapshotId: 'snap-001',
        startOffset: 10,
        endOffset: 20,
        exactExcerpt: '0123456789',
      );
      final str = evidence.toString();
      expect(str, contains('snapshot: snap-001'));
      expect(str, contains('[10, 20)'));
      expect(str, isNot(contains('0123456789')));
    });

    test('Equality and hashCode', () {
      final e1 = EvidenceReference(
        snapshotId: 's1',
        startOffset: 0,
        endOffset: 5,
        exactExcerpt: 'hello',
      );
      final e2 = EvidenceReference(
        snapshotId: 's1',
        startOffset: 0,
        endOffset: 5,
        exactExcerpt: 'hello',
      );
      final e3 = EvidenceReference(
        snapshotId: 's1',
        startOffset: 0,
        endOffset: 5,
        exactExcerpt: 'world',
      );

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
      expect(e1, isNot(equals(e3)));
    });
  });
}
