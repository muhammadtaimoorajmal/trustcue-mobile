import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/input/data/services/default_screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/privacy/presentation/widgets/scope_clear_confirmation_dialog.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_service.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/retention_policy.dart';

/// Controller coordinating privacy controls, retention policies, and data scoping.
class PrivacyController extends GetxController {
  final LocalReportRepository repository;
  final RetentionService retentionService;
  final DefaultScreenshotStorageService _screenshotStorageService;

  PrivacyController({
    required this.repository,
    required this.retentionService,
    DefaultScreenshotStorageService? screenshotStorageService,
  }) : _screenshotStorageService =
           screenshotStorageService ?? DefaultScreenshotStorageService();

  final Rx<RetentionPolicy> currentPolicy = RetentionPolicy.never.obs;
  final RxBool isLoading = false.obs;
  final RxInt accountReportCount = 0.obs;
  final RxInt guestReportCount = 0.obs;
  final RxString statusMessage = ''.obs;

  AuthController? get _authController =>
      Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;

  bool get isAuthenticated => _authController?.isAuthenticated ?? false;

  String? get currentAccountId => _authController?.user.value?.id;

  bool get isSyncEnabled =>
      _authController?.profile.value?.syncEnabled ?? false;

  @override
  void onInit() {
    super.onInit();
    loadStatus();
  }

  /// Reloads active retention policy and local report counts by scope.
  Future<void> loadStatus() async {
    isLoading.value = true;
    try {
      currentPolicy.value = await retentionService.getPolicy();

      if (isAuthenticated && currentAccountId != null) {
        final accCountRes = await repository.getReportCount(
          accountId: currentAccountId,
        );
        accountReportCount.value = accCountRes.valueOrNull ?? 0;
      } else {
        accountReportCount.value = 0;
      }

      final guestCountRes = await repository.getReportCount(accountId: null);
      guestReportCount.value = guestCountRes.valueOrNull ?? 0;
    } finally {
      isLoading.value = false;
    }
  }

  /// Updates local report retention policy.
  Future<void> setRetentionPolicy(RetentionPolicy policy) async {
    await retentionService.setPolicy(policy);
    currentPolicy.value = policy;
  }

  /// Performs immediate retention sweep of reports exceeding the current retention cutoff.
  Future<void> pruneExpiredReportsNow(BuildContext context) async {
    if (currentPolicy.value == RetentionPolicy.never) {
      Get.snackbar(
        'Retention Indefinite',
        'Current policy is set to keep reports indefinitely. Select an expiration period to prune old reports.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final confirmed = await ScopeClearConfirmationDialog.show(
      context,
      title: 'Prune Expired Reports',
      description:
          'Permanently remove local reports older than ${currentPolicy.value.label} from this device?',
      willDelete: [
        'Local reports and unreferenced snapshots older than ${currentPolicy.value.label}',
      ],
      willNotDelete: [
        'Reports newer than the retention period',
        'Cloud summaries (if sync is enabled)',
        'Account profile and preferences',
      ],
      confirmLabel: 'Prune expired reports',
    );

    if (!confirmed) return;

    isLoading.value = true;
    try {
      final pruneRes = await retentionService.pruneExpiredReports(
        currentAccountId: currentAccountId,
        includeGuest: true,
      );
      final count = pruneRes.valueOrNull ?? 0;
      await loadStatus();
      Get.snackbar(
        'Retention Pruning Complete',
        count == 0
            ? 'No reports were older than ${currentPolicy.value.label}.'
            : 'Pruned $count expired report(s) from this device.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Cleans up cached temporary screenshots and image buffers.
  Future<void> clearTemporaryFiles() async {
    isLoading.value = true;
    try {
      final clearedCount = await _screenshotStorageService.cleanupOrphanFiles();
      Get.snackbar(
        'Temporary Cache Cleared',
        clearedCount == 0
            ? 'No temporary files were found in cache.'
            : 'Cleared $clearedCount cached temporary image file(s).',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Clears all local reports owned by the currently authenticated account.
  Future<void> clearAccountReports(BuildContext context) async {
    final accountId = currentAccountId;
    if (accountId == null) return;

    final confirmed = await ScopeClearConfirmationDialog.show(
      context,
      title: 'Clear Account Reports',
      description:
          'Delete all local reports saved for this account on this device?',
      willDelete: [
        'All local reports and reviewed text snapshots owned by this account',
        'Local SQLite search records for this account',
      ],
      willNotDelete: [
        'Guest reports stored on this device',
        'Reports saved by other accounts on this device',
        'Cloud backup summaries',
        'Account login session and credentials',
      ],
      confirmLabel: 'Delete account reports',
    );

    if (!confirmed) return;

    isLoading.value = true;
    try {
      final res = await repository.deleteReportsForAccount(accountId);
      final count = res.valueOrNull ?? 0;
      await loadStatus();
      Get.snackbar(
        'Account Reports Deleted',
        'Deleted $count report(s) for this account from device storage.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Clears all unauthenticated guest reports on this device.
  Future<void> clearGuestReports(BuildContext context) async {
    final confirmed = await ScopeClearConfirmationDialog.show(
      context,
      title: 'Clear Guest Reports',
      description:
          'Delete all unauthenticated guest reports saved on this device?',
      willDelete: [
        'All local guest reports and associated unreferenced snapshots',
      ],
      willNotDelete: [
        'Reports owned by authenticated accounts',
        'Onboarding acknowledgment and preferences',
      ],
      confirmLabel: 'Delete guest reports',
    );

    if (!confirmed) return;

    isLoading.value = true;
    try {
      final res = await repository.deleteGuestReports();
      final count = res.valueOrNull ?? 0;
      await loadStatus();
      Get.snackbar(
        'Guest Reports Deleted',
        'Deleted $count guest report(s) from device storage.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Purges all cloud summaries for the current user and disables sync.
  Future<void> purgeCloudSummaries(BuildContext context) async {
    final auth = _authController;
    if (auth == null || !isAuthenticated) {
      Get.snackbar(
        'Account Required',
        'Sign in to manage cloud backups.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final confirmed = await ScopeClearConfirmationDialog.show(
      context,
      title: 'Delete Cloud Summaries',
      description: 'Stop synchronization and permanently purge all report summaries stored in your cloud account?',
      willDelete: [
        'All cloud-stored metadata summaries for your account',
        'Cloud tombstone markers',
      ],
      willNotDelete: [
        'Local reports stored on this device',
        'Account login profile and daily AI quota',
      ],
      confirmLabel: 'Stop sync & purge cloud summaries',
    );

    if (!confirmed) return;

    isLoading.value = true;
    try {
      await auth.purgeCloudBackups();
      await loadStatus();
    } finally {
      isLoading.value = false;
    }
  }
}
