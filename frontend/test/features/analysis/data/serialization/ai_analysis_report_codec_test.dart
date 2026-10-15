import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/data/serialization/ai_analysis_report_codec.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('AiAnalysisReportCodec Tests', () {
    const codec = AiAnalysisReportCodec();
    const snapshotText = 'Urgent: Wire \$500 to account 987654321 immediately.';
    final snapshot = TextSnapshot(
      id: 'snap-001',
      text: snapshotText,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
    );

    final validPayload = {
      'reportId': 'rep-ai-12345',
      'snapshotId': 'snap-001',
      'provider': 'groq',
      'model': 'qwen/qwen3.8-27b',
      'analyzedAt': '2026-10-15T12:05:00Z',
      'factualSummary':
          'Observed high urgency and direct payment solicitation.',
      'findings': [
        {
          'id': 'ai-finding-1',
          'category': 'urgency',
          'explanation': 'Demands immediate money transfer to induce panic.',
          'origin': 'remoteAi',
          'producerId': 'groq-qwen3.8-27b',
          'evidence': [
            {'startOffset': 0, 'endOffset': 6, 'exactExcerpt': 'Urgent'},
          ],
        },
      ],
      'uncertaintyNotes': [
        'AI assessment identifies potential social engineering cues and does not guarantee safety.',
      ],
      'suggestedActions': [
        {
          'id': 'act-1',
          'title': 'Verify independently',
          'description':
              'Contact the recipient through known authentic channels.',
          'priority': 'immediate',
          'supportingCategoryIds': ['urgency'],
          'isConditionalPostAction': false,
        },
      ],
    };

    test('decodes valid payload successfully', () {
      final report = codec.decode(validPayload);

      expect(report.reportId, equals('rep-ai-12345'));
      expect(report.snapshotId, equals('snap-001'));
      expect(report.provider, equals('groq'));
      expect(report.model, equals('qwen/qwen3.8-27b'));
      expect(report.factualSummary, contains('high urgency'));
      expect(report.findings.length, equals(1));
      expect(report.findings.first.origin, equals(FindingOrigin.remoteAi));
      expect(
        report.findings.first.evidence.first.exactExcerpt,
        equals('Urgent'),
      );
      expect(report.uncertaintyNotes.length, equals(1));
      expect(report.suggestedActions.length, equals(1));
      expect(
        report.suggestedActions.first.priority,
        equals(AssessmentActionPriority.immediate),
      );

      // Validates cleanly against matching snapshot
      expect(() => report.validateAgainst(snapshot), returnsNormally);
    });

    test('decodes empty findings (no-match) successfully', () {
      final noMatchPayload = Map<String, dynamic>.from(validPayload)
        ..['findings'] = []
        ..['factualSummary'] = 'No explicit warning patterns observed.';

      final report = codec.decode(noMatchPayload);

      expect(report.findings, isEmpty);
      expect(
        report.factualSummary,
        equals('No explicit warning patterns observed.'),
      );
      expect(() => report.validateAgainst(snapshot), returnsNormally);
    });

    test('throws FormatException when required fields are missing', () {
      final missingReportId = Map<String, dynamic>.from(validPayload)
        ..remove('reportId');
      expect(() => codec.decode(missingReportId), throwsFormatException);

      final missingSnapshotId = Map<String, dynamic>.from(validPayload)
        ..remove('snapshotId');
      expect(() => codec.decode(missingSnapshotId), throwsFormatException);

      final missingFactualSummary = Map<String, dynamic>.from(validPayload)
        ..remove('factualSummary');
      expect(() => codec.decode(missingFactualSummary), throwsFormatException);
    });

    test('validateAgainst throws on snapshot ID mismatch', () {
      final report = codec.decode(validPayload);
      final mismatchedSnapshot = TextSnapshot(
        id: 'snap-other-id',
        text: snapshotText,
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      expect(
        () => report.validateAgainst(mismatchedSnapshot),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validateAgainst throws on text offset/excerpt mismatch', () {
      final invalidOffsetPayload = Map<String, dynamic>.from(validPayload)
        ..['findings'] = [
          {
            'id': 'ai-finding-1',
            'category': 'urgency',
            'explanation': 'Demands immediate money transfer.',
            'origin': 'remoteAi',
            'producerId': 'groq-qwen3.8-27b',
            'evidence': [
              {'startOffset': 0, 'endOffset': 10, 'exactExcerpt': 'WrongText!'},
            ],
          },
        ];

      final report = codec.decode(invalidOffsetPayload);
      expect(
        () => report.validateAgainst(snapshot),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('decodeJsonString parses valid JSON string or returns failure', () {
      final validJsonStr =
          '{"reportId":"rep-1","snapshotId":"snap-001","provider":"groq","model":"qwen","analyzedAt":"2026-10-15T12:00:00Z","factualSummary":"Summary text.","findings":[],"uncertaintyNotes":[],"suggestedActions":[]}';
      final result = codec.decodeJsonString(validJsonStr);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.reportId, equals('rep-1'));

      final invalidJsonStr = '{not valid json}';
      final failResult = codec.decodeJsonString(invalidJsonStr);
      expect(failResult.isFailure, isTrue);
    });
  });
}
