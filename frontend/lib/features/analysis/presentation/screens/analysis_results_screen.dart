import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_indicator_group.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';

/// Screen displaying deterministic on-device analysis results, scope limitations,
/// factual evidence trail, and prioritized protective actions.
///
/// Principles:
/// - Never presents findings as a definitive fraud score, probability, or safe verdict.
/// - Outcome states are factual observations from local checks.
/// - No-match outcome is explicitly stated as NOT proof of safety (no green shield or safe badges).
/// - Partial coverage constraints remain visible even when findings are detected.
/// - Exposes complete evidence trail with UTF-16 offset traceability and educational context.
/// - Does not include nonfunctional Save, Share, AI, or History controls.
class AnalysisResultsScreen extends GetView<AnalysisResultsController> {
  const AnalysisResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Return to review',
          onPressed: controller.returnToReview,
        ),
      ),
      body: AppPageBody(
        child: Obx(() {
          switch (controller.state.value) {
            case AnalysisState.initial:
            case AnalysisState.running:
              return _buildRunningState(theme);
            case AnalysisState.failedOrUnsupported:
              return _buildFailureState(theme);
            case AnalysisState.completedWithIndicators:
            case AnalysisState.completedWithNoMatches:
            case AnalysisState.limitedCoverage:
              final assessment = controller.assessment.value;
              if (assessment == null) {
                return _buildFailureState(theme);
              }
              return _buildResultsContent(theme, assessment, context);
          }
        }),
      ),
    );
  }

  Widget _buildRunningState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.pagePaddingLarge,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Running local scam indicator checks on this device',
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            Text(
              'Analyzing on this device...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Evaluating text using on-device rules.\nNothing is being uploaded to any server or network.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.pagePaddingSmall),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Analysis unavailable',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                controller.errorMessage.value ?? 'Local analysis could not be completed for the provided text.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Return to review',
                      onPressed: controller.returnToReview,
                    ),
                  ),
                  if (controller.args != null && controller.args!.isValid) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton.primary(
                        label: 'Retry',
                        onPressed: controller.retryAnalysis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsContent(
    ThemeData theme,
    LocalAssessment assessment,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A. Header Banner
        _buildHeaderBanner(theme),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // B. Outcome Summary
        _buildOutcomeSummary(theme, assessment),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // C. Coverage and Limitations
        _buildCoverageAndLimitations(theme, assessment),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // D. Evidence Trail
        _buildEvidenceTrail(theme, assessment, context),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // E. Suggested Next Steps
        _buildSuggestedNextSteps(theme, assessment),
        const SizedBox(height: AppSpacing.pagePaddingLarge),

        // F. Navigation Actions
        _buildNavigationActions(theme),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
      ],
    );
  }

  Widget _buildHeaderBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingSmall),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.phonelink_lock_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local on-device analysis',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Evaluated on this device using local rules. Nothing was uploaded.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeSummary(ThemeData theme, LocalAssessment assessment) {
    final IconData icon;
    final Color iconColor;
    final String heading;
    final Color bannerBg;

    switch (assessment.outcomeState) {
      case AssessmentOutcomeState.indicatorsDetected:
        icon = Icons.warning_amber_rounded;
        iconColor = theme.colorScheme.error;
        heading = assessment.totalFindingsCount == 1
            ? '1 potential warning indicator detected'
            : '${assessment.totalFindingsCount} potential warning indicators detected';
        bannerBg = theme.colorScheme.errorContainer.withValues(alpha: 0.2);
        break;
      case AssessmentOutcomeState.noIndicatorsMatched:
        // NEVER a green checkmark or green shield! Use neutral informational style.
        icon = Icons.info_outline;
        iconColor = theme.colorScheme.primary;
        heading = 'No indicators matched';
        bannerBg = theme.colorScheme.surfaceContainerHighest;
        break;
      case AssessmentOutcomeState.limitedCoverage:
        icon = Icons.rule_folder_outlined;
        iconColor = theme.colorScheme.tertiary;
        heading = 'Limited rule coverage';
        bannerBg = theme.colorScheme.surfaceContainerHighest;
        break;
    }

    return AppCard(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    heading,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(assessment.factualSummary, style: theme.textTheme.bodyMedium),
            if (assessment.outcomeState ==
                AssessmentOutcomeState.noIndicatorsMatched) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: theme.hintColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Not a proof of safety: on-device rules check specific known patterns and do not evaluate sender identity or all scam methods.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoverageAndLimitations(
    ThemeData theme,
    LocalAssessment assessment,
  ) {
    final coverage = assessment.coverageInfo;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.rule_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scope and rule coverage',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(coverage.coverageDescription, style: theme.textTheme.bodyMedium),
          if (coverage.skippedRuleIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Partial coverage: ${coverage.skippedRuleIds.length} rule(s) were skipped due to input constraints.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: controller.toggleLimitationsDetails,
            icon: Icon(
              controller.showLimitationsDetails.value
                  ? Icons.expand_less
                  : Icons.expand_more,
            ),
            label: Text(
              controller.showLimitationsDetails.value
                  ? 'Hide limitations and uncertainty notes'
                  : 'View limitations and uncertainty notes',
            ),
          ),
          if (controller.showLimitationsDetails.value) ...[
            const Divider(),
            ...assessment.uncertaintyNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(note, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceTrail(
    ThemeData theme,
    LocalAssessment assessment,
    BuildContext context,
  ) {
    if (assessment.groupedIndicators.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.search_off_outlined, size: 20, color: theme.hintColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No scam indicator findings were generated for this text.',
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
              Icons.receipt_long_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Evidence trail',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...assessment.groupedIndicators.map(
          (group) => _buildIndicatorGroupCard(theme, group, context),
        ),
      ],
    );
  }

  Widget _buildIndicatorGroupCard(
    ThemeData theme,
    AssessmentIndicatorGroup group,
    BuildContext context,
  ) {
    final edu = group.educationalContext;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.pagePaddingSmall),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Group Header with Category
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    group.categoryLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                Text(
                  group.findings.length == 1
                      ? '1 finding'
                      : '${group.findings.length} findings',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Educational Context Section
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
                    'What was observed:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(edu.whatObserved, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    'Why it deserves attention:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(edu.whyAttention, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    'What this check cannot establish:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    edu.whatCannotEstablish,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Independent verification step:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    edu.independentVerificationStep,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Individual Findings
            ...group.findings.map(
              (finding) => _buildFindingTile(theme, finding, context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindingTile(
    ThemeData theme,
    AnalysisFinding finding,
    BuildContext context,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
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
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
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
                  Text(
                    '"${ref.exactExcerpt}"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'offset [${ref.startOffset}, ${ref.endOffset})',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
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

  Widget _buildSuggestedNextSteps(ThemeData theme, LocalAssessment assessment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                'Suggested next steps',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...assessment.actionableSteps.map(
          (action) => _buildActionCard(theme, action),
        ),
      ],
    );
  }

  Widget _buildActionCard(ThemeData theme, AssessmentAction action) {
    final String priorityBadge;
    final Color badgeBg;
    final Color badgeFg;

    switch (action.priority) {
      case AssessmentActionPriority.immediate:
        priorityBadge = 'Immediate protective step';
        badgeBg = theme.colorScheme.errorContainer;
        badgeFg = theme.colorScheme.onErrorContainer;
        break;
      case AssessmentActionPriority.recommended:
        priorityBadge = 'Recommended verification';
        badgeBg = theme.colorScheme.primaryContainer;
        badgeFg = theme.colorScheme.onPrimaryContainer;
        break;
      case AssessmentActionPriority.conditional:
        priorityBadge = 'Conditional guidance';
        badgeBg = theme.colorScheme.secondaryContainer;
        badgeFg = theme.colorScheme.onSecondaryContainer;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priorityBadge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: badgeFg,
                    ),
                  ),
                ),
                if (action.isConditionalPostAction) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'If already acted',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              action.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(action.description, style: theme.textTheme.bodyMedium),
            if (action.supportingCategoryIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Motivated by: ${action.supportingCategoryIds.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton.secondary(
          label: 'Return to review and edit text',
          onPressed: controller.returnToReview,
        ),
        const SizedBox(height: 8),
        AppButton.secondary(
          label: 'Review safe-use guidance',
          onPressed: controller.openSafeUseGuidance,
        ),
      ],
    );
  }
}
