import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_execution_context.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_service.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/rule_registry.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Testable service pipeline composing rule evaluation and assessment synthesis.
///
/// Flow:
///   reviewed snapshot -> local rule engine -> assessment synthesizer -> LocalAssessment
///
/// Principles:
/// - Pure service orchestration using dependency injection and typed [Result]s.
/// - Never called automatically from app startup, OCR completion, incoming shares, or text review.
/// - Propagates engine overflow, rule failure, or unsupported input directly as typed failures;
///   never converts a failed analysis into a reassuring no-match assessment.
/// - Verifies snapshot ID consistency between [reviewResult] and [snapshot].
class LocalAnalysisPipeline {
  final AnalysisService engine;
  final AssessmentSynthesizer synthesizer;
  final RuleRegistry registry;

  LocalAnalysisPipeline({
    required this.engine,
    required this.synthesizer,
    required this.registry,
  });

  /// Executes full local analysis pipeline against a [TextSnapshot].
  Future<Result<LocalAssessment>> process(
    TextSnapshot snapshot, {
    ReviewedTextResult? reviewResult,
    List<String>? skippedRuleIds,
  }) async {
    // 1. Verify snapshot identity consistency if review metadata is provided
    if (reviewResult != null && reviewResult.snapshot.id != snapshot.id) {
      return Result.failure(
        AnalysisFailure.malformedData(
          'Provided reviewResult snapshot ID ("${reviewResult.snapshot.id}") does not match target snapshot ID ("${snapshot.id}").',
          'snapshot_id_mismatch',
        ),
      );
    }

    // 2. Evaluate snapshot using local rule engine
    final engineResult = await engine.analyze(snapshot);
    if (engineResult.isFailure) {
      // Propagate typed failure directly without masking as a completed assessment
      return Result.failure(engineResult.failureOrNull!);
    }

    final report = engineResult.valueOrNull!;

    // 3. Build execution context from registry and runtime parameters
    final executionContext = AnalysisExecutionContext.fromRegistry(
      registry,
      reviewResult: reviewResult,
      skippedRuleIds: skippedRuleIds,
    );

    // 4. Synthesize assessment
    return synthesizer.synthesize(
      report: report,
      executionContext: executionContext,
    );
  }
}
