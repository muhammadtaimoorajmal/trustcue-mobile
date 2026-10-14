import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('EvidenceValidator Tests', () {
    late TextSnapshot snapshot;

    setUp(() {
      snapshot = TextSnapshot(
        id: 'snap-1',
        text: 'Alert: Your account has been suspended. Click here to verify.',
        source: InputSource.messageText,
        createdAt: DateTime.now().toUtc(),
      );
    });

    test('createReference extracts exact excerpt and offsets correctly', () {
      final ref = EvidenceValidator.createReference(
        snapshot: snapshot,
        startOffset: 7,
        endOffset: 39,
      );

      expect(ref.snapshotId, 'snap-1');
      expect(ref.startOffset, 7);
      expect(ref.endOffset, 39);
      expect(ref.exactExcerpt, 'Your account has been suspended.');
    });

    test('validateFinding succeeds for valid finding matching snapshot', () {
      final ref = EvidenceValidator.createReference(
        snapshot: snapshot,
        startOffset: 7,
        endOffset: 39,
      );

      final finding = AnalysisFinding(
        id: 'f-1',
        category: 'account_suspension_or_threats',
        explanation: 'Suspension threat observed.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.account.threat',
        evidence: [ref],
      );

      expect(
        () => EvidenceValidator.validateFinding(
          finding,
          snapshot,
          expectedProducerId: 'rule.account.threat',
          expectedCategoryId: 'account_suspension_or_threats',
        ),
        returnsNormally,
      );
    });

    test('Rejects finding with non-localRule origin', () {
      final ref = EvidenceValidator.createReference(
        snapshot: snapshot,
        startOffset: 0,
        endOffset: 5,
      );

      final finding = AnalysisFinding(
        id: 'f-remote',
        category: 'urgency_or_pressure',
        explanation: 'AI finding.',
        origin: FindingOrigin.remoteAi,
        producerId: 'rule.test',
        evidence: [ref],
      );

      expect(
        () => EvidenceValidator.validateFinding(finding, snapshot),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('must have origin FindingOrigin.localRule'),
          ),
        ),
      );
    });

    test('Rejects finding with mismatched producer ID', () {
      final ref = EvidenceValidator.createReference(
        snapshot: snapshot,
        startOffset: 0,
        endOffset: 5,
      );

      final finding = AnalysisFinding(
        id: 'f-mismatch-producer',
        category: 'urgency_or_pressure',
        explanation: 'Test',
        origin: FindingOrigin.localRule,
        producerId: 'rule.other.producer',
        evidence: [ref],
      );

      expect(
        () => EvidenceValidator.validateFinding(
          finding,
          snapshot,
          expectedProducerId: 'rule.expected.producer',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('does not match rule producer'),
          ),
        ),
      );
    });

    test('Rejects finding with mismatched category ID', () {
      final ref = EvidenceValidator.createReference(
        snapshot: snapshot,
        startOffset: 0,
        endOffset: 5,
      );

      final finding = AnalysisFinding(
        id: 'f-mismatch-cat',
        category: 'requests_for_payment',
        explanation: 'Test',
        origin: FindingOrigin.localRule,
        producerId: 'rule.test',
        evidence: [ref],
      );

      expect(
        () => EvidenceValidator.validateFinding(
          finding,
          snapshot,
          expectedCategoryId: 'urgency_or_pressure',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('does not match rule category'),
          ),
        ),
      );
    });

    test('Rejects evidence referencing mismatched snapshot ID', () {
      final wrongRef = EvidenceReference(
        snapshotId: 'different-snapshot-id',
        startOffset: 0,
        endOffset: 5,
        exactExcerpt: 'Alert',
      );

      expect(
        () => EvidenceValidator.validateReference(wrongRef, snapshot),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Evidence references snapshot'),
          ),
        ),
      );
    });

    test('Rejects evidence with mismatched excerpt string', () {
      final wrongExcerptRef = EvidenceReference(
        snapshotId: 'snap-1',
        startOffset: 0,
        endOffset: 5,
        exactExcerpt: 'Wrong',
      );

      expect(
        () => EvidenceValidator.validateReference(wrongExcerptRef, snapshot),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Evidence excerpt mismatch'),
          ),
        ),
      );
    });

    test('Rejects evidence exceeding snapshot text bounds', () {
      final outOfBoundsRef = EvidenceReference(
        snapshotId: 'snap-1',
        startOffset: 0,
        endOffset: snapshot.text.length + 10,
        exactExcerpt: '${snapshot.text}          ',
      );

      expect(
        () => EvidenceValidator.validateReference(outOfBoundsRef, snapshot),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('exceeds snapshot text length'),
          ),
        ),
      );
    });

    test('Rejects evidence that splits UTF-16 surrogate pairs (emoji)', () {
      // ⚠️ is code units [0x26A0, 0xFE0F], 🚨 is [0xD83D, 0xDEA8] (high: 0xD83D, low: 0xDEA8)
      final emojiSnapshot = TextSnapshot(
        id: 'snap-emoji',
        text: 'Warning 🚨 Urgent!',
        source: InputSource.messageText,
        createdAt: DateTime.now().toUtc(),
      );

      // In 'Warning 🚨 Urgent!':
      // 'Warning ' length is 8.
      // 🚨 is at indices 8 and 9 (0xD83D at 8, 0xDEA8 at 9).
      // Splitting at index 9 splits the surrogate pair!
      expect(
        () => EvidenceValidator.createReference(
          snapshot: emojiSnapshot,
          startOffset: 0,
          endOffset: 9, // splits the high/low surrogate of 🚨
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('splits a UTF-16 surrogate pair'),
          ),
        ),
      );
    });
  });
}
