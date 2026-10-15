import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

/// Card widget presenting a neutral summary of a locally saved analysis report.
///
/// Invariants:
/// - Displays metadata, outcome state, provenance badges, and preview text.
/// - Never exposes raw unredacted sensitive values; relies on bounded [SavedReportSummary.previewText].
/// - Provides explicit actions to view full details or initiate confirmation-gated deletion.
class HistoryReportCard extends StatelessWidget {
  final SavedReportSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HistoryReportCard({
    super.key,
    required this.summary,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcomeBadge = _buildOutcomeBadge(theme);
    final provenanceBadge = _buildProvenanceBadge(theme);
    final sourceBadge = _buildSourceBadge(theme);

    return AppCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingSmall),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: Source, Provenance, and Delete action
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sourceBadge,
                  const SizedBox(width: 8),
                  provenanceBadge,
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: 'Delete report from device',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Outcome badge & findings count
              Row(
                children: [
                  outcomeBadge,
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      '${summary.findingsCount} indicator(s)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Preview text snippet
              Text(
                summary.previewText.isNotEmpty
                    ? summary.previewText
                    : 'No preview text recorded.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: summary.previewText.isNotEmpty
                      ? theme.textTheme.bodyMedium?.color
                      : theme.hintColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Footer: Date and View Details cue
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTimestamp(summary.savedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View details',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceBadge(ThemeData theme) {
    final IconData icon;
    final String label;

    switch (summary.inputSource) {
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

  Widget _buildProvenanceBadge(ThemeData theme) {
    if (summary.hasAiAnalysis) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '[AI-Assisted: ${summary.aiProvider ?? 'Cloud'}]',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onTertiaryContainer,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  Widget _buildOutcomeBadge(ThemeData theme) {
    final Color color;
    final IconData icon;
    final String label;

    switch (summary.outcomeState) {
      case AssessmentOutcomeState.indicatorsDetected:
        color = theme.colorScheme.error;
        icon = Icons.warning_amber_rounded;
        label = 'Indicators detected';
        break;
      case AssessmentOutcomeState.noIndicatorsMatched:
        color = theme.colorScheme.primary;
        icon = Icons.info_outline;
        label = 'No indicators matched';
        break;
      case AssessmentOutcomeState.limitedCoverage:
        color = theme.colorScheme.secondary;
        icon = Icons.help_outline;
        label = 'Limited coverage';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
