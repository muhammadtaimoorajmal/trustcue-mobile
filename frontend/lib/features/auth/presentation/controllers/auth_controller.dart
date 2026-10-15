import 'dart:async';

import 'package:get/get.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';

/// Central application controller managing authentication status and current user identity.
class AuthController extends GetxController {
  AuthController({required this.authRepository});

  final AuthRepository authRepository;
  StreamSubscription<AuthStatus>? _statusSubscription;

  final Rx<AuthStatus> status = AuthStatus.unauthenticated.obs;
  final Rxn<AuthUser> user = Rxn<AuthUser>();
  final RxBool isInitialized = false.obs;

  bool get isAuthenticated => status.value == AuthStatus.authenticated;
  bool get isConfigured => authRepository.isConfigured;

  @override
  void onInit() {
    super.onInit();
    _initAuth();
  }

  Future<void> _initAuth() async {
    _statusSubscription = authRepository.statusStream.listen((newStatus) {
      status.value = newStatus;
      user.value = authRepository.currentUser;
    });

    await authRepository.initialize();
    status.value = authRepository.currentStatus;
    user.value = authRepository.currentUser;
    isInitialized.value = true;
  }

  /// Terminates the current session and clears local credentials.
  Future<void> signOut({bool global = false}) async {
    await authRepository.signOut(global: global);
    status.value = authRepository.currentStatus;
    user.value = null;
  }

  @override
  void onClose() {
    _statusSubscription?.cancel();
    super.onClose();
  }
}
