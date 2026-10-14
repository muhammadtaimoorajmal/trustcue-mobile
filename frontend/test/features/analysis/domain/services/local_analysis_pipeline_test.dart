import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_type.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  final fixedClock = DateTime.utc(2026, 10, 15, 15, 30);
  late LocalRuleEngine engine;
  late LocalAssessmentSynthesizer synthesizer;
  late LocalAnalysisPipeline pipeline;

  setUp(() {
    final registry = LocalRuleCatalog.createRegistry();
    engine = LocalRuleEngine(
      registry: registry,
      clock: () => fixedClock,
      idGenerator: () => 'test-id-1',
    );
    synthesizer = LocalAssessmentSynthesizer(clock: () => fixedClock);
    pipeline = LocalAnalysisPipeline(
      engine: engine,
      synthesizer: synthesizer,
      registry: registry,
    );
  });

  TextSnapshot createSnapshot({
    String id = 'snap-pipeline-1',
    InputSource source = InputSource.messageText,
    required String text,
  }) {
    return TextSnapshot(
      id: id,
      source: source,
      text: text,
      createdAt: fixedClock,
    );
  }

  group('LocalAnalysisPipeline End-to-End Analysis', () {
    test('end-to-end analysis of message with multiple indicators', () async {
      final snapshot = createSnapshot(
        text: 'Send your password right now to avoid account suspension: http://192.168.1.1/login. Respond immediately within 24 hours.',
      );

      final result = await pipeline.process(snapshot);

      expect(result.isSuccess, isTrue);
      final assessment = result.valueOrNull!;

      expect(
        assessment.outcomeState,
        AssessmentOutcomeState.indicatorsDetected,
      );
      expect(assessment.snapshotId, snapshot.id);
      expect(assessment.reportId, 'report-test-id-1');
      expect(assessment.synthesisPolicyVersion, '1.0.0');

      // Should identify urgency, credentials, account threat, and IP link
      expect(assessment.groupedIndicators.length, greaterThanOrEqualTo(3));
      final groupCategoryIds = assessment.groupedIndicators
          .map((g) => g.categoryId)
          .toSet();
      expect(groupCategoryIds, contains('urgency_or_pressure'));
      expect(groupCategoryIds, contains('requests_for_credentials'));
      expect(groupCategoryIds, contains('account_suspension_or_threats'));
      expect(groupCategoryIds, contains('link_structural_indicators'));

      // Verify every summarized indicator and action can be traced to actual findings
      final allFindingIds = <String>{};
      for (final group in assessment.groupedIndicators) {
        expect(group.findings, isNotEmpty);
        for (final finding in group.findings) {
          allFindingIds.add(finding.id);
        }
      }

      for (final action in assessment.actionableSteps) {
        for (final findingId in action.supportingFindingIds) {
          expect(
            allFindingIds.contains(findingId),
            isTrue,
            reason:
                'Action ${action.id} references untraced finding $findingId',
          );
        }
      }

      // Verify factual summary lists category names
      expect(assessment.factualSummary, contains('Urgency or pressure'));
      expect(assessment.factualSummary, contains('Requests for credentials'));

      // Verify coverage info
      expect(assessment.coverageInfo.executedRuleIds, hasLength(10));
      expect(assessment.coverageInfo.isCatalogEmpty, isFalse);
    });

    test('end-to-end analysis of clean message produces honest no-match assessment', () async {
      final snapshot = createSnapshot(
        text: 'Hi Sarah, are we still meeting for lunch at 12:30 PM tomorrow? Let me know.',
      );

      final result = await pipeline.process(snapshot);

      expect(result.isSuccess, isTrue);
      final assessment = result.valueOrNull!;

      expect(
        assessment.outcomeState,
        AssessmentOutcomeState.noIndicatorsMatched,
      );
      expect(
        assessment.factualSummary,
        'No indicators were matched by these local checks. This does not establish that the message is safe.',
      );
      expect(assessment.groupedIndicators, isEmpty);
      expect(assessment.actionableSteps, hasLength(1));
      expect(assessment.actionableSteps.first.id, 'action.general_caution');
    });

    test(
      'end-to-end analysis of screenshot input carries OCR uncertainty note',
      () async {
        final snapshot = createSnapshot(
          source: InputSource.screenshot,
          text: 'Congratulations! You won the grand lottery prize! Claim your reward now.',
        );

        final result = await pipeline.process(snapshot);

        expect(result.isSuccess, isTrue);
        final assessment = result.valueOrNull!;

        expect(assessment.snapshotSource, InputSource.screenshot);
        expect(
          assessment.uncertaintyNotes.any(
            (n) => n.contains(
              'optical character recognition (OCR) and may contain transcription errors',
            ),
          ),
          isTrue,
        );
      },
    );

    test('end-to-end analysis with trusted review metadata reflects redactions count', () async {
      final snapshot = createSnapshot(
        text: 'Claim your job offer now with guaranteed pay.',
      );
      final reviewResult = ReviewedTextResult(
        snapshot: snapshot,
        sourceSnapshotId: 'src-snap-1',
        sourceRevision: 'rev-1',
        reviewedAt: fixedClock,
        redactionCounts: {SensitiveDataType.phone: 1},
      );

      final result = await pipeline.process(
        snapshot,
        reviewResult: reviewResult,
      );

      expect(result.isSuccess, isTrue);
      final assessment = result.valueOrNull!;

      expect(
        assessment.uncertaintyNotes.any(
          (n) => n.contains('1 redaction(s) applied'),
        ),
        isTrue,
      );
    });
  });

  group('LocalAnalysisPipeline Failure & Overflow Propagation', () {
    test(
      'rejects snapshot ID mismatch between reviewResult and target snapshot',
      () async {
        final snapshot = createSnapshot(id: 'snap-actual', text: 'Hello world');
        final mismatchedSnapshot = createSnapshot(
          id: 'snap-other',
          text: 'Hello world',
        );
        final reviewResult = ReviewedTextResult(
          snapshot: mismatchedSnapshot,
          sourceSnapshotId: 'src-snap',
          sourceRevision: 'rev-1',
          reviewedAt: fixedClock,
        );

        final result = await pipeline.process(
          snapshot,
          reviewResult: reviewResult,
        );

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.code, AnalysisFailureCode.malformedData);
        expect(result.failureOrNull?.safeDetails, 'snapshot_id_mismatch');
      },
    );

    test('propagates engine input validation failures directly without creating reassuring assessment', () async {
      // 0-byte or invalid text according to MessageTextValidator
      final snapshot = createSnapshot(
        text: 'A' * 200000, // Exceeds MessageTextValidator byte limit
      );

      final result = await pipeline.process(snapshot);

      expect(result.isFailure, isTrue);
      // Must NOT return a reassuring no-match assessment
      expect(result.valueOrNull, isNull);
    });

    test('propagates engine overflow failure directly', () async {
      // Create pipeline with maxFindings = 0 to trigger overflow immediately on first finding
      final smallRegistry = LocalRuleCatalog.createRegistry();
      final smallEngine = LocalRuleEngine(
        registry: smallRegistry,
        maxFindings: 0,
        clock: () => fixedClock,
      );
      final testPipeline = LocalAnalysisPipeline(
        engine: smallEngine,
        synthesizer: synthesizer,
        registry: smallRegistry,
      );

      final snapshot = createSnapshot(
        text: 'Send your password immediately to avoid account suspension: http://192.168.1.1/login.',
      );

      final result = await testPipeline.process(snapshot);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, AnalysisFailureCode.unsupportedInput);
      expect(result.failureOrNull?.safeDetails, 'max_findings_exceeded');
      expect(result.valueOrNull, isNull);
    });
  });
}
