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

/// Screen allowing users to select, validate, and interactively preview a screenshot
/// locally before future text extraction and analysis modules.
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
                    label: 'Replace image',
                    icon: Icons.refresh_outlined,
                    isLoading: controller.isProcessing.value,
                    onPressed: controller.isProcessing.value
                        ? null
                        : () => controller.chooseImage(),
                  ),
                  const SizedBox(height: AppSpacing.pagePaddingSmall),
                  AppButton.secondary(
                    label: 'Remove image',
                    icon: Icons.delete_outline,
                    onPressed: controller.isProcessing.value
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

  Widget _buildPreviewArea(
    BuildContext context,
    SelectedImageDescriptor image,
  ) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Container(
        height: 320,
        width: double.infinity,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          clipBehavior: Clip.hardEdge,
          child: Center(
            child: imageBuilder != null
                ? imageBuilder!(context, image.filePath)
                : Image.file(
                    File(image.filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        'Unable to load preview',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Image details', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Format', style: theme.textTheme.bodyMedium),
              Text(
                image.formatName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dimensions', style: theme.textTheme.bodyMedium),
              Text(
                image.dimensionsText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Size', style: theme.textTheme.bodyMedium),
              Text(
                image.formattedFileSize,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
