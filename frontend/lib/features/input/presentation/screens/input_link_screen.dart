import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';

import '../controllers/input_link_controller.dart';
import '../../domain/models/link_inspection_result.dart';
import '../../domain/models/qr_payload.dart';
import '../../domain/models/selected_image_descriptor.dart';

/// Screen allowing users to inspect a typed/pasted web address or decode QR codes
/// from an on-device image, review destination details and structural observations,
/// and explicitly launch external destinations.
class InputLinkScreen extends GetView<InputLinkController> {
  const InputLinkScreen({super.key, this.imageBuilder});

  final Widget Function(BuildContext context, String filePath)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Link or QR code')),
      body: AppPageBody(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSafetyGuidance(theme),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              _buildModeSelector(theme),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              Obx(() {
                if (controller.currentMode.value == LinkIntakeMode.text) {
                  return _buildTextInputSection(theme);
                } else {
                  return _buildQrInputSection(context, theme);
                }
              }),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              Obx(() => _buildActiveInspectionSection(context, theme)),
              Obx(() => _buildReviewedStatusBanner(theme)),
              Obx(() => _buildLaunchErrorBanner(theme)),
              Obx(() => _buildConfirmationModal(context, theme)),
              const SizedBox(height: AppSpacing.pagePaddingLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyGuidance(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  'Link inspection and local checks are available. Results are indicators, not a verdict.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingSmall),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Safety reminder', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Avoid opening an unfamiliar destination just to check it. Scam messages frequently conceal destination addresses using URL shorteners, typosquatting, or QR codes.',
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
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Obx(() {
      final mode = controller.currentMode.value;
      return SegmentedButton<LinkIntakeMode>(
        segments: const [
          ButtonSegment(
            value: LinkIntakeMode.text,
            label: Text('Web address'),
            icon: Icon(Icons.link),
          ),
          ButtonSegment(
            value: LinkIntakeMode.qr,
            label: Text('QR image'),
            icon: Icon(Icons.qr_code),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (Set<LinkIntakeMode> newSelection) {
          controller.switchMode(newSelection.first);
        },
      );
    });
  }

  Widget _buildTextInputSection(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Web address', style: theme.textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Paste'),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data != null && data.text != null) {
                    controller.urlTextController.text = data.text!;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: controller.urlTextController,
            label: 'Destination URL',
            hint: 'e.g., https://example.com',
            helperText: 'Type or paste a destination URL (up to 4,096 bytes). Explicit "http://" or "https://" required.',
            multiline: false,
          ),
          const SizedBox(height: 12),
          AppButton.primary(
            label: 'Inspect link',
            icon: Icons.search,
            onPressed: controller.inspectTextLink,
          ),
        ],
      ),
    );
  }

  Widget _buildQrInputSection(BuildContext context, ThemeData theme) {
    final image = controller.selectedQrImage.value;
    final isDecoding = controller.isDecodingQr.value;
    final isPicking = controller.isPickingImage.value;
    final validationError = controller.imageValidationError.value;
    final qrResult = controller.qrDecodeResult.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (image == null) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Select an image containing a QR code',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'TrustCue inspects QR codes from existing screenshots or photos. Live camera scanning is not used to prevent unintended background actions.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                AppButton.primary(
                  label: isPicking ? 'Selecting...' : 'Choose QR image',
                  icon: Icons.photo_library,
                  isLoading: isPicking,
                  onPressed: isPicking ? null : controller.chooseQrImage,
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 12),
                  _buildValidationErrorNotice(validationError.message, theme),
                ],
              ],
            ),
          ),
        ] else ...[
          _buildQrPreviewCard(context, theme, image, isDecoding, isPicking),
          if (validationError != null) ...[
            const SizedBox(height: 8),
            _buildValidationErrorNotice(validationError.message, theme),
          ],
          if (qrResult != null) ...[
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            _buildQrResultCard(theme, qrResult),
          ],
        ],
      ],
    );
  }

  Widget _buildQrPreviewCard(
    BuildContext context,
    ThemeData theme,
    SelectedImageDescriptor image,
    bool isDecoding,
    bool isPicking,
  ) {
    final fileSizeMb = (image.byteCount / (1024 * 1024)).toStringAsFixed(2);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Selected QR image',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${image.width} × ${image.height} • $fileSizeMb MB',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 3.0,
              child: Center(
                child: imageBuilder != null
                    ? imageBuilder!(context, image.filePath)
                    : Image.file(
                        File(image.filePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(Icons.broken_image, size: 40),
                            ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppButton.primary(
            label: isDecoding ? 'Decoding QR code...' : 'Decode QR code',
            icon: Icons.qr_code,
            isLoading: isDecoding,
            onPressed: (isDecoding || isPicking)
                ? null
                : controller.decodeQrImage,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Replace image',
                  icon: Icons.photo_library_outlined,
                  onPressed: isDecoding ? null : controller.chooseQrImage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.secondary(
                  label: 'Remove',
                  icon: Icons.delete_outline,
                  onPressed: isDecoding ? null : controller.removeQrImage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrResultCard(ThemeData theme, dynamic qrResult) {
    if (qrResult.isEmpty as bool) {
      return AppCard(
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text('No QR code detected', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'No QR code found in the selected image. Please ensure the QR code is clearly visible, well-lit, and in focus.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final payloads = qrResult.payloads as List<QrPayload>;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payloads.length > 1
                      ? 'Detected ${payloads.length} QR codes'
                      : 'Decoded QR code',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (payloads.length > 1) ...[
            Text(
              'Multiple QR codes were found in this image. Select one to review:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ...payloads.map((payload) {
              final isSelected = controller.selectedPayload.value == payload;
              return InkWell(
                onTap: () => controller.selectPayload(payload),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.4,
                          )
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payload.formatDescription,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              payload.summary,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            _buildSinglePayloadOverview(theme, payloads.first),
          ],
        ],
      ),
    );
  }

  Widget _buildSinglePayloadOverview(ThemeData theme, QrPayload payload) {
    if (payload.type == QrPayloadType.unsupported) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.block, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  payload.formatDescription,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Payload: ${payload.summary}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'TrustCue only inspects and opens standard web destinations. Wi-Fi connection, contact card saving, and external application intents are deliberately not executed.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Review payload text',
              icon: Icons.edit_note,
              onPressed: controller.reviewText,
            ),
          ],
        ),
      );
    } else if (payload.type == QrPayloadType.plainText) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Plain Text Payload', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(payload.rawValue, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Review text in editor',
              icon: Icons.edit_note,
              onPressed: controller.reviewText,
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActiveInspectionSection(BuildContext context, ThemeData theme) {
    final inspection = controller.activeInspection;
    if (inspection == null) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.travel_explore,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Destination Review',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEligibilityStatusBanner(inspection, theme),
          const SizedBox(height: 12),
          if (inspection.host != null) ...[
            _buildDestinationDetailsGrid(inspection, theme),
            const SizedBox(height: 12),
          ],
          _buildFullUrlBox(inspection.rawInput, theme),
          if (inspection.observations.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Structural Observations', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            ...inspection.observations.map(
              (obs) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Icon(
                        Icons.arrow_right,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Text(obs, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton.primary(
                  label: 'Open externally',
                  icon: Icons.open_in_browser,
                  onPressed: controller.canOpenExternally
                      ? controller.requestOpenExternal
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.secondary(
                  label: 'Review text',
                  icon: Icons.edit_note,
                  onPressed: controller.reviewText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityStatusBanner(
    LinkInspectionResult inspection,
    ThemeData theme,
  ) {
    if (inspection.isLaunchable) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Destination is eligible for external opening.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cannot be opened externally',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inspection.rejectionReason ?? 'Invalid destination.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDestinationDetailsGrid(
    LinkInspectionResult inspection,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: inspection.scheme == 'https'
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  inspection.scheme?.toUpperCase() ?? 'NONE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inspection.host ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (inspection.port != null) ...[
                Text(
                  ':${inspection.port}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (inspection.path != null && inspection.path != '/') ...[
            const SizedBox(height: 6),
            Text('Path: ${inspection.path}', style: theme.textTheme.bodySmall),
          ],
          if (inspection.query != null) ...[
            const SizedBox(height: 4),
            Text(
              'Query: ?${inspection.query}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullUrlBox(String rawUrl, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exact Destination URL', style: theme.textTheme.labelMedium),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy URL',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: rawUrl));
                },
              ),
            ],
          ),
          SelectableText(
            rawUrl,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationErrorNotice(String message, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewedStatusBanner(ThemeData theme) {
    final reviewed = controller.reviewedResult.value;
    if (reviewed == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.pagePaddingSmall),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_note, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Text reviewed in editor (${reviewed.snapshot.text.length} chars, ${reviewed.totalRedactions} redaction(s)). Held in-memory.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaunchErrorBanner(ThemeData theme) {
    final error = controller.launchErrorMessage.value;
    if (error == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.pagePaddingSmall),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationModal(BuildContext context, ThemeData theme) {
    if (!controller.showOpenConfirmation.value) return const SizedBox.shrink();

    final inspection = controller.activeInspection;
    if (inspection == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.pagePaddingSmall),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Open in external browser?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You are about to leave TrustCue and open this destination in an external browser app:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inspection.host ?? '',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    inspection.rawInput,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Never provide passwords or authentication codes on an unverified website. External destinations are not analyzed or verified by TrustCue.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'Cancel',
                    onPressed: controller.cancelOpenExternal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton.primary(
                    label: 'Open destination',
                    icon: Icons.open_in_new,
                    isLoading: controller.isOpeningExternal.value,
                    onPressed: controller.confirmOpenExternal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
