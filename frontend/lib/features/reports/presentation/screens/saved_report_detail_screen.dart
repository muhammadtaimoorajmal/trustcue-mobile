import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/export/domain/services/export_data_extractor.dart';
import 'package:trustcue_mobile/features/export/presentation/controllers/export_controller.dart';
import 'package:trustcue_mobile/features/export/presentation/widgets/export_report_sheet.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/localization/domain/models/app_language.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/presentation/controllers/saved_report_detail_controller.dart';

/// Screen presenting the full historical detail of a locally saved analysis report.
class SavedReportDetailScreen extends GetView<SavedReportDetailController> {
  const SavedReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Report Details'),
        actions: [
          Obx(() {
            final report = controller.report.value;
            if (report == null) {
              return const SizedBox.shrink();
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  tooltip: 'export_action_tooltip'.tr,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => _openExportSheet(context, report),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Delete report from device',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: controller.isDeleting.value
                      ? null
                      : () => controller.deleteCurrentReport(context),
                ),
              ],
            );
          }),
        ],
      ),
      body: AppPageBody(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value != null) {
            return _buildErrorState(theme);
          }

          final report = controller.report.value;
          if (report == null) {
            return const Center(child: Text('Report not found.'));
          }

          return _buildReportDetailContent(theme, report, context);
        }),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Could not open report',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.errorMessage.value ?? 'An unknown error occurred.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton.primary(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: controller.loadReport,
            ),
            const SizedBox(height: 8),
            AppButton.secondary(
              label: 'Back to saved reports',
              onPressed: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportDetailContent(
    ThemeData theme,
    SavedReport report,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Provenance & Metadata Banner
        _buildMetadataBanner(theme, report),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // 2. Outcome Status Card
        _buildOutcomeCard(theme, report),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // 3. Exact Reviewed Text Snapshot Card
        _buildSnapshotCard(theme, report),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // 4. Local Rule Indicator Findings
        _buildFindingsSection(
          theme,
          title: 'Local on-device findings',
          findings: report.localReport.findings,
          context: context,
          isAi: false,
        ),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // 5. Cloud AI Findings (if present)
        if (report.hasAiAnalysis && report.aiReport != null) ...[
          _buildFindingsSection(
            theme,
            title: 'Cloud AI findings (${report.aiReport!.provider})',
            findings: report.aiReport!.findings,
            context: context,
            isAi: true,
            aiSummary: report.aiReport!.factualSummary,
          ),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
        ],

        // 6. Historical Limitations & Uncertainty Notes
        _buildLimitationsCard(theme, report),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // 7. Suggested Verification Steps
        if (report.localReport.suggestedActions.isNotEmpty ||
            (report.aiReport?.suggestedActions.isNotEmpty ?? false)) ...[
          _buildSuggestedActions(theme, report),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
        ],

        // 8. Actions
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        AppButton.secondary(
          label: 'export_report_title'.tr,
          icon: Icons.ios_share_rounded,
          onPressed: () => _openExportSheet(context, report),
        ),
        const SizedBox(height: 8),
        AppButton.secondary(
          label: 'Delete report from this device',
          icon: Icons.delete_outline,
          onPressed: () => controller.deleteCurrentReport(context),
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
      ],
    );
  }

  void _openExportSheet(BuildContext context, SavedReport report) {
    final exportController = Get.isRegistered<ExportController>()
        ? Get.find<ExportController>()
        : Get.put(
            ExportController(
              hasSourceText: report.snapshot.text.isNotEmpty,
              hasAiFindings: report.hasAiAnalysis,
              hasEvidenceQuotes:
                  report.localReport.findings.any(
                    (f) => f.evidence.isNotEmpty,
                  ) ||
                  (report.aiReport?.findings.any(
                        (f) => f.evidence.isNotEmpty,
                      ) ??
                      false),
              dataFactory: (options) => ExportDataExtractor.fromSavedReport(
                report: report,
                options: options,
              ),
            ),
          );

    ExportReportSheet.show(context, controller: exportController).then((_) {
      if (Get.isRegistered<ExportController>()) {
        Get.delete<ExportController>();
      }
    });
  }

  Widget _buildMetadataBanner(ThemeData theme, SavedReport report) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingSmall),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildSourceBadge(theme, report.snapshot.source),
              if (report.hasAiAnalysis)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '[AI-Assisted: ${report.aiReport?.provider ?? 'Cloud'}]',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '[On-device heuristic]',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Saved: ${_formatDate(report.savedAt)} • Analyzed: ${_formatDate(report.analyzedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeCard(ThemeData theme, SavedReport report) {
    final IconData icon;
    final Color color;
    final String title;

    switch (report.outcomeState) {
      case AssessmentOutcomeState.indicatorsDetected:
        icon = Icons.warning_amber_rounded;
        color = theme.colorScheme.error;
        title = report.totalFindingsCount == 1
            ? '1 potential warning indicator detected'
            : '${report.totalFindingsCount} potential warning indicators detected';
        break;
      case AssessmentOutcomeState.noIndicatorsMatched:
        icon = Icons.info_outline;
        color = theme.colorScheme.primary;
        title = 'No warning indicators matched';
        break;
      case AssessmentOutcomeState.limitedCoverage:
        icon = Icons.help_outline;
        color = theme.colorScheme.secondary;
        title = 'Limited rule coverage on input';
        break;
    }

    return AppCard(
      child: Row(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Results reflect the state of checks at the time of evaluation.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard(ThemeData theme, SavedReport report) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Analyzed text snapshot',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${report.snapshot.text.length} chars',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: SelectableText(
              report.snapshot.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingsSection(
    ThemeData theme, {
    required String title,
    required List<AnalysisFinding> findings,
    required BuildContext context,
    required bool isAi,
    String? aiSummary,
  }) {
    if (findings.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.search_off_outlined, size: 20, color: theme.hintColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No indicators recorded in this category.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              isAi ? Icons.psychology_outlined : Icons.rule_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (aiSummary != null && aiSummary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(aiSummary, style: theme.textTheme.bodySmall),
          ),
        ],
        const SizedBox(height: 8),
        ...findings.map(
          (finding) => _buildFindingCard(theme, finding, context, isAi),
        ),
      ],
    );
  }

  Widget _buildFindingCard(
    ThemeData theme,
    AnalysisFinding finding,
    BuildContext context,
    bool isAi,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isAi
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAi ? '[AI-Assisted]' : '[Heuristic Rule]',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isAi
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.producerId,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            finding.explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exact supporting excerpt(s):',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ...finding.evidence.map(
            (ref) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  Directionality(
                    textDirection: determineExcerptDirection(ref.exactExcerpt),
                    child: Text(
                      '"${ref.exactExcerpt}"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'offset [${ref.startOffset}, ${ref.endOffset})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.secondary(
              label: 'View in analyzed text',
              onPressed: () => controller.viewEvidenceInText(finding, context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitationsCard(ThemeData theme, SavedReport report) {
    final allLimitations = [
      ...report.localReport.limitations,
      if (report.aiReport != null) ...report.aiReport!.uncertaintyNotes,
    ];

    if (allLimitations.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Original limitations and uncertainty notes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...allLimitations.map(
            (note) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(note, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedActions(ThemeData theme, SavedReport report) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rtl_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Suggested verification actions',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...report.localReport.suggestedActions.map(
            (action) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(action, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(ThemeData theme, InputSource source) {
    final IconData icon;
    final String label;

    switch (source) {
      case InputSource.messageText:
        icon = Icons.chat_bubble_outline;
        label = 'Text';
        break;
      case InputSource.screenshot:
        icon = Icons.image_outlined;
        label = 'Screenshot';
        break;
      case InputSource.link:
        icon = Icons.link_outlined;
        label = 'Link';
        break;
      case InputSource.qrCode:
        icon = Icons.qr_code_outlined;
        label = 'QR code';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
