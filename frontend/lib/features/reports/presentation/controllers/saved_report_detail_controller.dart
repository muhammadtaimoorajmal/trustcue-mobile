import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/presentation/widgets/analyzed_text_evidence_viewer.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/reports/data/database/app_database.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/presentation/widgets/delete_confirmation_dialog.dart';

/// Presentation controller for the detailed view of a single locally saved report.
///
/// Invariants & Guarantees:
/// - Reconstructs the exact historical findings, text snapshot, and uncertainty notes
///   without silently re-running the analysis engine.
/// - Scoped to the current account context (`accountId` vs guest `null`).
/// - Handles missing or corrupt records safely with recoverable UI states.
class SavedReportDetailController extends GetxController {
  final String? reportId;
  final LocalReportRepository? repository;
  final AuthRepository? authRepository;

  SavedReportDetailController({
    this.reportId,
    this.repository,
    this.authRepository,
  });

  final RxBool isLoading = true.obs;
  final Rxn<SavedReport> report = Rxn<SavedReport>();
  final RxnString errorMessage = RxnString();
  final RxBool showLimitations = false.obs;

  String get _effectiveReportId {
    if (reportId != null && reportId!.isNotEmpty) {
      return reportId!;
    }
    final raw = Get.arguments;
    if (raw is String) return raw;
    return '';
  }

  String? get currentAccountId {
    final auth =
        authRepository ??
        (Get.isRegistered<AuthRepository>()
            ? Get.find<AuthRepository>()
            : null);
    if (auth != null && auth.currentStatus == AuthStatus.authenticated) {
      return auth.currentUser?.id;
    }
    return null;
  }

  bool get isSyncEnabled {
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      return auth.isAuthenticated && (auth.profile.value?.syncEnabled ?? false);
    }
    return false;
  }

  LocalReportRepository get _repo {
    return repository ??
        (Get.isRegistered<LocalReportRepository>()
            ? Get.find<LocalReportRepository>()
            : AppDatabase.getInstance());
  }

  @override
  void onInit() {
    super.onInit();
    loadReport();
  }

  /// Loads the saved report by ID with account boundary scoping.
  Future<void> loadReport() async {
    final id = _effectiveReportId;
    if (id.isEmpty) {
      isLoading.value = false;
      errorMessage.value = 'Invalid report identifier.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;

    try {
      final accountId = currentAccountId;
      final result = await _repo.getReportById(
        id,
        accountId: accountId,
        enforceAccountScope: true,
      );

      if (result.isSuccess) {
        final loaded = result.valueOrNull;
        if (loaded == null) {
          errorMessage.value =
              'Report not found or not accessible on this device.';
        } else {
          report.value = loaded;
        }
      } else {
        errorMessage.value =
            result.failureOrNull?.message ?? 'Failed to load saved report.';
      }
    } catch (e) {
      errorMessage.value = 'Unexpected error loading report: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  /// Opens the interactive evidence viewer displaying exact highlights in analyzed text.
  void viewEvidenceInText(AnalysisFinding finding, BuildContext context) {
    final currentReport = report.value;
    if (currentReport == null) return;

    AnalyzedTextEvidenceViewer.show(
      context,
      analyzedText: currentReport.snapshot.text,
      finding: finding,
    );
  }

  /// Toggles visibility of historical limitations and uncertainty notes.
  void toggleLimitations() {
    showLimitations.value = !showLimitations.value;
  }

  /// Prompts for confirmation and deletes this report.
  Future<bool> deleteCurrentReport(BuildContext context) async {
    final currentReport = report.value;
    if (currentReport == null) return false;

    final syncActive = isSyncEnabled && currentReport.accountId != null;
    final choice = await DeleteConfirmationDialog.show(
      context,
      isSyncEnabled: syncActive,
    );
    if (choice == DeleteReportChoice.cancel) return false;

    final shouldTombstone = choice == DeleteReportChoice.deviceAndCloud;
    final accountId = currentAccountId;
    final result = await _repo.deleteReport(
      currentReport.id,
      accountId: accountId,
      enforceAccountScope: true,
      tombstoneForCloud: shouldTombstone,
    );

    if (result.isSuccess && (result.valueOrNull ?? false)) {
      if (shouldTombstone && Get.isRegistered<AuthController>()) {
        unawaited(Get.find<AuthController>().syncNow());
      }

      Get.back(result: true);
      final currentContext = Get.context;
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(
              shouldTombstone
                  ? 'Report deleted from device and cloud backup.'
                  : 'Report deleted from this device.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return true;
    } else {
      final currentContext = Get.context;
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(
              result.failureOrNull?.message ?? 'Failed to delete saved report.',
            ),
            backgroundColor: Theme.of(currentContext).colorScheme.error,
          ),
        );
      }
      return false;
    }
  }
}
