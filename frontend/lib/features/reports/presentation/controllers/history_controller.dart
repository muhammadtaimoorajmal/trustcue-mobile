import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/reports/data/database/app_database.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';
import 'package:trustcue_mobile/features/reports/presentation/widgets/delete_confirmation_dialog.dart';

/// Presentation controller managing report history list, pagination, debounced search,
/// metadata filtering, account scoping, and transactional deletion.
///
/// Invariants & Guarantees:
/// - Scoped to authenticated user ID or guest (null) boundary.
/// - Debounced search queries (300ms) with stale-result protection.
/// - Confirmation-gated single report deletion immediately removing data from SQLite.
class HistoryController extends GetxController {
  final LocalReportRepository? repository;
  final AuthRepository? authRepository;

  static const int pageSize = 20;

  HistoryController({this.repository, this.authRepository});

  final TextEditingController searchController = TextEditingController();

  final RxList<SavedReportSummary> summaries = <SavedReportSummary>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final RxnString errorMessage = RxnString();
  final RxInt totalCount = 0.obs;

  // Filter states
  final RxString searchQuery = ''.obs;
  final Rxn<InputSource> selectedInputSource = Rxn<InputSource>();
  final Rxn<bool> selectedProvenance = Rxn<bool>();

  Timer? _debounceTimer;
  int _operationId = 0;

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
    loadInitial();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    searchController.dispose();
    super.onClose();
  }

  /// Initial load or filter change reset.
  Future<void> loadInitial() async {
    final operationId = ++_operationId;
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final accountId = currentAccountId;
      final query = searchQuery.value.trim();
      final source = selectedInputSource.value;
      final prov = selectedProvenance.value;

      final resultsFuture = query.isEmpty
          ? _repo.searchReportSummaries(
              query: '',
              accountId: accountId,
              inputSource: source,
              hasAiAnalysis: prov,
              limit: pageSize,
              offset: 0,
            )
          : _repo.searchReportSummaries(
              query: query,
              accountId: accountId,
              inputSource: source,
              hasAiAnalysis: prov,
              limit: pageSize,
              offset: 0,
            );

      final countFuture = _repo.getReportCount(
        accountId: accountId,
        query: query.isEmpty ? null : query,
        inputSource: source,
        hasAiAnalysis: prov,
      );

      final resultsResult = await resultsFuture;
      final countResult = await countFuture;

      if (isClosed || _operationId != operationId) return;

      if (resultsResult.isSuccess) {
        final items = resultsResult.valueOrNull ?? [];
        summaries.assignAll(items);
        totalCount.value = countResult.valueOrNull ?? items.length;
        hasMore.value = items.length < totalCount.value;
      } else {
        errorMessage.value =
            resultsResult.failureOrNull?.message ??
            'Failed to load saved reports.';
        summaries.clear();
        totalCount.value = 0;
        hasMore.value = false;
      }
    } catch (e) {
      if (isClosed || _operationId != operationId) return;
      errorMessage.value = 'Unexpected error loading reports: ${e.toString()}';
      summaries.clear();
      totalCount.value = 0;
      hasMore.value = false;
    } finally {
      if (!isClosed && _operationId == operationId) {
        isLoading.value = false;
      }
    }
  }

  /// Loads the next page of reports.
  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || isLoading.value) return;

    final operationId = _operationId;
    isLoadingMore.value = true;

    try {
      final accountId = currentAccountId;
      final query = searchQuery.value.trim();
      final source = selectedInputSource.value;
      final prov = selectedProvenance.value;
      final currentOffset = summaries.length;

      final result = await _repo.searchReportSummaries(
        query: query,
        accountId: accountId,
        inputSource: source,
        hasAiAnalysis: prov,
        limit: pageSize,
        offset: currentOffset,
      );

      if (isClosed || _operationId != operationId) return;

      if (result.isSuccess) {
        final newItems = result.valueOrNull ?? [];
        summaries.addAll(newItems);
        hasMore.value = summaries.length < totalCount.value;
      }
    } catch (_) {
      // Gracefully ignore load-more failure without dropping existing summaries
    } finally {
      if (!isClosed && _operationId == operationId) {
        isLoadingMore.value = false;
      }
    }
  }

  /// Handles search query changes with debouncing.
  void onSearchQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (isClosed) return;
      searchQuery.value = query;
      loadInitial();
    });
  }

  /// Clears search query text and reloads.
  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    _debounceTimer?.cancel();
    loadInitial();
  }

  /// Filters by input source.
  void setInputSourceFilter(InputSource? source) {
    if (selectedInputSource.value == source) return;
    selectedInputSource.value = source;
    loadInitial();
  }

  /// Filters by analysis provenance (null = all, false = local only, true = AI assisted).
  void setProvenanceFilter(bool? provenance) {
    if (selectedProvenance.value == provenance) return;
    selectedProvenance.value = provenance;
    loadInitial();
  }

  /// Prompts for confirmation and deletes the specified report.
  Future<void> deleteReportWithConfirmation(
    SavedReportSummary summary,
    BuildContext context,
  ) async {
    final syncActive = isSyncEnabled && summary.accountId != null;
    final choice = await DeleteConfirmationDialog.show(
      context,
      isSyncEnabled: syncActive,
    );
    if (choice == DeleteReportChoice.cancel) return;

    final shouldTombstone = choice == DeleteReportChoice.deviceAndCloud;
    final accountId = currentAccountId;
    final result = await _repo.deleteReport(
      summary.id,
      accountId: accountId,
      enforceAccountScope: true,
      tombstoneForCloud: shouldTombstone,
    );

    if (result.isSuccess && (result.valueOrNull ?? false)) {
      summaries.removeWhere((item) => item.id == summary.id);
      totalCount.value = (totalCount.value - 1).clamp(0, 999999);
      hasMore.value = summaries.length < totalCount.value;

      if (shouldTombstone && Get.isRegistered<AuthController>()) {
        unawaited(Get.find<AuthController>().syncNow());
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.failureOrNull?.message ??
                  'Failed to delete report from device.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Navigates to the report detail view.
  void openReportDetail(SavedReportSummary summary) {
    Get.toNamed(AppRoutes.historyDetail, arguments: summary.id);
  }
}
