import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/feedback/data/repositories/sqlite_feedback_repository.dart';
import 'package:trustcue_mobile/features/feedback/domain/contracts/feedback_repository.dart';
import 'package:trustcue_mobile/features/feedback/domain/models/app_feedback.dart';

/// Presentation controller managing anonymous feedback dialog interactions.
class FeedbackController extends GetxController {
  final FeedbackRepository _repository;
  final String Function()? idGenerator;

  FeedbackController({FeedbackRepository? repository, this.idGenerator})
    : _repository = repository ?? SqliteFeedbackRepository();

  final Rxn<FeedbackRating> selectedRating = Rxn<FeedbackRating>();
  final Rxn<FeedbackReasonChip> selectedReasonChip = Rxn<FeedbackReasonChip>();
  final TextEditingController commentController = TextEditingController();
  final RxBool isSaving = false.obs;
  final RxBool isSaved = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onClose() {
    commentController.dispose();
    super.onClose();
  }

  void selectRating(FeedbackRating rating) {
    selectedRating.value = rating;
    selectedReasonChip.value = null; // Reset chip when rating changes
    errorMessage.value = null;
  }

  void selectReasonChip(FeedbackReasonChip chip) {
    if (selectedReasonChip.value == chip) {
      selectedReasonChip.value = null;
    } else {
      selectedReasonChip.value = chip;
    }
  }

  /// Submits the feedback to local SQLite storage.
  Future<bool> submitFeedback({
    required FeedbackTargetType targetType,
    required String targetId,
  }) async {
    if (selectedRating.value == null) {
      errorMessage.value = 'Please select a rating.';
      return false;
    }

    final comment = commentController.text.trim();
    if (comment.length > 200) {
      errorMessage.value = 'Comment cannot exceed 200 characters.';
      return false;
    }

    isSaving.value = true;
    errorMessage.value = null;

    try {
      final gen = idGenerator;
      final id = gen != null
          ? gen()
          : 'fb_${DateTime.now().toUtc().microsecondsSinceEpoch}';

      final feedback = AppFeedback(
        id: id,
        targetType: targetType,
        targetId: targetId,
        rating: selectedRating.value!,
        reasonChip: selectedReasonChip.value,
        comment: comment.isEmpty ? null : comment,
        createdAt: DateTime.now().toUtc(),
      );

      await _repository.saveFeedback(feedback);
      isSaved.value = true;
      return true;
    } catch (e) {
      errorMessage.value = 'Failed to save feedback locally: $e';
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
