import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/guide/domain/models/guide_topic.dart';
import 'package:trustcue_mobile/features/guide/domain/models/practice_example.dart';
import 'package:trustcue_mobile/features/guide/domain/services/guide_catalog.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/review_input.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_review_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';

/// Presentation controller managing the offline User Guide and safe guided practice.
class UserGuideController extends GetxController {
  final RxSet<String> expandedTopics = <String>{}.obs;

  List<PracticeExample> get practiceExamples => GuideCatalog.practiceExamples;
  List<GuideTopic> get topics => GuideCatalog.getTopics();

  bool isTopicExpanded(String id) => expandedTopics.contains(id);

  void toggleTopic(String id) {
    if (expandedTopics.contains(id)) {
      expandedTopics.remove(id);
    } else {
      expandedTopics.add(id);
    }
  }

  /// Launches a synthetic practice demonstration into the real review pipeline.
  ///
  /// Invariants:
  /// - Prompts before replacing any active draft text in [InputTextController].
  /// - Real on-device pipeline is used without mock flags or faked results.
  /// - Zero network or AI calls are initiated.
  /// - Zero reports are automatically persisted.
  Future<void> launchPractice(
    PracticeExample example,
    BuildContext context,
  ) async {
    final bool hasExistingDraft =
        Get.isRegistered<InputTextController>() &&
        Get.find<InputTextController>().hasDraft &&
        Get.find<InputTextController>().text.value != example.syntheticText;

    if (hasExistingDraft) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('guide_draft_dialog_title'.tr),
          content: Text('guide_draft_dialog_body'.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('guide_draft_dialog_cancel'.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('guide_draft_dialog_replace'.tr),
            ),
          ],
        ),
      );

      if (shouldReplace != true) {
        return;
      }
    }

    if (Get.isRegistered<InputTextController>()) {
      Get.find<InputTextController>().populateSharedText(example.syntheticText);
    }

    final snapshot = TextSnapshot(
      id: 'practice_${DateTime.now().microsecondsSinceEpoch}',
      source: InputSource.messageText,
      text: example.syntheticText,
      createdAt: DateTime.now(),
    );

    final reviewInput = ReviewInput(
      snapshot: snapshot,
      sourceRevision: snapshot.id,
    );

    if (Get.isRegistered<InputReviewController>()) {
      Get.delete<InputReviewController>();
    }

    Get.toNamed(AppRoutes.inputReview, arguments: reviewInput);
  }
}
