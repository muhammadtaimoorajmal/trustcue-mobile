import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';

import '../controllers/input_screenshot_controller.dart';
import '../../domain/models/selected_image_descriptor.dart';

/// Screen allowing users to select, validate, interactively preview, and extract
/// text from a suspicious screenshot on-device.
class InputScreenshotScreen extends GetView<InputScreenshotController> {
  const InputScreenshotScreen({super.key, this.imageBuilder});

  final Widget Function(BuildContext context, String filePath)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final canDirectlyPop =
          Navigator.of(context).canPop() &&
          (!controller.hasImage || controller.isNavigatingAway.value);

      return PopScope(
        canPop: canDirectlyPop,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await controller.handleBack(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Screenshot'),
            leading: BackButton(
              onPressed: () => controller.handleBack(context),
            ),
          ),
          body: AppPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.pagePaddingSmall),
                if (!controller.hasImage) ...[
                  Text(
                    'Choose a screenshot of the message you want to review.',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For suspicious messages captured in an image.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.pagePaddingLarge),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Image preview is available. Text extraction and scam analysis are not available yet.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.pagePaddingSmall),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.photo_size_select_actual_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Supported formats: PNG, JPEG (up to 10 MB, 20 MP).',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.validationError.value != null) ...[
                    const SizedBox(height: AppSpacing.pagePaddingSmall),
                    AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.validationError.value!.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.pagePaddingLarge),
                  AppButton.primary(
                    label: 'Choose image',
                    icon: Icons.photo_library_outlined,
                    isLoading: controller.isProcessing.value,
                    onPressed: controller.isProcessing.value
                        ? null
                        : () => controller.chooseImage(),
                  ),
                ] else ...[
                  Text(
                    'Screenshot preview',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inspect the image before proceeding. Zoom and pan are available.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.pagePaddingLarge),
                  _buildPreviewArea(context, controller.selectedImage.value!),
                  const SizedBox(height: 8),
                  Text(
                    'Pinch or drag to zoom and pan.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.pagePaddingLarge),
                  _buildDetailsCard(context, controller.selectedImage.value!),
                  const SizedBox(height: AppSpacing.pagePaddingSmall),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected for local preview. TrustCue has not uploaded or analyzed this image.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.pagePaddingSmall),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.translate_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Text extraction currently supports Latin-script text, including English. Urdu and Arabic text in images are not supported yet.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.pagePaddingSmall),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Text extraction can miss or misread words. Check the result against your screenshot.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.validationError.value != null) ...[
                    const SizedBox(height: AppSpacing.pagePaddingSmall),
                    AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.validationError.value!.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.pagePaddingLarge),

                  // OCR extraction area
                  _buildOcrSection(context),

                  const SizedBox(height: AppSpacing.pagePaddingLarge),
                  AppButton.secondary(
                    label: 'Replace image',
                    icon: Icons.refresh_outlined,
                    isLoading: controller.isProcessing.value,
                    onPressed:
                        (controller.isProcessing.value ||
                            controller.isExtracting.value)
                        ? null
                        : () => controller.chooseImage(),
                  ),
                  const SizedBox(height: AppSpacing.pagePaddingSmall),
                  AppButton.secondary(
                    label: 'Remove image',
                    icon: Icons.delete_outline,
                    onPressed:
                        (controller.isProcessing.value ||
                            controller.isExtracting.value)
                        ? null
                        : () => controller.requestRemoveImage(context),
                  ),
                ],
                const SizedBox(height: AppSpacing.pagePaddingLarge),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety reminder',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check the image for passwords, OTPs, account numbers, and personal details before reviewing.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.pagePaddingSmall),
                AppButton.secondary(
                  label: 'Review safe-use guidance',
                  onPressed: () {
                    if (Get.currentRoute != AppRoutes.guidance) {
                      Get.toNamed(AppRoutes.guidance);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildOcrSection(BuildContext context) {
    final theme = Theme.of(context);

    if (controller.isExtracting.value) {
      return AppCard(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Extracting text on this device...',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Processing image with on-device Latin model.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AppButton.secondary(
              label: 'Cancel extraction',
              icon: Icons.cancel_outlined,
              onPressed: () => controller.cancelExtraction(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    if (controller.ocrFailure.value != null) {
      final failure = controller.ocrFailure.value!;
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        failure.message,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        failure.recoverySuggestion,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton.primary(
                    label: controller.isNativeSettling.value
                        ? 'Settling...'
                        : 'Retry extraction',
                    icon: Icons.refresh_outlined,
                    onPressed: controller.isNativeSettling.value
                        ? null
                        : () => controller.extractText(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'Enter text manually',
                    icon: Icons.edit_note_outlined,
                    onPressed: () => controller.navigateToMessageInput(),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (controller.ocrResult.value != null) {
      final result = controller.ocrResult.value!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Extracted text', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Extracted on this device. This text has not been reviewed or analyzed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: SelectableText(
                    result.snapshot.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
          AppButton.secondary(
            label: 'Extract text again',
            icon: Icons.document_scanner_outlined,
            onPressed: controller.isNativeSettling.value
                ? null
                : () => controller.extractText(),
          ),
        ],
      );
    }

    return AppButton.primary(
      label: 'Extract text',
      icon: Icons.document_scanner_outlined,
      isLoading: controller.isProcessing.value,
      onPressed:
          (controller.isProcessing.value || controller.isNativeSettling.value)
          ? null
          : () => controller.extractText(),
    );
  }

  Widget _buildPreviewArea(
    BuildContext context,
    SelectedImageDescriptor image,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: imageBuilder != null
              ? imageBuilder!(context, image.filePath)
              : Image.file(
                  File(image.filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Unable to display image preview.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    SelectedImageDescriptor image,
  ) {
    final theme = Theme.of(context);
    final sizeKb = (image.byteCount / 1024).toStringAsFixed(1);
    final sizeMb = (image.byteCount / (1024 * 1024)).toStringAsFixed(2);
    final formattedSize = image.byteCount > 1024 * 1024
        ? '$sizeMb MB'
        : '$sizeKb KB';
    final formatLabel = image.format.name.toUpperCase();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Image details', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 4,
            children: [
              Text('Format', style: theme.textTheme.bodySmall),
              Text(
                formatLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 4,
            children: [
              Text('Dimensions', style: theme.textTheme.bodySmall),
              Text(
                '${image.width} × ${image.height} px',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 4,
            children: [
              Text('File size', style: theme.textTheme.bodySmall),
              Text(
                formattedSize,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
