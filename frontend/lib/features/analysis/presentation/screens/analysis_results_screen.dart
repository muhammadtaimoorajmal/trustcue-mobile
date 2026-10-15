import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_indicator_group.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';

/// Screen displaying deterministic on-device analysis results, scope limitations,
/// factual evidence trail, prioritized protective actions, and optional protected
/// cloud AI assistance.
///
/// Principles:
/// - Never presents findings as a definitive fraud score, probability, or safe verdict.
/// - Outcome states are factual observations from local checks.
/// - No-match outcome is explicitly stated as NOT proof of safety (no green shield or safe badges).
/// - Partial coverage constraints remain visible even when findings are detected.
/// - Exposes complete evidence trail with UTF-16 offset traceability and educational context.
/// - Distinct provenance: On-device findings are marked `[On-device heuristic]`, cloud findings `[AI-Assisted: Groq]`.
/// - Local on-device analysis remains the primary baseline and is preserved if cloud AI is unavailable.
/// - All text is rendered inert; never parsed as markdown or clickable HTML.
class AnalysisResultsScreen extends GetView<AnalysisResultsController> {
  const AnalysisResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis results'),
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

        // F. Optional Cloud AI Analysis Section
        _buildCloudAiSection(theme, context),
        const SizedBox(height: AppSpacing.pagePaddingLarge),

        // G. Navigation Actions
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
    final isAi = finding.origin == FindingOrigin.remoteAi;

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
                      ? 'Groq Cloud • ${finding.producerId}'
                      : 'Rule provenance: ${finding.producerId} (on-device local rule)',
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

  // --- Cloud AI Workflow Section ---

  Widget _buildCloudAiSection(ThemeData theme, BuildContext context) {
    return Obx(() {
      final aiState = controller.aiState.value;
      switch (aiState) {
        case AiAnalysisState.idle:
          return _buildAiIdleCard(theme, context);
        case AiAnalysisState.submitting:
          return _buildAiSubmittingCard(theme);
        case AiAnalysisState.failed:
          return _buildAiFailedCard(theme, context);
        case AiAnalysisState.completed:
          final report = controller.aiReport.value;
          if (report == null) return _buildAiIdleCard(theme, context);
          return _buildAiCompletedCard(theme, report, context);
      }
    });
  }

  Widget _buildAiIdleCard(ThemeData theme, BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.onTertiaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Optional Cloud AI analysis',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Secondary pattern evaluation via Groq Cloud',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Request an AI-assisted evaluation powered by high-speed Groq LPUs. Groq checks for subtle linguistic indicators, pretexting, and social engineering cues.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Requires explicit affirmative upload consent. Only your reviewed text is sent over TLS; original images and device data are never uploaded.',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppButton.primary(
            label: 'Ask Cloud AI',
            icon: Icons.auto_awesome,
            onPressed: () => controller.requestAiAnalysis(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSubmittingCard(ThemeData theme) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Semantics(
              label: 'Requesting cloud AI analysis from TrustCue backend',
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: 12),
            Text(
              'Analyzing with Cloud AI...',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Securely transmitting reviewed text to Groq Cloud LPUs.\nYour on-device local results above remain active.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiFailedCard(ThemeData theme, BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cloud AI analysis unavailable',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            controller.aiErrorMessage.value ??
                'Cloud AI analysis request could not be completed.',
            style: theme.textTheme.bodyMedium,
          ),
          if (controller.aiRetryAfter.value != null) ...[
            const SizedBox(height: 6),
            Text(
              'Retry after ${controller.aiRetryAfter.value} seconds.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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
                  Icons.check_circle_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your local on-device analysis above is complete and unaffected.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Dismiss',
                  onPressed: controller.invalidateConsent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.primary(
                  label: 'Retry AI review',
                  onPressed: () => controller.retryAiAnalysis(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiCompletedCard(
    ThemeData theme,
    AiAnalysisReport report,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Provenance & Header Banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingSmall),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.tertiary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '[AI-Assisted: Groq]',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${report.provider} • ${report.model}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Non-guarantee disclosure: AI assistance identifies potential patterns and explanations. It does not provide absolute fraud scores, guarantee safety, or verify sender legitimacy.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // AI Summary Card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI pattern summary',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(report.factualSummary, style: theme.textTheme.bodyMedium),
              if (report.uncertaintyNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Model uncertainty & limitations:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...report.uncertaintyNotes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
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
        ),
        const SizedBox(height: AppSpacing.pagePaddingSmall),

        // AI Findings / Evidence
        if (report.findings.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.find_in_page_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI-identified indicators (${report.findings.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...report.findings.map(
            (finding) => _buildFindingTile(theme, finding, context),
          ),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
        ] else ...[
          AppCard(
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: theme.hintColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No additional scam indicators were identified by cloud AI. (Not proof of safety).',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
        ],

        // AI Suggested Actions
        if (report.suggestedActions.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.checklist_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI-recommended verification steps',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...report.suggestedActions.map(
            (action) => _buildActionCard(theme, action),
          ),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
        ],
      ],
    );
  }

  Widget _buildNavigationActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Local Save Action
        _buildLocalSaveAction(theme),
        const SizedBox(height: 12),

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

  Widget _buildLocalSaveAction(ThemeData theme) {
    return Obx(() {
      final status = controller.saveStatus.value;

      switch (status) {
        case ReportSaveStatus.saved:
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved on this device',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Only reviewed text and findings are stored locally on your device.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

        case ReportSaveStatus.saving:
          return const AppButton.primary(
            label: 'Saving to device...',
            isLoading: true,
            onPressed: null,
          );

        case ReportSaveStatus.failed:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.error),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.saveErrorMessage.value ??
                            'Unable to save report locally.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AppButton.primary(
                label: 'Retry saving to device',
                icon: Icons.refresh,
                onPressed: controller.saveReportOnDevice,
              ),
            ],
          );

        case ReportSaveStatus.notSaved:
          return AppButton.primary(
            label: 'Save on this device',
            icon: Icons.save_alt_outlined,
            onPressed: controller.saveReportOnDevice,
          );
      }
    });
  }
}
