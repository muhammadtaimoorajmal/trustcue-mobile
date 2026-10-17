import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/privacy/presentation/controllers/privacy_controller.dart';
import 'package:trustcue_mobile/features/reports/domain/models/retention_policy.dart';

/// Screen presenting the Privacy Center, data boundaries, retention policies,
/// and granular deletion controls for Module 40.
class PrivacyScreen extends GetView<PrivacyController> {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data status',
            onPressed: controller.loadStatus,
          ),
        ],
      ),
      body: AppPageBody(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(theme),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              _buildDataBoundariesCard(context, theme),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              _buildRetentionCard(context, theme),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              _buildLocalDataClearingCard(context, theme),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              _buildFeedbackCard(context, theme),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              _buildCloudAndAccountCard(context, theme),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              _buildGuidanceCard(context, theme),
              const SizedBox(height: AppSpacing.pagePaddingLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Privacy & Data Transparency',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'TrustCue operates with strict privacy boundaries. Understand where your data resides, what is shared, and how to permanently delete it.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataBoundariesCard(BuildContext context, ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Storage & Processing Boundaries',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildBoundaryItem(
            theme,
            icon: Icons.smartphone_outlined,
            title: 'What remains on this device',
            body:
                'Analyzed messages, screenshots, OCR extractions, and saved reports are stored exclusively in the app-private SQLite database on your device. '
                'Isolated by Android sandbox permissions (process UID) with OS cloud backup disabled (allowBackup="false"). '
                'Note: storage is app-private, not transparent hardware encryption.',
          ),
          const Divider(height: 24),
          _buildBoundaryItem(
            theme,
            icon: Icons.psychology_outlined,
            title: 'What is sent for AI analysis',
            body:
                'Remote AI analysis is strictly optional and requires your explicit, affirmative consent per request. '
                'Only the single reviewed text snapshot you approve is sent. '
                'Processed ephemerally by self-hosted backend and AI provider (Groq) with zero model training and no customer data retention.',
          ),
          const Divider(height: 24),
          _buildBoundaryItem(
            theme,
            icon: Icons.cloud_done_outlined,
            title: 'What optional cloud backup stores',
            body:
                'Cloud report synchronization is disabled by default. If you explicitly enable it, only high-level metadata summaries are saved '
                '(outcomeState, categories, timestamps, indicator counts). '
                'Raw message text, OCR transcripts, evidence quotes, screenshots, and message hashes are NEVER uploaded to or stored in the cloud.',
          ),
          const Divider(height: 24),
          _buildBoundaryItem(
            theme,
            icon: Icons.compare_arrows_outlined,
            title: 'Deletion semantics',
            body:
                '• Local Deletion: Permanently deletes report(s) and unreferenced snapshots from this phone.\n'
                '• Cloud Purge: Permanently wipes all metadata summaries from the cloud server.\n'
                '• Account Deletion: Purges server account, quotas, cloud backups, and cascades to clear local account reports.',
          ),
        ],
      ),
    );
  }

  Widget _buildBoundaryItem(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
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

  Widget _buildRetentionCard(BuildContext context, ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_delete_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Local Report Retention',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Configure automatic local storage cleanup. Reports older than the selected retention period will be pruned from this device on app startup.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final activePolicy = controller.currentPolicy.value;
            return DropdownButtonFormField<RetentionPolicy>(
              key: ValueKey(activePolicy),
              initialValue: activePolicy,
              decoration: const InputDecoration(
                labelText: 'Retention Policy',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: RetentionPolicy.values.map((policy) {
                return DropdownMenuItem<RetentionPolicy>(
                  value: policy,
                  child: Text(policy.label),
                );
              }).toList(),
              onChanged: (policy) {
                if (policy != null) {
                  controller.setRetentionPolicy(policy);
                }
              },
            );
          }),
          const SizedBox(height: 16),
          Obx(() {
            return AppButton.secondary(
              label: 'Prune Expired Reports Now',
              icon: Icons.cleaning_services_outlined,
              isLoading: controller.isLoading.value,
              onPressed: () => controller.pruneExpiredReportsNow(context),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLocalDataClearingCard(BuildContext context, ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_sweep_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Clear Local Data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Permanently remove cached images or local reports within a clearly stated scope. These actions do not delete your account or cloud backups.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          AppButton.secondary(
            label: 'Clear Temporary Image Cache',
            icon: Icons.image_not_supported_outlined,
            onPressed: controller.clearTemporaryFiles,
          ),
          const SizedBox(height: 12),
          Obx(() {
            final aCount = controller.accountReportCount.value;
            final gCount = controller.guestReportCount.value;
            final isAuth = controller.isAuthenticated;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isAuth)
                  AppButton.secondary(
                    label: 'Clear Account Reports ($aCount)',
                    icon: Icons.delete_outline,
                    onPressed: aCount == 0
                        ? null
                        : () => controller.clearAccountReports(context),
                  )
                else
                  AppButton.secondary(
                    label: 'Clear Guest Reports ($gCount)',
                    icon: Icons.delete_outline,
                    onPressed: gCount == 0
                        ? null
                        : () => controller.clearGuestReports(context),
                  ),
                if (isAuth && gCount > 0) ...[
                  const SizedBox(height: 12),
                  AppButton.secondary(
                    label: 'Clear Remaining Guest Reports ($gCount)',
                    icon: Icons.delete_outline,
                    onPressed: () => controller.clearGuestReports(context),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCloudAndAccountCard(BuildContext context, ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cloud Backup & Account Lifecycle',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Manage cloud summary backups and account deletion. Cloud backup is optional and only stores non-sensitive metadata summaries.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            controller.isLoading.value;
            final isSync = controller.isSyncEnabled;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSync
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isSync ? Icons.sync : Icons.sync_disabled,
                    size: 20,
                    color: isSync
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSync
                          ? 'Cloud Sync: Active (Summary backup)'
                          : 'Cloud Sync: Disabled (Local only)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          AppButton.secondary(
            label: 'Manage Cloud Sync Settings',
            icon: Icons.settings_backup_restore,
            onPressed: () => Get.toNamed(AppRoutes.account),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final isAuth = controller.isAuthenticated;
            final isLoading = controller.isLoading.value;
            if (!isAuth) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton.secondary(
                  label: 'Stop Sync & Delete Cloud Summaries',
                  icon: Icons.cloud_off,
                  isLoading: isLoading,
                  onPressed: () => controller.purgeCloudSummaries(context),
                ),
                const SizedBox(height: 12),
              ],
            );
          }),
          AppButton.secondary(
            label: 'Permanent Account Deletion',
            icon: Icons.person_remove_outlined,
            onPressed: () => Get.toNamed(AppRoutes.account),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(BuildContext context, ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Educational Guidance & Disclosures',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Review our safe-use instructions and understand how scam indicators are identified and explained.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          AppButton.secondary(
            label: 'Review Safe-Use Guidance',
            icon: Icons.verified_user_outlined,
            onPressed: () => Get.toNamed(AppRoutes.guidance),
          ),
          const SizedBox(height: 12),
          AppButton.secondary(
            label: 'Explore Scam Education Center',
            icon: Icons.school_outlined,
            onPressed: () => Get.toNamed(AppRoutes.education),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context, ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rate_review_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Local Anonymous Feedback',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Usefulness ratings and comments submitted for educational topics or findings are stored strictly on this device without any personal data or transmission.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final count = controller.feedbackCount.value;
            return Text(
              '$count feedback records stored on this device',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            );
          }),
          const SizedBox(height: 12),
          AppButton.secondary(
            label: 'Clear Local Feedback',
            icon: Icons.delete_outline,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Clear Local Feedback'),
                  content: const Text(
                    'Are you sure you want to delete all locally stored feedback records from this device? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    AppButton.primary(
                      label: 'Clear All',
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await controller.clearLocalFeedback();
              }
            },
          ),
        ],
      ),
    );
  }
}
