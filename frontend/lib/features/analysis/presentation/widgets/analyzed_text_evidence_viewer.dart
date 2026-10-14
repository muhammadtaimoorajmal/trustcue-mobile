import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';

/// Interactive viewer displaying the exact analyzed plain text with highlighted evidence spans.
///
/// Principles:
/// - Slices text strictly by UTF-16 code-unit offsets; never performs loose string searches.
/// - Renders plain text only: never parses HTML, Markdown, or creates clickable links.
/// - Displays redacted text exactly as confirmed; never recovers original sensitive data.
/// - Provides non-color-alone indicators (underlines and labeled badges) for accessibility.
/// - Gracefully displays a safe unavailable notice if evidence offsets are malformed.
class AnalyzedTextEvidenceViewer extends StatelessWidget {
  final String analyzedText;
  final AnalysisFinding finding;

  const AnalyzedTextEvidenceViewer({
    super.key,
    required this.analyzedText,
    required this.finding,
  });

  /// Displays the evidence viewer in a scrollable modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String analyzedText,
    required AnalysisFinding finding,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetCtx, scrollController) => AnalyzedTextEvidenceViewer(
          analyzedText: analyzedText,
          finding: finding,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Validate evidence references
    final validationError = _validateEvidence();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingSmall,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle and header
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Evidence in analyzed text',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close evidence view',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Finding Context Banner
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.explanation,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rule provenance: ${finding.producerId} (on-device local rule)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: finding.evidence.map((ref) {
                    return Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(4),
                      avatar: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          '${ref.startOffset}',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      label: Text(
                        'Span [${ref.startOffset}, ${ref.endOffset}): "${ref.exactExcerpt}"',
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Privacy note
          Text(
            'Analyzed text is displayed as plain text. Links are not clickable. Redactions applied during review are preserved.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 8),

          // Content body
          Expanded(
            child: AppCard(
              child: SingleChildScrollView(
                child: validationError != null
                    ? _buildMalformedErrorState(theme, validationError)
                    : _buildHighlightedTextContent(theme),
              ),
            ),
          ),
          const SizedBox(height: 8),

          AppButton.secondary(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  String? _validateEvidence() {
    for (final ref in finding.evidence) {
      if (ref.startOffset < 0 ||
          ref.endOffset > analyzedText.length ||
          ref.startOffset >= ref.endOffset) {
        return 'Evidence span [${ref.startOffset}, ${ref.endOffset}) is out of bounds for analyzed text length (${analyzedText.length}).';
      }
      final actualSubstring = analyzedText.substring(
        ref.startOffset,
        ref.endOffset,
      );
      if (actualSubstring != ref.exactExcerpt) {
        return 'Evidence excerpt does not match snapshot text at offsets [${ref.startOffset}, ${ref.endOffset}).';
      }
    }
    return null;
  }

  Widget _buildMalformedErrorState(ThemeData theme, String error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Evidence highlight unavailable',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'The evidence references could not be verified against the analyzed text snapshot. No replacement excerpt was fabricated.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Analyzed text snapshot:',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          analyzedText,
          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildHighlightedTextContent(ThemeData theme) {
    final spans = _buildTextSpans(theme);

    return Semantics(
      label: 'Analyzed plain text with highlighted evidence segments',
      child: SelectableText.rich(
        TextSpan(children: spans),
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  List<InlineSpan> _buildTextSpans(ThemeData theme) {
    if (finding.evidence.isEmpty) {
      return [TextSpan(text: analyzedText)];
    }

    // Sort evidence references by start offset
    final sortedRefs = List<EvidenceReference>.from(finding.evidence)
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    // Merge overlapping or contiguous spans to avoid offset collisions
    final mergedSpans = <_SpanRange>[];
    for (final ref in sortedRefs) {
      if (mergedSpans.isEmpty) {
        mergedSpans.add(_SpanRange(ref.startOffset, ref.endOffset, [ref]));
      } else {
        final last = mergedSpans.last;
        if (ref.startOffset <= last.end) {
          // Overlap or contiguous: merge
          mergedSpans[mergedSpans.length - 1] = _SpanRange(
            last.start,
            math.max(last.end, ref.endOffset),
            [...last.refs, ref],
          );
        } else {
          mergedSpans.add(_SpanRange(ref.startOffset, ref.endOffset, [ref]));
        }
      }
    }

    final spans = <InlineSpan>[];
    var currentOffset = 0;

    final highlightBackground = theme.colorScheme.primaryContainer;
    final highlightForeground = theme.colorScheme.onPrimaryContainer;

    for (final range in mergedSpans) {
      // 1. Plain text before highlight
      if (range.start > currentOffset) {
        spans.add(
          TextSpan(text: analyzedText.substring(currentOffset, range.start)),
        );
      }

      // 2. Highlighted segment with accessible non-color indicators
      final segmentText = analyzedText.substring(range.start, range.end);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Semantics(
            label: 'Matched evidence: $segmentText',
            child: Container(
              key: ValueKey('evidence-highlight-${range.start}'),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: highlightBackground,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              child: Text(
                segmentText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: highlightForeground,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      );

      currentOffset = range.end;
    }

    // 3. Trailing plain text after all highlights
    if (currentOffset < analyzedText.length) {
      spans.add(TextSpan(text: analyzedText.substring(currentOffset)));
    }

    return spans;
  }
}

class _SpanRange {
  final int start;
  final int end;
  final List<EvidenceReference> refs;

  const _SpanRange(this.start, this.end, this.refs);
}
