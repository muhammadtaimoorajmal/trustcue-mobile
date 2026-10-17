import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/feedback/domain/models/app_feedback.dart';
import 'package:trustcue_mobile/features/feedback/presentation/controllers/feedback_controller.dart';

/// Interactive dialog for collecting anonymous usefulness feedback stored locally.
class FeedbackDialog extends StatelessWidget {
  final FeedbackTargetType targetType;
  final String targetId;
  final String? targetTitle;

  const FeedbackDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required FeedbackTargetType targetType,
    required String targetId,
    String? targetTitle,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => FeedbackDialog(
        targetType: targetType,
        targetId: targetId,
        targetTitle: targetTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.isRegistered<FeedbackController>()
        ? Get.find<FeedbackController>()
        : Get.put(FeedbackController());

    return AlertDialog(
      title: Text(
        'feedback_dialog_title'.tr,
        style: theme.textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Obx(() {
          if (controller.isSaved.value) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'feedback_saved_msg'.tr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'feedback_local_notice'.tr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (targetTitle != null) ...[
                Text(
                  targetTitle!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Non-Reporting Authority Notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'feedback_disclaimer'.tr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.pagePaddingSmall),

              // Rating Selection
              Text(
                'How was this explanation?',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('feedback_rate_helpful'.tr),
                    avatar: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                    selected:
                        controller.selectedRating.value ==
                        FeedbackRating.helpful,
                    onSelected: (val) {
                      if (val) {
                        controller.selectRating(FeedbackRating.helpful);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: Text('feedback_rate_unhelpful'.tr),
                    avatar: const Icon(Icons.thumb_down_alt_outlined, size: 16),
                    selected:
                        controller.selectedRating.value ==
                        FeedbackRating.unhelpful,
                    onSelected: (val) {
                      if (val) {
                        controller.selectRating(FeedbackRating.unhelpful);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: Text('feedback_rate_neutral'.tr),
                    avatar: const Icon(Icons.sentiment_neutral, size: 16),
                    selected:
                        controller.selectedRating.value ==
                        FeedbackRating.neutral,
                    onSelected: (val) {
                      if (val) {
                        controller.selectRating(FeedbackRating.neutral);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.pagePaddingSmall),

              // Reason Chips (shown when rating is selected)
              if (controller.selectedRating.value != null) ...[
                Text(
                  'feedback_reasons_title'.tr,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _getChipsForRating(controller.selectedRating.value!)
                      .map((chip) {
                        final isSelected =
                            controller.selectedReasonChip.value == chip;
                        return FilterChip(
                          label: Text(_getChipLabel(chip)),
                          selected: isSelected,
                          onSelected: (_) => controller.selectReasonChip(chip),
                        );
                      })
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.pagePaddingSmall),
              ],

              // Optional Comment with strict boundary and counter
              AppTextField(
                controller: controller.commentController,
                label: 'feedback_comment_label'.tr,
                hint: 'Share feedback without personal details...',
                multiline: true,
                maxLength: 200,
                maxLines: 3,
              ),
              const SizedBox(height: 4),
              Text(
                'feedback_privacy_warning'.tr,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),

              if (controller.errorMessage.value != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage.value!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          );
        }),
      ),
      actions: [
        Obx(() {
          if (controller.isSaved.value) {
            return AppButton.primary(
              label: 'close'.tr,
              onPressed: () {
                Navigator.of(context).pop();
                Get.delete<FeedbackController>();
              },
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: controller.isSaving.value
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        Get.delete<FeedbackController>();
                      },
                child: Text('cancel'.tr),
              ),
              const SizedBox(width: 8),
              AppButton.primary(
                label: controller.isSaving.value ? 'Saving...' : 'save'.tr,
                onPressed: controller.isSaving.value
                    ? null
                    : () async {
                        await controller.submitFeedback(
                          targetType: targetType,
                          targetId: targetId,
                        );
                      },
              ),
            ],
          );
        }),
      ],
    );
  }

  List<FeedbackReasonChip> _getChipsForRating(FeedbackRating rating) {
    switch (rating) {
      case FeedbackRating.helpful:
        return const [
          FeedbackReasonChip.clearExplanation,
          FeedbackReasonChip.goodExample,
          FeedbackReasonChip.easyToVerify,
          FeedbackReasonChip.other,
        ];
      case FeedbackRating.unhelpful:
        return const [
          FeedbackReasonChip.confusingTerms,
          FeedbackReasonChip.tooTechnical,
          FeedbackReasonChip.exampleMismatch,
          FeedbackReasonChip.missingSteps,
          FeedbackReasonChip.other,
        ];
      case FeedbackRating.neutral:
        return const [
          FeedbackReasonChip.clearExplanation,
          FeedbackReasonChip.exampleMismatch,
          FeedbackReasonChip.other,
        ];
    }
  }

  String _getChipLabel(FeedbackReasonChip chip) {
    switch (chip) {
      case FeedbackReasonChip.clearExplanation:
        return 'feedback_chip_clear_explanation'.tr;
      case FeedbackReasonChip.goodExample:
        return 'feedback_chip_good_example'.tr;
      case FeedbackReasonChip.easyToVerify:
        return 'feedback_chip_easy_to_verify'.tr;
      case FeedbackReasonChip.confusingTerms:
        return 'feedback_chip_confusing_terms'.tr;
      case FeedbackReasonChip.tooTechnical:
        return 'feedback_chip_too_technical'.tr;
      case FeedbackReasonChip.exampleMismatch:
        return 'feedback_chip_example_mismatch'.tr;
      case FeedbackReasonChip.missingSteps:
        return 'feedback_chip_missing_steps'.tr;
      case FeedbackReasonChip.other:
        return 'feedback_chip_other'.tr;
    }
  }
}
