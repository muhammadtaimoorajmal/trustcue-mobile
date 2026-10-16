import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

/// Card widget presenting a neutral summary of a locally saved analysis report.
///
/// Invariants & Privacy Controls:
/// - Displays metadata, outcome state, and provenance badges.
/// - To protect privacy in public spaces (shoulder surfing), preview text snippets
///   are hidden by default behind an explicit user-controlled toggle.
/// - Provides explicit actions to view full details or initiate confirmation-gated deletion.
class HistoryReportCard extends StatefulWidget {
  final SavedReportSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool initialShowPreview;

  const HistoryReportCard({
    super.key,
    required this.summary,
    required this.onTap,
    required this.onDelete,
    this.initialShowPreview = false,
  });

  @override
  State<HistoryReportCard> createState() => _HistoryReportCardState();
}

class _HistoryReportCardState extends State<HistoryReportCard> {
  late bool _showPreview;

  @override
  void initState() {
    super.initState();
    _showPreview = widget.initialShowPreview;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcomeBadge = _buildOutcomeBadge(theme);
    final provenanceBadge = _buildProvenanceBadge(theme);
    final sourceBadge = _buildSourceBadge(theme);

    return AppCard(
      child: InkWell(
        onTap: widget.onTap,
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
                    onPressed: widget.onDelete,
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
                      '${widget.summary.findingsCount} indicator(s)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // User-controlled preview text toggle (shoulder-surfing privacy)
              if (_showPreview) ...[
                Text(
                  widget.summary.previewText.isNotEmpty
                      ? widget.summary.previewText
                      : 'No preview text recorded.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: widget.summary.previewText.isNotEmpty
                        ? theme.textTheme.bodyMedium?.color
                        : theme.hintColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => setState(() => _showPreview = false),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 14,
                            color: theme.hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Hide snippet',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => setState(() => _showPreview = true),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Show snippet',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Footer: Date and View Details cue
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTimestamp(widget.summary.savedAt),
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

    switch (widget.summary.inputSource) {
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
    if (widget.summary.hasAiAnalysis) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '[AI-Assisted: ${widget.summary.aiProvider ?? 'Cloud'}]',
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

    switch (widget.summary.outcomeState) {
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
