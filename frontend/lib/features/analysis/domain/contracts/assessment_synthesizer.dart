import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';

import 'analysis_execution_context.dart';

/// Contract for deterministic on-device assessment synthesis.
///
/// Principles:
/// - Transforms a completed [AnalysisReport] and [AnalysisExecutionContext] into an immutable [LocalAssessment].
/// - Pure-Dart execution without platform, widget, or network dependencies.
/// - Deterministic output: equivalent inputs MUST produce identical assessments.
/// - Never computes fraud probabilities, risk scores, or safe verdicts.
abstract class AssessmentSynthesizer {
  Result<LocalAssessment> synthesize({
    required AnalysisReport report,
    required AnalysisExecutionContext executionContext,
  });
}
