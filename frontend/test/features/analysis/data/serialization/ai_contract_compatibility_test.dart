import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/data/serialization/analysis_finding_codec.dart';
import 'package:trustcue_mobile/features/analysis/data/serialization/analysis_report_codec.dart';
import 'package:trustcue_mobile/features/analysis/data/serialization/evidence_reference_codec.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('Module 34 - AI Contract Compatibility Tests', () {
    const findingCodec = AnalysisFindingCodec();
    const evidenceCodec = EvidenceReferenceCodec();
    const reportCodec = AnalysisReportCodec();

    test('decodes remote AI finding produced by backend validator', () {
      final snapshot = TextSnapshot(
        id: 'snap-ai-01',
        text: 'CRITICAL: Send your password to verify@secure-bank.com now.',
        source: InputSource.messageText,
        createdAt: DateTime.parse('2026-10-15T12:00:00Z'),
      );

      final backendFindingJson = {
        'id': 'finding-7b8192a3-5c21-4f9e-bc3d-112233445566',
        'category': 'requests_for_credentials',
        'explanation': 'Message requests account password submission to an external address.',
        'origin': 'remoteAi',
        'producerId': 'trustcue-ai-groq',
        'evidence': [
          {
            'snapshotId': 'snap-ai-01',
            'startOffset': 10,
            'endOffset': 28,
            'exactExcerpt': 'Send your password',
          },
        ],
      };

      final finding = findingCodec.decode(backendFindingJson);

      expect(finding.id, equals('finding-7b8192a3-5c21-4f9e-bc3d-112233445566'));
      expect(finding.category, equals('requests_for_credentials'));
      expect(finding.origin, equals(FindingOrigin.remoteAi));
      expect(finding.producerId, equals('trustcue-ai-groq'));
      expect(finding.evidence.length, equals(1));

      final ev = finding.evidence.first;
      expect(ev.snapshotId, equals('snap-ai-01'));
      expect(ev.startOffset, equals(10));
      expect(ev.endOffset, equals(28));
      expect(ev.exactExcerpt, equals('Send your password'));

      // Validate directly against snapshot
      expect(() => finding.validateAgainst(snapshot), returnsNormally);
    });

    test('validates UTF-16 code units across supplementary emoji characters', () {
      const shield = '\u{1F6E1}'; // 🛡 (2 UTF-16 code units)
      const text = 'Urgent $shield password alert';
      // 'Urgent ' is 7 code units
      // shield is 2 code units -> offsets [7, 9)
      // ' password' is 9 code units -> starts at offset 9, ends at 9 + 9 = 18

      final snapshot = TextSnapshot(
        id: 'snap-emoji-01',
        text: text,
        source: InputSource.messageText,
        createdAt: DateTime.parse('2026-10-15T12:00:00Z'),
      );

      final excerpt = 'password';
      final startOffset = text.indexOf(excerpt); // 9
      final endOffset = startOffset + excerpt.length; // 17

      final evidenceJson = {
        'snapshotId': 'snap-emoji-01',
        'startOffset': startOffset,
        'endOffset': endOffset,
        'exactExcerpt': excerpt,
      };

      final ev = evidenceCodec.decode(evidenceJson);
      expect(ev.startOffset, equals(10));
      expect(ev.endOffset, equals(18));
      expect(() => ev.validateAgainst(snapshot), returnsNormally);
    });

    test('rejects evidence offset that splits a UTF-16 surrogate pair', () {
      const shield = '\u{1F6E1}'; // 🛡 (2 UTF-16 code units: 0xD83D 0xDEE1)
      const text = 'Security $shield warning';
      // 'Security ' is 9 code units. shield starts at 9, trail is at 10.
      final snapshot = TextSnapshot(
        id: 'snap-surrogate-split',
        text: text,
        source: InputSource.messageText,
        createdAt: DateTime.parse('2026-10-15T12:00:00Z'),
      );

      // Offset 10 splits the shield surrogate pair (between 0xD83D and 0xDEE1)
      final splitSubstring = text.substring(10, 12);
      expect(
        () => EvidenceReference(
          snapshotId: 'snap-surrogate-split',
          startOffset: 10,
          endOffset: 12,
          exactExcerpt: splitSubstring,
        ).validateAgainst(snapshot),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('splits a UTF-16 surrogate pair'),
        )),
      );
    });

    test('full AnalysisReport integration with remote AI findings and honest limitations', () {
      final reportJson = {
        'id': 'rep-server-uuid-1234',
        'schemaVersion': 1,
        'snapshot': {
          'id': 'snap-full-01',
          'source': 'messageText',
          'text': 'Hello, your package is ready.',
          'createdAt': '2026-10-15T12:00:00.000Z',
        },
        'analyzedAt': '2026-10-15T12:01:00.000Z',
        'findings': <Map<String, dynamic>>[],
        'limitations': [
          'No scam warning indicators were detected in the evaluated text snapshot. '
          'This does not establish that the communication is safe or authentic.',
        ],
        'suggestedActions': [
          'Verify official tracking directly through the carrier application.',
        ],
      };

      final reportResult = reportCodec.decodeJsonString(jsonEncode(reportJson));
      expect(reportResult.isSuccess, isTrue);

      final report = reportResult.valueOrNull!;
      expect(report.id, equals('rep-server-uuid-1234'));
      expect(report.findings, isEmpty);
      expect(report.limitations.first, contains('does not establish that the communication is safe'));
    });
  });
}
