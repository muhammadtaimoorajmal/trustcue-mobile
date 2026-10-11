import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/data/serialization/analysis_report_codec.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import '../../fakes/fake_analysis_service.dart';

void main() {
  group('AnalysisReportCodec Serialization Tests', () {
    const codec = AnalysisReportCodec();

    final testSnapshot = TextSnapshot(
      id: 'snap-codec-01',
      source: InputSource.messageText,
      text: 'Warning: Suspicious payment request at https://pay.example.com',
      createdAt: DateTime.utc(2026, 10, 11, 14, 0),
    );

    final finding1 = AnalysisFinding(
      id: 'f-codec-01',
      category: 'payment_threat',
      explanation: 'Unusual urgency and payment destination detected.',
      origin: FindingOrigin.localRule,
      producerId: 'rule.payment.v1',
      evidence: [
        EvidenceReference(
          snapshotId: 'snap-codec-01',
          startOffset: 0,
          endOffset: 8,
          exactExcerpt: 'Warning:',
        ),
      ],
    );

    final report = AnalysisReport(
      id: 'rep-codec-01',
      schemaVersion: 1,
      snapshot: testSnapshot,
      analyzedAt: DateTime.utc(2026, 10, 11, 14, 1),
      findings: [finding1],
      limitations: [
        'Heuristic analysis cannot verify off-platform payment gateways.',
      ],
      suggestedActions: [
        'Do not submit payments through links received in unverified messages.',
      ],
    );

    test('Encodes and decodes valid report with exact round-trip fidelity', () {
      final encodedMap = codec.encode(report);
      expect(encodedMap['id'], 'rep-codec-01');
      expect(encodedMap['schemaVersion'], 1);
      expect(encodedMap['analyzedAt'], '2026-10-11T14:01:00.000Z');
      expect(encodedMap['findings'], isA<List>());
      expect(encodedMap['limitations'], isA<List>());
      expect(encodedMap['suggestedActions'], isA<List>());

      final decodedReport = codec.decode(encodedMap);
      expect(decodedReport, equals(report));
    });

    test('encodeJsonString and decodeJsonString round-trip successfully', () {
      final jsonString = codec.encodeJsonString(report);
      expect(jsonString, isA<String>());
      expect(jsonString, contains('"rep-codec-01"'));

      final result = codec.decodeJsonString(jsonString);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, equals(report));
    });

    test('Rejects missing or wrong-typed required fields', () {
      final encoded = codec.encode(report);

      final missingId = Map<String, dynamic>.from(encoded)..remove('id');
      expect(() => codec.decode(missingId), throwsFormatException);

      final wrongVersionType = Map<String, dynamic>.from(encoded)
        ..['schemaVersion'] = '1'; // String instead of int
      expect(() => codec.decode(wrongVersionType), throwsFormatException);

      final unsupportedVersion = Map<String, dynamic>.from(encoded)
        ..['schemaVersion'] = 2; // Version 2 not yet supported
      expect(() => codec.decode(unsupportedVersion), throwsFormatException);

      final missingSnapshot = Map<String, dynamic>.from(encoded)
        ..remove('snapshot');
      expect(() => codec.decode(missingSnapshot), throwsFormatException);

      final missingFindings = Map<String, dynamic>.from(encoded)
        ..remove('findings');
      expect(() => codec.decode(missingFindings), throwsFormatException);
    });

    test('Rejects coerced integers in evidence offsets', () {
      final badEvidenceMap = {
        'snapshotId': 'snap-codec-01',
        'startOffset': '0', // String coercion prohibited
        'endOffset': 8,
        'exactExcerpt': 'Warning:',
      };

      final badReportMap = codec.encode(report);
      badReportMap['findings'] = [
        {
          'id': 'f-bad',
          'category': 'cat',
          'explanation': 'exp',
          'origin': 'localRule',
          'producerId': 'p1',
          'evidence': [badEvidenceMap],
        },
      ];

      expect(() => codec.decode(badReportMap), throwsFormatException);
    });

    test('Rejects timestamps without explicit timezone', () {
      final badReportMap = codec.encode(report)
        ..['analyzedAt'] = '2026-10-11T14:01:00'; // Missing Z or offset

      expect(() => codec.decode(badReportMap), throwsFormatException);
    });

    test('Ignores unknown additional fields in version 1', () {
      final mapWithExtras = codec.encode(report)
        ..['futureDiagnosticField'] = 'alpha-build-debug'
        ..['extraMetadata'] = {'someFlag': 123};

      final decoded = codec.decode(mapWithExtras);
      expect(decoded.id, report.id);
      expect(decoded.findings.length, 1);
    });

    test('decodeJsonString traps malformed JSON and returns typed Failure', () {
      const invalidJson = '{ not-valid-json ]';
      final result = codec.decodeJsonString(invalidJson);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, AnalysisFailureCode.malformedData);
      expect(result.failureOrNull?.message, contains('Malformed report data'));
    });

    test(
      'decodeJsonString traps non-object JSON root and returns typed Failure',
      () {
        const arrayJson = '["not", "an", "object"]';
        final result = codec.decodeJsonString(arrayJson);

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.code, AnalysisFailureCode.malformedData);
      },
    );

    test(
      'FakeAnalysisService adheres to async AnalysisService contract',
      () async {
        final service = FakeAnalysisService();

        // Successful analysis of snapshot
        final result = await service.analyze(testSnapshot);
        expect(result.isSuccess, isTrue);
        expect(service.callCount, 1);
        expect(service.lastAnalyzedSnapshot, testSnapshot);
        expect(result.valueOrNull?.snapshot, testSnapshot);

        // Configured failure result
        final failureService = FakeAnalysisService(
          nextResult: const Result.failure(
            AnalysisFailure.unavailable('Remote service offline'),
          ),
        );

        final failedResult = await failureService.analyze(testSnapshot);
        expect(failedResult.isFailure, isTrue);
        expect(
          failedResult.failureOrNull?.code,
          AnalysisFailureCode.unavailable,
        );
      },
    );
  });
}
