import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/analysis/data/services/analysis_api_client.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/upload_consent.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/analysis/presentation/widgets/analyzed_text_evidence_viewer.dart';
import 'package:trustcue_mobile/features/analysis/presentation/widgets/upload_consent_dialog.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/reports/data/database/app_database.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

/// Explicit states for local on-device report persistence.
enum ReportSaveStatus {
  /// Report has not been saved on this device yet.
  notSaved,

  /// Currently executing transactional write to local database.
  saving,

  /// Successfully persisted to local device storage.
  saved,

  /// Save operation encountered a database or validation failure.
  failed,
}

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

/// Explicit lifecycle states for optional server-assisted AI analysis execution.
enum AiAnalysisState {
  /// AI analysis has not been requested for this snapshot.
  idle,

  /// Actively transmitting snapshot and waiting for protected backend response.
  submitting,

  /// Server-assisted AI analysis successfully completed and validated.
  completed,

  /// AI analysis request failed or was declined. Local assessment is preserved.
  failed,
}

/// Presentation controller managing on-device analysis execution, lifecycle states,
/// optional cloud AI execution with explicit upload consent, evidence navigation,
/// and safe-return flows.
///
/// Principles:
/// - In-memory argument passing only: holds [AnalysisResultsArgs] for screen lifetime.
/// - Memory ownership: releases [assessment], [aiReport], and references upon controller disposal.
/// - Stale-result protection: operation identity ensures late completions from popped
///   routes or replaced operations are safely ignored.
/// - Never treats engine failure, overflow, or invalid input as a reassuring no-match.
/// - On-device execution is the primary baseline; cloud AI is strictly optional and secondary.
/// - Cloud AI failure leaves local assessment fully visible and intact.
class AnalysisResultsController extends GetxController {
  final LocalAnalysisPipeline pipeline;
  final AnalysisResultsArgs? args;
  final AnalysisApiClient? apiClient;
  final AuthRepository? authRepository;
  final LocalReportRepository? reportRepository;

  AnalysisResultsController({
    required this.pipeline,
    AnalysisResultsArgs? args,
    this.apiClient,
    this.authRepository,
    this.reportRepository,
  }) : args = args ?? _getRouteArguments();

  final Rx<AnalysisState> state = AnalysisState.initial.obs;
  final Rxn<LocalAssessment> assessment = Rxn<LocalAssessment>();
  final Rxn<String> errorMessage = Rxn<String>();
  final RxBool showLimitationsDetails = false.obs;
  final RxBool isNavigatingAway = false.obs;

  // Cloud AI state
  final Rx<AiAnalysisState> aiState = AiAnalysisState.idle.obs;
  final Rxn<AiAnalysisReport> aiReport = Rxn<AiAnalysisReport>();
  final Rxn<String> aiErrorMessage = Rxn<String>();
  final Rxn<String> aiRetryAfter = Rxn<String>();
  final Rxn<UploadConsent> currentConsent = Rxn<UploadConsent>();
  final RxBool isRequestingAi = false.obs;

  // Local persistence state
  final Rx<ReportSaveStatus> saveStatus = ReportSaveStatus.notSaved.obs;
  final RxBool isSaving = false.obs;
  final RxnString saveErrorMessage = RxnString();

  int _operationId = 0;
  int _aiOperationId = 0;

  @override
  void onInit() {
    super.onInit();
    startAnalysis();
  }

  @override
  void onClose() {
    // Invalidate any in-flight operations
    _operationId++;
    _aiOperationId++;
    assessment.value = null;
    aiReport.value = null;
    currentConsent.value = null;
    super.onClose();
  }

  /// Initiates on-device analysis against the reviewed snapshot.
  Future<void> startAnalysis() async {
    final currentArgs = args;
    if (currentArgs == null || !currentArgs.isValid) {
      state.value = AnalysisState.failedOrUnsupported;
      errorMessage.value = 'Review input is missing or invalid. Return to review and confirm your text.';
      return;
    }

    // Reset previous AI and persistence state upon fresh analysis start
    invalidateConsent();
    saveStatus.value = ReportSaveStatus.notSaved;
    saveErrorMessage.value = null;

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

  /// Initiates optional cloud AI analysis after ensuring authentication and explicit consent.
  Future<void> requestAiAnalysis(BuildContext context) async {
    final currentArgs = args;
    if (currentArgs == null || !currentArgs.isValid) return;
    if (isRequestingAi.value || aiState.value == AiAnalysisState.submitting) {
      return;
    }

    final auth =
        authRepository ??
        (Get.isRegistered<AuthRepository>()
            ? Get.find<AuthRepository>()
            : null);
    final isAuthenticated =
        auth != null && auth.currentStatus == AuthStatus.authenticated;

    if (!isAuthenticated) {
      aiState.value = AiAnalysisState.failed;
      aiErrorMessage.value = 'Cloud AI analysis requires an authenticated account. Local analysis remains fully functional.';
      return;
    }

    final accountId = auth.currentUser?.id;
    var consent = currentConsent.value;
    if (consent == null ||
        !consent.isValidFor(
          currentArgs.snapshot,
          candidateAccountId: accountId,
        )) {
      final granted = await UploadConsentDialog.show(
        context,
        snapshot: currentArgs.snapshot,
        accountId: accountId,
      );
      if (granted == null || !granted.granted) {
        return; // User cancelled or declined
      }
      currentConsent.value = granted;
      consent = granted;
    }

    final operationId = ++_aiOperationId;
    isRequestingAi.value = true;
    aiState.value = AiAnalysisState.submitting;
    aiErrorMessage.value = null;
    aiRetryAfter.value = null;

    try {
      final client =
          apiClient ??
          (Get.isRegistered<AnalysisApiClient>()
              ? Get.find<AnalysisApiClient>()
              : AnalysisApiClient(
                  tokenProvider: () async => auth.getAccessToken(),
                ));

      final result = await client.analyzeWithAi(
        snapshot: currentArgs.snapshot,
        consent: consent,
        sourceRevision: currentArgs.reviewResult.sourceRevision,
        currentAccountId: accountId,
      );

      if (isClosed || _aiOperationId != operationId) return;

      if (result.isSuccess) {
        aiReport.value = result.valueOrNull;
        aiState.value = AiAnalysisState.completed;
      } else {
        final failure = result.failureOrNull!;
        aiState.value = AiAnalysisState.failed;
        aiErrorMessage.value = failure.message;
        aiRetryAfter.value = failure.retryAfterSeconds;
      }
    } finally {
      if (!isClosed && _aiOperationId == operationId) {
        isRequestingAi.value = false;
      }
    }
  }

  /// Retries AI analysis for the current snapshot.
  void retryAiAnalysis(BuildContext context) {
    if (isRequestingAi.value) return;
    requestAiAnalysis(context);
  }

  /// Explicitly invalidates any cached upload consent and AI report.
  void invalidateConsent() {
    currentConsent.value = null;
    aiReport.value = null;
    aiState.value = AiAnalysisState.idle;
    aiErrorMessage.value = null;
    aiRetryAfter.value = null;
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

  /// Persists the current analysis findings and reviewed snapshot to local device storage.
  ///
  /// Guarantees:
  /// - Explicit user initiation only; never runs automatically.
  /// - Atomic transactional write to app-private SQLite database.
  /// - Repeated calls are safe and idempotent.
  /// - Failure leaves current analysis results 100% visible on screen.
  Future<void> saveReportOnDevice() async {
    final currentArgs = args;
    if (currentArgs == null || !currentArgs.isValid) return;
    if (isSaving.value || saveStatus.value == ReportSaveStatus.saving) return;

    final currentAssessment = assessment.value;
    if (currentAssessment == null) return;

    final repo =
        reportRepository ??
        (Get.isRegistered<LocalReportRepository>()
            ? Get.find<LocalReportRepository>()
            : AppDatabase.getInstance());

    isSaving.value = true;
    saveStatus.value = ReportSaveStatus.saving;
    saveErrorMessage.value = null;

    try {
      final auth =
          authRepository ??
          (Get.isRegistered<AuthRepository>()
              ? Get.find<AuthRepository>()
              : null);
      final accountId = auth?.currentStatus == AuthStatus.authenticated
          ? auth?.currentUser?.id
          : null;

      final now = DateTime.now().toUtc();
      final localFindings = currentAssessment.groupedIndicators
          .expand((group) => group.findings)
          .toList();
      final limitations = [
        currentAssessment.coverageInfo.coverageDescription,
        ...currentAssessment.uncertaintyNotes,
      ];
      final suggestedActions = currentAssessment.actionableSteps
          .map((action) => action.title)
          .toList();

      final localReport = AnalysisReport(
        id: currentAssessment.reportId,
        snapshot: currentArgs.snapshot,
        analyzedAt: currentAssessment.createdAt,
        findings: localFindings,
        limitations: limitations,
        suggestedActions: suggestedActions,
      );

      final savedReport = SavedReport(
        id: currentAssessment.reportId,
        snapshot: currentArgs.snapshot,
        accountId: accountId,
        analyzedAt: currentAssessment.createdAt,
        savedAt: now,
        localReport: localReport,
        aiReport: aiReport.value,
      );

      final saveResult = await repo.saveReport(savedReport);
      if (saveResult.isSuccess) {
        saveStatus.value = ReportSaveStatus.saved;
      } else {
        saveStatus.value = ReportSaveStatus.failed;
        saveErrorMessage.value = saveResult.failureOrNull?.message;
      }
    } catch (e) {
      saveStatus.value = ReportSaveStatus.failed;
      saveErrorMessage.value = 'Failed to save report: ${e.toString()}';
    } finally {
      isSaving.value = false;
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
