import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/guide/domain/models/guide_topic.dart';
import 'package:trustcue_mobile/features/guide/domain/models/practice_example.dart';
import 'package:trustcue_mobile/features/guide/presentation/controllers/user_guide_controller.dart';
import 'package:trustcue_mobile/features/localization/presentation/widgets/language_selector_dialog.dart';

/// Offline User Guide screen with quick-start steps, safe guided practice,
/// and 6 comprehensive expandable reference topics.
class UserGuideScreen extends GetView<UserGuideController> {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('guide_title'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'language'.tr,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => LanguageSelectorDialog.show(context),
          ),
        ],
      ),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Text(
              'guide_title'.tr,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'guide_subtitle'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),

            // Quick Start 3-Step Banner
            _buildQuickStartBanner(theme),
            const SizedBox(height: 24),

            // Safe Guided Practice Section
            _buildPracticeSection(context, theme),
            const SizedBox(height: 24),

            // Comprehensive Guide Topics Section
            _buildTopicsSection(context, theme),
            const SizedBox(height: AppSpacing.pagePaddingLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartBanner(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'guide_quick_start_title'.tr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickStepItem(
            theme: theme,
            stepNumber: '1',
            titleKey: 'guide_step1_title',
            descKey: 'guide_step1_desc',
          ),
          const SizedBox(height: 12),
          _buildQuickStepItem(
            theme: theme,
            stepNumber: '2',
            titleKey: 'guide_step2_title',
            descKey: 'guide_step2_desc',
          ),
          const SizedBox(height: 12),
          _buildQuickStepItem(
            theme: theme,
            stepNumber: '3',
            titleKey: 'guide_step3_title',
            descKey: 'guide_step3_desc',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStepItem({
    required ThemeData theme,
    required String stepNumber,
    required String titleKey,
    required String descKey,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleKey.tr,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descKey.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'guide_practice_section_title'.tr,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'guide_practice_section_desc'.tr,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...controller.practiceExamples.map(
          (example) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildPracticeCard(context, theme, example),
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeCard(
    BuildContext context,
    ThemeData theme,
    PracticeExample example,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Synthetic Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 14,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'guide_practice_tag_synthetic'.tr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Title & Description
          Text(
            example.titleKey.tr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            example.descriptionKey.tr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Synthetic Message Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    example.syntheticText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Expected Signals Explanation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: example.isWarningSample
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.25)
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  example.isWarningSample
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  size: 18,
                  color: example.isWarningSample
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    example.explanationKey.tr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: example.isWarningSample
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Button
          AppButton.primary(
            label: 'guide_practice_start_btn'.tr,
            icon: Icons.play_arrow_rounded,
            onPressed: () => controller.launchPractice(example, context),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'guide_topics_heading'.tr,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...controller.topics.map(
          (topic) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildTopicAccordion(context, theme, topic),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicAccordion(
    BuildContext context,
    ThemeData theme,
    GuideTopic topic,
  ) {
    return Obx(() {
      final isExpanded = controller.isTopicExpanded(topic.id);

      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => controller.toggleTopic(topic.id),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        topic.icon,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.titleKey.tr,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            topic.subtitleKey.tr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const Divider(height: 24),
              if (topic.illustrationBuilder != null) ...[
                Center(child: topic.illustrationBuilder!(context)),
                const SizedBox(height: 12),
              ],
              ...topic.sections.map(
                (sec) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sec.icon != null) ...[
                        Icon(
                          sec.icon,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sec.titleKey.tr,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sec.bodyKey.tr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
