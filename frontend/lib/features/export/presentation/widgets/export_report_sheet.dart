import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_format.dart';
import 'package:trustcue_mobile/features/export/presentation/controllers/export_controller.dart';

/// Modal bottom sheet allowing users to configure, preview, and share sanitized
/// reports in Plain Text or PDF format.
///
/// Invariants & Privacy Protections:
/// - Prominently displays privacy choices before any file creation or sharing.
/// - Inclusion options default to unchecked (summaries only).
/// - Live preview reflects exact content that will be shared.
/// - Warns when non-Latin/Urdu text is exported to PDF.
class ExportReportSheet extends StatelessWidget {
  final ExportController controller;

  const ExportReportSheet({super.key, required this.controller});

  /// Displays the export bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required ExportController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExportReportSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: maxSheetHeight,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.ios_share_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'export_report_title'.tr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'close'.tr,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Configuration & Preview
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Obx(() {
                    final options = controller.options.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Format Selection
                        Text(
                          'export_format_label'.tr,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('export_format_plain_text'.tr),
                              selected:
                                  options.format == ExportFormat.plainText,
                              onSelected: (_) =>
                                  controller.setFormat(ExportFormat.plainText),
                            ),
                            ChoiceChip(
                              label: Text('export_format_pdf'.tr),
                              selected: options.format == ExportFormat.pdf,
                              onSelected: (_) =>
                                  controller.setFormat(ExportFormat.pdf),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Non-Latin / Urdu PDF Notice or Block Warning
                        if (options.format == ExportFormat.pdf)
                          if (!controller.isPdfSupported)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.error,
                                  width: 0.8,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 18,
                                        color: colorScheme.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          controller.pdfUnsupportedReason ?? 'PDF export is unavailable because the report contains non-Latin script.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onErrorContainer,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => controller.setFormat(
                                      ExportFormat.plainText,
                                    ),
                                    child: Text(
                                      'Switch to Plain Text (.txt) ->',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.error,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'export_pdf_urdu_notice'.tr,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                        const SizedBox(height: 12),

                        // Information to Include Section
                        Text(
                          'export_include_options_title'.tr,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Checkbox: Reviewed Text
                        if (controller.hasSourceText)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              'export_include_text'.tr,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'export_include_text_desc'.tr,
                              style: theme.textTheme.bodySmall,
                            ),
                            value: options.includeReviewedText,
                            onChanged: (val) => controller
                                .toggleIncludeReviewedText(val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),

                        // Checkbox: Evidence Quotes
                        if (controller.hasEvidenceQuotes)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              'export_include_evidence'.tr,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'export_include_evidence_desc'.tr,
                              style: theme.textTheme.bodySmall,
                            ),
                            value: options.includeEvidenceQuotes,
                            onChanged: (val) => controller
                                .toggleIncludeEvidenceQuotes(val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),

                        // Checkbox: AI Explanations
                        if (controller.hasAiFindings)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              'export_include_ai'.tr,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'export_include_ai_desc'.tr,
                              style: theme.textTheme.bodySmall,
                            ),
                            value: options.includeAiExplanations,
                            onChanged: (val) => controller
                                .toggleIncludeAiExplanations(val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),

                        const SizedBox(height: 8),

                        // Privacy Warning Banner
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.error.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.privacy_tip_outlined,
                                size: 18,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'export_privacy_warning'.tr,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Live Preview Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'export_preview_title'.tr,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (controller.wasCopied.value)
                              Text(
                                'export_copied_toast'.tr,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 160,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                              width: 0.8,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              controller.previewText.value,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),

                        // Error message if any
                        if (controller.errorMessage.value != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            controller.errorMessage.value!,
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ),
              ),

              // Bottom Actions Bar
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(() {
                  final isSharing = controller.isSharing.value;
                  final isGenerating = controller.isGenerating.value;
                  final isPlainText =
                      controller.options.value.format == ExportFormat.plainText;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton.primary(
                        label: isSharing
                            ? 'export_sharing'.tr
                            : isGenerating
                            ? 'export_generating'.tr
                            : (!isPlainText && !controller.isPdfSupported)
                            ? 'PDF Unavailable (Use Plain Text)'
                            : 'export_share_button'.tr,
                        icon: Icons.share_rounded,
                        isLoading: isSharing || isGenerating,
                        onPressed: isSharing || isGenerating
                            ? null
                            : (!isPlainText && !controller.isPdfSupported)
                            ? () => controller.setFormat(ExportFormat.plainText)
                            : () => controller.shareReport(),
                      ),
                      if (isPlainText) ...[
                        const SizedBox(height: 8),
                        AppButton.secondary(
                          label: controller.wasCopied.value
                              ? 'export_copied_toast'.tr
                              : 'export_copy_button'.tr,
                          icon: Icons.copy_rounded,
                          onPressed: isSharing || isGenerating
                              ? null
                              : () => controller.copyPlainTextToClipboard(),
                        ),
                      ],
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
