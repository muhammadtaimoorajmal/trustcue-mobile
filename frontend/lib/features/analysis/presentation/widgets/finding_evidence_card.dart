import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/localization/domain/models/app_language.dart';

/// Reusable card displaying an individual analysis finding with clear plain-language
/// explanation, exact supporting quotation excerpts, interactive analyzed text navigation,
/// and an expandable technical details section isolating offsets and rule identifiers.
///
/// Invariants:
/// - Exact excerpt quotes are preserved byte-for-byte; never paraphrased or truncated.
/// - Excerpts use [determineExcerptDirection] so RTL/Urdu text remains RTL, while English/URLs remain LTR.
/// - Rule IDs and numeric offset spans `[start, end)` are hidden from the primary user view
///   and available within an expandable technical details drawer.
/// - Minimum 48x48 dp touch target on all interactive controls.
class FindingEvidenceCard extends StatefulWidget {
  final AnalysisFinding finding;
  final bool isAi;
  final VoidCallback onViewInAnalyzedText;
  final bool initiallyExpanded;

  const FindingEvidenceCard({
    super.key,
    required this.finding,
    required this.isAi,
    required this.onViewInAnalyzedText,
    this.initiallyExpanded = false,
  });

  @override
  State<FindingEvidenceCard> createState() => _FindingEvidenceCardState();
}

class _FindingEvidenceCardState extends State<FindingEvidenceCard> {
  late bool _showTechnicalDetails;

  @override
  void initState() {
    super.initState();
    _showTechnicalDetails = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finding = widget.finding;
    final isAi = widget.isAi || finding.origin == FindingOrigin.remoteAi;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Provenance Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAi
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAi ? '[AI-Assisted: Groq]' : '[On-device heuristic]',
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
                  isAi
                      ? 'Cloud AI pattern evaluation'
                      : 'Evaluated on this device',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Finding Explanation
          Text(
            finding.explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          // 3. Exact Supporting Excerpts
          if (finding.evidence.isNotEmpty) ...[
            Text(
              'Exact supporting excerpt(s):',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...finding.evidence.map(
              (ref) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Directionality(
                  textDirection: determineExcerptDirection(ref.exactExcerpt),
                  child: Text(
                    '"${ref.exactExcerpt}"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // 4. Action Row: View in analyzed text + Toggle Technical Details
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton.icon(
                icon: Icon(
                  _showTechnicalDetails ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _showTechnicalDetails
                      ? 'hide_technical_details'.tr
                      : 'show_technical_details'.tr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () {
                  setState(() {
                    _showTechnicalDetails = !_showTechnicalDetails;
                  });
                },
              ),
              AppButton.secondary(
                label: 'View in analyzed text',
                icon: Icons.find_in_page_outlined,
                onPressed: widget.onViewInAnalyzedText,
              ),
            ],
          ),

          // 5. Expandable Technical Details Section
          if (_showTechnicalDetails) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'technical_details_title'.tr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAi
                        ? 'Model provenance: ${finding.producerId} (Groq Cloud)'
                        : 'Rule provenance: ${finding.producerId} (on-device local rule)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  ...finding.evidence.map(
                    (ref) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'offset [${ref.startOffset}, ${ref.endOffset}) • snapshot: ${ref.snapshotId}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
