import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_colors.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_candidate.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_review_controller.dart';

/// Screen allowing users to inspect, correct, and optionally redact sensitive details
/// from prepared message text or OCR extraction results.
class InputReviewScreen extends GetView<InputReviewController> {
  const InputReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canPop = await controller.handleBackNavigation();
        if (canPop) {
          Get.back();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review text'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () async {
              final canPop = await controller.handleBackNavigation();
              if (canPop) {
                Get.back();
              }
            },
          ),
        ),
        body: AppPageBody(
          child: Obx(() {
            if (!controller.hasValidInput) {
              return _buildMissingInputState(theme);
            }
            return _buildReviewContent(theme, brightness);
          }),
        ),
      ),
    );
  }

  Widget _buildMissingInputState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        AppCard(
          child: Column(
            children: [
              Icon(
                Icons.find_in_page_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              Text(
                'No text to review',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'There is no active message or OCR text ready for review. Prepare a message or select a screenshot first.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              AppButton.primary(
                label: 'Back to Home',
                onPressed: () => Get.offAllNamed(AppRoutes.home),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewContent(ThemeData theme, Brightness brightness) {
    final isSuccessDark = brightness == Brightness.dark;
    final successColor = isSuccessDark
        ? AppColors.successDark
        : AppColors.successLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Privacy & Local-Only Boundary Banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingSmall),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reviewing text does not analyze it or authorize uploading it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // Subtitle instructions
        Text(
          controller.isScreenshotSource
              ? 'Check the extracted text against your screenshot. Words or numbers may have been misread.'
              : 'Check the message and remove details you do not want included.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // Screenshot Comparison Section (if screenshot source)
        if (controller.isScreenshotSource) ...[
          _buildScreenshotComparisonSection(theme, brightness),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
        ],

        // Editable Text Editor
        AppTextField(
          controller: controller.textEditingController,
          focusNode: controller.focusNode,
          label: 'Message text',
          hint: 'Review and correct message content here...',
          multiline: true,
          minLines: 5,
          maxLines: 12,
          counterText: MessageTextValidator.formatCharacterCount(
            controller.codePointCount.value,
          ),
          errorText: controller.validationError.value?.message,
        ),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // Check for Sensitive Details Button
        AppButton.secondary(
          label: 'Check for sensitive details',
          onPressed: controller.checkSensitiveDetails,
        ),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // Sensitive Data Suggestions Section
        if (controller.hasDetected.value) ...[
          _buildSensitiveDataSection(theme, brightness),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
        ],

        // Read-only Final Text Preview
        _buildPreviewSection(theme, brightness),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // Confirm Button
        AppButton.primary(
          label: 'Confirm reviewed text',
          onPressed: controller.isConfirmed.value
              ? null
              : () => controller.confirmReviewedText(),
        ),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // Confirmed Success Banner
        if (controller.isConfirmed.value) ...[
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, color: successColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reviewed text is ready on this device. It has not been analyzed or sent anywhere.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: successColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
        ],

        // Safe-use guidance card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How TrustCue handles your text',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All corrections and redactions remain local to your device session.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              AppButton.secondary(
                label: 'Review safe-use guidance',
                onPressed: controller.openSafeUseGuidance,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
      ],
    );
  }

  Widget _buildScreenshotComparisonSection(
    ThemeData theme,
    Brightness brightness,
  ) {
    if (!controller.isComparisonImageAvailable) {
      return AppCard(
        child: Row(
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 20,
              color: theme.hintColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Screenshot comparison is unavailable; you can still review and edit the text.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Screenshot comparison',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: controller.toggleComparisonImage,
                icon: Icon(
                  controller.showComparisonImage.value
                      ? Icons.expand_less
                      : Icons.expand_more,
                ),
                label: Text(
                  controller.showComparisonImage.value ? 'Hide' : 'Show',
                ),
              ),
            ],
          ),
          if (controller.showComparisonImage.value) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(controller.reviewInput!.imagePath!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensitiveDataSection(ThemeData theme, Brightness brightness) {
    final candidates = controller.candidates;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Possible sensitive details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These checks can miss information or flag ordinary text. Review the message yourself.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Redactions apply to this text, not to the original screenshot.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          if (candidates.isEmpty) ...[
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: theme.hintColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No suggestions found. This does not mean the text contains no sensitive information.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: controller.selectAllCandidates,
                  child: const Text('Select all'),
                ),
                TextButton(
                  onPressed: controller.clearCandidateSelections,
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const Divider(),
            ...candidates.map((c) => _buildCandidateTile(c, theme, brightness)),
          ],
        ],
      ),
    );
  }

  Widget _buildCandidateTile(
    SensitiveDataCandidate candidate,
    ThemeData theme,
    Brightness brightness,
  ) {
    final isSelected = controller.selectedCandidateIds.contains(candidate.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => controller.toggleCandidate(candidate.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => controller.toggleCandidate(candidate.id),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            candidate.type.placeholder,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            candidate.maskedLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      candidate.contextSummary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection(ThemeData theme, Brightness brightness) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Final text preview',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: SelectableText(
              controller.previewText.value.isEmpty
                  ? '(No text entered)'
                  : controller.previewText.value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
