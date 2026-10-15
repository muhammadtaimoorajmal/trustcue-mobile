import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/reports/presentation/controllers/history_controller.dart';
import 'package:trustcue_mobile/features/reports/presentation/widgets/history_filter_bar.dart';
import 'package:trustcue_mobile/features/reports/presentation/widgets/history_report_card.dart';

/// Screen displaying the list of locally saved analysis reports with search,
/// metadata filters, pagination, and deletion capabilities.
class HistoryScreen extends GetView<HistoryController> {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh reports',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: controller.loadInitial,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingSmall,
                vertical: AppSpacing.pagePaddingSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Privacy Banner
                  _buildPrivacyBanner(theme),
                  const SizedBox(height: AppSpacing.pagePaddingSmall),

                  // 2. Search & Filter Bar
                  Obx(
                    () => HistoryFilterBar(
                      searchController: controller.searchController,
                      onSearchChanged: controller.onSearchQueryChanged,
                      onClearSearch: controller.clearSearch,
                      selectedSource: controller.selectedInputSource.value,
                      onSourceChanged: controller.setInputSourceFilter,
                      selectedProvenance: controller.selectedProvenance.value,
                      onProvenanceChanged: controller.setProvenanceFilter,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.pagePaddingSmall),

                  // 3. Results Header with Count
                  Obx(() {
                    if (controller.isLoading.value) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${controller.totalCount.value} saved report(s)',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (controller.searchQuery.isNotEmpty ||
                              controller.selectedInputSource.value != null ||
                              controller.selectedProvenance.value != null)
                            TextButton.icon(
                              onPressed: () {
                                controller.selectedInputSource.value = null;
                                controller.selectedProvenance.value = null;
                                controller.clearSearch();
                              },
                              icon: const Icon(Icons.filter_alt_off, size: 16),
                              label: const Text('Clear filters'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),

                  // 4. Content Area
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: controller.loadInitial,
                      child: Obx(() {
                        if (controller.isLoading.value) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (controller.errorMessage.value != null) {
                          return _buildErrorState(theme);
                        }

                        if (controller.summaries.isEmpty) {
                          return _buildEmptyState(theme);
                        }

                        return _buildReportList(theme, context);
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyBanner(ThemeData theme) {
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
          Icon(Icons.lock_outline, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'On-device storage',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saved reports stay on this device. Searching and browsing evaluate locally without network calls.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
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
              'Could not load saved reports',
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
              onPressed: controller.loadInitial,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final hasFilter =
        controller.searchQuery.isNotEmpty ||
        controller.selectedInputSource.value != null ||
        controller.selectedProvenance.value != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter ? Icons.search_off_outlined : Icons.history_outlined,
              size: 56,
              color: theme.hintColor,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'No matching reports found' : 'No saved reports yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try adjusting your search keywords or clear your active filters.'
                  : 'Reports saved after running an analysis check will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (hasFilter)
              AppButton.secondary(
                label: 'Clear search filters',
                icon: Icons.clear,
                onPressed: () {
                  controller.selectedInputSource.value = null;
                  controller.selectedProvenance.value = null;
                  controller.clearSearch();
                },
              )
            else
              AppButton.primary(
                label: 'Start new check',
                icon: Icons.add,
                onPressed: () {
                  Get.offNamed(AppRoutes.home);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList(ThemeData theme, BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount:
          controller.summaries.length + (controller.hasMore.value ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == controller.summaries.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: controller.isLoadingMore.value
                  ? const CircularProgressIndicator()
                  : AppButton.secondary(
                      label: 'Load more reports',
                      onPressed: controller.loadMore,
                    ),
            ),
          );
        }

        final summary = controller.summaries[index];
        return HistoryReportCard(
          summary: summary,
          onTap: () => controller.openReportDetail(summary),
          onDelete: () =>
              controller.deleteReportWithConfirmation(summary, context),
        );
      },
    );
  }
}
