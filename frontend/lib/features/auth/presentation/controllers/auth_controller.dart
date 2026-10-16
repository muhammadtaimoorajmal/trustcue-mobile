import 'dart:async';

import 'package:get/get.dart';
import 'package:trustcue_mobile/features/auth/data/services/account_api_client.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/domain/models/user_profile.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';

/// Central application controller managing authentication status, user profile,
/// and permanent account deletion lifecycle.
class AuthController extends GetxController {
  AuthController({
    required this.authRepository,
    AccountApiClient? accountApiClient,
    this.reportRepository,
  }) : accountApiClient =
           accountApiClient ??
           AccountApiClient(
             tokenProvider: () => authRepository.getAccessToken(),
           );

  final AuthRepository authRepository;
  final AccountApiClient accountApiClient;
  final LocalReportRepository? reportRepository;

  StreamSubscription<AuthStatus>? _statusSubscription;

  final Rx<AuthStatus> status = AuthStatus.unauthenticated.obs;
  final Rxn<AuthUser> user = Rxn<AuthUser>();
  final RxBool isInitialized = false.obs;

  // Profile and deletion state
  final Rxn<UserProfile> profile = Rxn<UserProfile>();
  final RxBool isLoadingProfile = false.obs;
  final RxBool isUpdatingProfile = false.obs;
  final RxBool isDeletingAccount = false.obs;
  final RxnString profileError = RxnString();
  final RxnString deletionError = RxnString();

  bool get isAuthenticated => status.value == AuthStatus.authenticated;
  bool get isConfigured => authRepository.isConfigured;

  @override
  void onInit() {
    super.onInit();
    _initAuth();
  }

  Future<void> _initAuth() async {
    _statusSubscription = authRepository.statusStream.listen((newStatus) async {
      status.value = newStatus;
      user.value = authRepository.currentUser;
      if (newStatus == AuthStatus.authenticated) {
        await fetchProfile();
      } else {
        profile.value = null;
      }
    });

    await authRepository.initialize();
    status.value = authRepository.currentStatus;
    user.value = authRepository.currentUser;
    isInitialized.value = true;

    if (status.value == AuthStatus.authenticated) {
      await fetchProfile();
    }
  }

  /// Fetches the authenticated user profile metadata from backend.
  Future<void> fetchProfile() async {
    isLoadingProfile.value = true;
    profileError.value = null;

    final result = await accountApiClient.getProfile();
    if (result.isSuccess) {
      profile.value = result.valueOrNull;
    } else {
      profileError.value = result.failureOrNull?.message;
    }
    isLoadingProfile.value = false;
  }

  /// Updates the user's display name with client-side trimming and validation.
  Future<bool> updateDisplayName(String? newDisplayName) async {
    if (!isAuthenticated) return false;

    final trimmed = newDisplayName?.trim();
    if (trimmed != null && trimmed.length > 64) {
      profileError.value = 'Display name cannot exceed 64 characters.';
      return false;
    }

    isUpdatingProfile.value = true;
    profileError.value = null;

    final result = await accountApiClient.updateProfile(displayName: trimmed);
    isUpdatingProfile.value = false;

    if (result.isSuccess) {
      profile.value = result.valueOrNull;
      return true;
    } else {
      profileError.value = result.failureOrNull?.message;
      return false;
    }
  }

  /// Executes permanent account deletion.
  ///
  /// Flow:
  /// 1. Re-authenticates with provided [password] to ensure security.
  /// 2. Invokes administrative deletion on backend via `AccountApiClient.deleteAccount()`.
  /// 3. Purges all local reports scoped to this user account from device SQLite storage.
  /// 4. Signs out and returns to guest mode.
  Future<bool> deleteAccount({required String password}) async {
    final currentUser = user.value;
    if (currentUser == null || !isAuthenticated) {
      deletionError.value = 'No authenticated user session found.';
      return false;
    }

    isDeletingAccount.value = true;
    deletionError.value = null;

    // 1. Re-authentication verification
    final reauthResult = await authRepository.signInWithPassword(
      email: currentUser.email,
      password: password,
    );

    if (reauthResult.isFailure) {
      deletionError.value = 'Incorrect password. Account deletion canceled.';
      isDeletingAccount.value = false;
      return false;
    }

    // 2. Invoke backend account deletion
    final backendResult = await accountApiClient.deleteAccount();
    if (backendResult.isFailure) {
      deletionError.value =
          backendResult.failureOrNull?.message ??
          'Failed to delete server account.';
      isDeletingAccount.value = false;
      return false;
    }

    // 3. Purge local account-scoped reports from SQLite
    if (reportRepository != null) {
      try {
        await reportRepository!.deleteReportsForAccount(currentUser.id);
      } catch (_) {
        // Continue cleanup even if local report delete fails
      }
    }

    // 4. Terminate local session and clear tokens
    await signOut();
    profile.value = null;
    isDeletingAccount.value = false;
    return true;
  }

  /// Terminates the current session and clears local credentials.
  Future<void> signOut({bool global = false}) async {
    await authRepository.signOut(global: global);
    status.value = authRepository.currentStatus;
    user.value = null;
    profile.value = null;
  }

  @override
  void onClose() {
    _statusSubscription?.cancel();
    super.onClose();
  }
}
