import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';

/// Modal bottom sheet presenting contextual educational guidance on how to interpret
/// TrustCue scam analysis results, evidence citations, safety boundaries, and persistence.
///
/// Invariants:
/// - Purely educational and non-blocking: dismissible at any time.
/// - Available completely offline without network dependencies.
/// - Fully localized in English and Urdu with natural text flow.
/// - Adheres to WCAG 2.1 AA: 48x48 dp touch targets, bounded scroll area, 200% text scale support.
/// - Does NOT bundle consent, data collection, or marketing.
class HowToReadResultsSheet extends StatelessWidget {
  const HowToReadResultsSheet({super.key});

  /// Displays the contextual help sheet modally.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const HowToReadResultsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row with Title and Close Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingLarge,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'how_to_read_results_title'.tr,
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
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingLarge,
              ),
              child: Text(
                'how_to_read_results_subtitle'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingLarge,
                  vertical: AppSpacing.pagePaddingSmall,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGuidanceItem(
                      theme: theme,
                      icon: Icons.lightbulb_outline,
                      iconColor: theme.colorScheme.tertiary,
                      title: 'help_clues_title'.tr,
                      description: 'help_clues_desc'.tr,
                    ),
                    const SizedBox(height: 14),
                    _buildGuidanceItem(
                      theme: theme,
                      icon: Icons.shield_outlined,
                      iconColor: theme.colorScheme.primary,
                      title: 'help_no_matches_title'.tr,
                      description: 'help_no_matches_desc'.tr,
                    ),
                    const SizedBox(height: 14),
                    _buildGuidanceItem(
                      theme: theme,
                      icon: Icons.search_outlined,
                      iconColor: theme.colorScheme.secondary,
                      title: 'help_evidence_title'.tr,
                      description: 'help_evidence_desc'.tr,
                    ),
                    const SizedBox(height: 14),
                    _buildGuidanceItem(
                      theme: theme,
                      icon: Icons.device_hub_outlined,
                      iconColor: theme.colorScheme.primary,
                      title: 'help_local_ai_title'.tr,
                      description: 'help_local_ai_desc'.tr,
                    ),
                    const SizedBox(height: 14),
                    _buildGuidanceItem(
                      theme: theme,
                      icon: Icons.lock_outline,
                      iconColor: theme.hintColor,
                      title: 'help_actions_title'.tr,
                      description: 'help_actions_desc'.tr,
                    ),
                    const SizedBox(height: AppSpacing.pagePaddingLarge),
                    AppButton.primary(
                      label: 'help_close_btn'.tr,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: AppSpacing.pagePaddingSmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceItem({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.85,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

