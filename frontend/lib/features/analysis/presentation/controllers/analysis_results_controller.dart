import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/analysis/presentation/widgets/analyzed_text_evidence_viewer.dart';

/// Explicit lifecycle states for on-device analysis execution.
enum AnalysisState {
  /// Ready to start or awaiting arguments.
  initial,

  /// Actively evaluating local heuristic rules against the immutable reviewed snapshot.
  running,

  /// Evaluation completed and identified one or more potential warning indicators.
  completedWithIndicators,

  /// Evaluation completed with no matching indicators. Not a guarantee of safety.
  completedWithNoMatches,

  /// Evaluation completed with constrained rule coverage or empty catalog.
  limitedCoverage,

  /// Engine failed, input was unsupported, or arguments were missing/invalid.
  failedOrUnsupported,
}

/// Presentation controller managing on-device analysis execution, lifecycle states,
/// evidence navigation, and safe-return flows.
///
/// Principles:
/// - In-memory argument passing only: holds [AnalysisResultsArgs] for screen lifetime.
/// - Memory ownership: releases [assessment] and references upon controller disposal.
/// - Stale-result protection: operation identity ensures late completions from popped
///   routes or replaced operations are safely ignored.
/// - Never treats engine failure, overflow, or invalid input as a reassuring no-match.
/// - Pure on-device execution; nothing is uploaded or persisted.
class AnalysisResultsController extends GetxController {
  final LocalAnalysisPipeline pipeline;
  final AnalysisResultsArgs? args;

  AnalysisResultsController({required this.pipeline, AnalysisResultsArgs? args})
    : args = args ?? _getRouteArguments();

  final Rx<AnalysisState> state = AnalysisState.initial.obs;
  final Rxn<LocalAssessment> assessment = Rxn<LocalAssessment>();
  final Rxn<String> errorMessage = Rxn<String>();
  final RxBool showLimitationsDetails = false.obs;
  final RxBool isNavigatingAway = false.obs;

  int _operationId = 0;

  @override
  void onInit() {
    super.onInit();
    startAnalysis();
  }

  @override
  void onClose() {
    // Invalidate any in-flight operations
    _operationId++;
    assessment.value = null;
    super.onClose();
  }

  /// Initiates analysis against the reviewed snapshot.
  Future<void> startAnalysis() async {
    final currentArgs = args;
    if (currentArgs == null || !currentArgs.isValid) {
      state.value = AnalysisState.failedOrUnsupported;
      errorMessage.value = 'Review input is missing or invalid. Return to review and confirm your text.';
      return;
    }

    final operationId = ++_operationId;
    state.value = AnalysisState.running;
    errorMessage.value = null;

    final result = await pipeline.process(
      currentArgs.snapshot,
      reviewResult: currentArgs.reviewResult,
    );

    // Stale-result protection: if controller was closed or a newer operation was launched, ignore
    if (isClosed || _operationId != operationId) {
      return;
    }

    if (result.isFailure) {
      state.value = AnalysisState.failedOrUnsupported;
      errorMessage.value =
          result.failureOrNull?.message ?? 'Analysis could not be completed.';
      return;
    }

    final localAssessment = result.valueOrNull!;
    assessment.value = localAssessment;

    switch (localAssessment.outcomeState) {
      case AssessmentOutcomeState.indicatorsDetected:
        state.value = AnalysisState.completedWithIndicators;
        break;
      case AssessmentOutcomeState.noIndicatorsMatched:
        state.value = AnalysisState.completedWithNoMatches;
        break;
      case AssessmentOutcomeState.limitedCoverage:
        state.value = AnalysisState.limitedCoverage;
        break;
    }
  }

  /// Deliberate user retry for a failed operation using the still-valid snapshot.
  void retryAnalysis() {
    if (state.value == AnalysisState.running) return;
    startAnalysis();
  }

  /// Toggles visibility of expanded limitations and uncertainty details.
  void toggleLimitationsDetails() {
    showLimitationsDetails.value = !showLimitationsDetails.value;
  }

  /// Opens the interactive evidence viewer displaying the exact analyzed text and highlights.
  void viewEvidenceInText(AnalysisFinding finding, BuildContext context) {
    final currentArgs = args;
    if (currentArgs == null) return;
    AnalyzedTextEvidenceViewer.show(
      context,
      analyzedText: currentArgs.snapshot.text,
      finding: finding,
    );
  }

  /// Navigates to safe-use guidance.
  Future<void> openSafeUseGuidance() async {
    if (isNavigatingAway.value) return;
    isNavigatingAway.value = true;
    try {
      await Get.toNamed(AppRoutes.guidance);
    } finally {
      isNavigatingAway.value = false;
    }
  }

  /// Returns to the text review screen, preserving the review draft.
  void returnToReview() {
    Get.back();
  }

  static AnalysisResultsArgs? _getRouteArguments() {
    final raw = Get.arguments;
    if (raw is AnalysisResultsArgs) {
      return raw;
    }
    return null;
  }
}
