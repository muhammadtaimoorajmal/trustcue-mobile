import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/review_input.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_candidate.dart';
import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_type.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/domain/services/local_sensitive_data_detector.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';

/// Presentation controller managing message and OCR text correction, local sensitive
/// data detection, user redaction choices, and final snapshot confirmation.
class InputReviewController extends GetxController {
  InputReviewController({
    ReviewInput? reviewInput,
    LocalSensitiveDataDetector? detector,
    String Function()? idGenerator,
    DateTime Function()? clock,
    TextEditingController? textEditingController,
    FocusNode? focusNode,
  }) : reviewInput = reviewInput ?? _getRouteArguments(),
       detector = detector ?? const LocalSensitiveDataDetector(),
       _idGenerator = idGenerator ?? _defaultIdGenerator,
       _clock = clock ?? DateTime.now,
       textEditingController = textEditingController ?? TextEditingController(),
       focusNode = focusNode ?? FocusNode();

  final ReviewInput? reviewInput;
  final LocalSensitiveDataDetector detector;
  final String Function() _idGenerator;
  final DateTime Function() _clock;

  final TextEditingController textEditingController;
  final FocusNode focusNode;

  late final bool hasValidInput;
  late final String initialText;

  final RxInt reviewRevision = 1.obs;
  final RxInt codePointCount = 0.obs;
  final Rxn<MessageTextValidationError> validationError =
      Rxn<MessageTextValidationError>();

  final RxList<SensitiveDataCandidate> candidates =
      <SensitiveDataCandidate>[].obs;
  final RxSet<String> selectedCandidateIds = <String>{}.obs;
  final RxBool hasDetected = false.obs;
  final RxString previewText = ''.obs;

  final RxBool isConfirmed = false.obs;
  final Rxn<ReviewedTextResult> confirmedResult = Rxn<ReviewedTextResult>();

  final RxBool showComparisonImage = false.obs;
  final RxBool isNavigatingAway = false.obs;
  final RxBool isNavigatingToAnalysis = false.obs;

  bool get isScreenshotSource =>
      reviewInput?.snapshot.source == InputSource.screenshot;

  bool get isComparisonImageAvailable {
    final path = reviewInput?.imagePath;
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    final input = reviewInput;
    if (input == null) {
      hasValidInput = false;
      initialText = '';
      return;
    }

    hasValidInput = true;
    final normalized = MessageTextValidator.normalizeLineEndings(
      input.snapshot.text,
    );
    initialText = normalized;
    textEditingController.text = normalized;
    previewText.value = normalized;
    codePointCount.value = MessageTextValidator.countCodePoints(normalized);

    checkSensitiveDetails();

    textEditingController.addListener(_handleTextChanged);
  }

  @override
  void onClose() {
    textEditingController.removeListener(_handleTextChanged);
    textEditingController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  void _handleTextChanged() {
    final currentText = textEditingController.text;
    codePointCount.value = MessageTextValidator.countCodePoints(currentText);

    // Any text edit invalidates previously detected suggestions, selections,
    // preview, and confirmation.
    reviewRevision.value++;
    candidates.clear();
    selectedCandidateIds.clear();
    hasDetected.value = false;
    isConfirmed.value = false;
    confirmedResult.value = null;
    previewText.value = currentText;

    final result = MessageTextValidator.validate(currentText);
    if (result.isInvalid) {
      validationError.value = result.error;
    } else {
      validationError.value = null;
    }
  }

  /// Runs the local heuristic detector against current review text.
  void checkSensitiveDetails() {
    if (!hasValidInput) return;
    final currentText = textEditingController.text;
    final validation = MessageTextValidator.validate(currentText);
    if (validation.isInvalid) {
      validationError.value = validation.error;
      return;
    }

    final detected = detector.detect(
      text: currentText,
      revision: 'rev-${reviewRevision.value}',
    );

    candidates.assignAll(detected);
    selectedCandidateIds.clear();
    hasDetected.value = true;
    isConfirmed.value = false;
    confirmedResult.value = null;
    previewText.value = currentText;
  }

  /// Toggles candidate selection and recalculates preview text.
  void toggleCandidate(String candidateId) {
    if (selectedCandidateIds.contains(candidateId)) {
      selectedCandidateIds.remove(candidateId);
    } else {
      selectedCandidateIds.add(candidateId);
    }

    // Changing selections invalidates confirmation
    isConfirmed.value = false;
    confirmedResult.value = null;

    _recomputePreview();
  }

  /// Selects all available suggestions.
  void selectAllCandidates() {
    selectedCandidateIds.addAll(candidates.map((c) => c.id));
    isConfirmed.value = false;
    confirmedResult.value = null;
    _recomputePreview();
  }

  /// Clears all suggestion selections.
  void clearCandidateSelections() {
    selectedCandidateIds.clear();
    isConfirmed.value = false;
    confirmedResult.value = null;
    _recomputePreview();
  }

  void _recomputePreview() {
    final currentText = textEditingController.text;
    previewText.value = detector.applyRedactions(
      text: currentText,
      selectedCandidateIds: selectedCandidateIds,
      candidates: candidates,
    );
  }

  /// Confirms reviewed and redacted text into an immutable in-memory [TextSnapshot].
  void confirmReviewedText() {
    if (!hasValidInput) return;

    final currentText = textEditingController.text;
    final textValidation = MessageTextValidator.validate(currentText);
    if (textValidation.isInvalid) {
      validationError.value = textValidation.error;
      return;
    }

    final finalRedactedText = previewText.value;
    final finalValidation = MessageTextValidator.validate(finalRedactedText);
    if (finalValidation.isInvalid) {
      validationError.value = finalValidation.error;
      return;
    }

    final nowUtc = _clock().toUtc();
    final newSnapshot = TextSnapshot(
      id: _idGenerator(),
      text: finalRedactedText,
      source: reviewInput!.snapshot.source, // Preserves original source!
      createdAt: nowUtc,
    );

    // Compute minimal category counts
    final counts = <SensitiveDataType, int>{};
    for (final candidate in candidates) {
      if (selectedCandidateIds.contains(candidate.id)) {
        counts[candidate.type] = (counts[candidate.type] ?? 0) + 1;
      }
    }

    final result = ReviewedTextResult(
      snapshot: newSnapshot,
      sourceSnapshotId: reviewInput!.snapshot.id,
      sourceRevision: reviewInput!.sourceRevision,
      reviewedAt: nowUtc,
      redactionCounts: counts,
    );

    confirmedResult.value = result;
    isConfirmed.value = true;
    validationError.value = null;
  }

  /// Navigates to `/analysis/results` passing the confirmed [ReviewedTextResult] in-memory.
  Future<void> analyzeOnThisDevice() async {
    if (!isConfirmed.value || confirmedResult.value == null) return;
    if (isNavigatingToAnalysis.value) return;

    isNavigatingToAnalysis.value = true;
    try {
      final reviewed = confirmedResult.value!;
      await Get.toNamed(
        AppRoutes.analysisResults,
        arguments: AnalysisResultsArgs(reviewResult: reviewed),
      );
    } finally {
      isNavigatingToAnalysis.value = false;
    }
  }

  /// Navigates to `/safe-use` with duplicate route protection, preserving draft state.
  Future<void> openSafeUseGuidance() async {
    if (isNavigatingAway.value) return;
    isNavigatingAway.value = true;
    try {
      await Get.toNamed(AppRoutes.guidance);
    } finally {
      isNavigatingAway.value = false;
    }
  }

  /// Toggles visibility of the screenshot comparison preview.
  void toggleComparisonImage() {
    showComparisonImage.value = !showComparisonImage.value;
  }

  /// Evaluates back navigation, returning the confirmed result or prompting for discard.
  Future<bool> handleBackNavigation() async {
    if (!hasValidInput) {
      return true;
    }

    // If confirmed, exit without discard dialog and return the confirmed result
    if (isConfirmed.value && confirmedResult.value != null) {
      Get.back(result: confirmedResult.value);
      return false; // already popped with result
    }

    // If no changes have been made, allow popping cleanly
    final hasEdits = textEditingController.text != initialText;
    final hasSelections = selectedCandidateIds.isNotEmpty;
    if (!hasEdits && !hasSelections) {
      return true;
    }

    // Prompt user to discard unconfirmed changes
    final discardConfirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unconfirmed changes or redaction selections. Leaving now will discard your review work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Keep reviewing'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'Discard',
              style: TextStyle(color: Get.theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );

    return discardConfirmed ?? false;
  }

  static ReviewInput? _getRouteArguments() {
    final args = Get.arguments;
    if (args is ReviewInput) {
      return args;
    }
    return null;
  }

  static String _defaultIdGenerator() {
    final rand = math.Random();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomSuffix = rand
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    return 'rev-snap-$timestamp-$randomSuffix';
  }
}
