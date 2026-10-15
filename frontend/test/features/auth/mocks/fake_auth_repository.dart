import 'dart:async';

import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    AuthStatus initialStatus = AuthStatus.unauthenticated,
    AuthUser? initialUser,
    this.isConfigured = true,
  }) : _currentStatus = initialStatus,
       _currentUser = initialUser;

  final StreamController<AuthStatus> _statusController =
      StreamController<AuthStatus>.broadcast();

  AuthStatus _currentStatus;
  AuthUser? _currentUser;

  @override
  bool isConfigured;

  AuthResult<AuthUser>? nextSignUpResult;
  AuthResult<AuthUser>? nextSignInResult;
  AuthResult<void>? nextSendPasswordResetResult;
  AuthResult<void>? nextUpdatePasswordResult;
  AuthResult<void>? nextResendVerificationResult;
  AuthResult<void>? nextSignOutResult;
  AuthResult<void>? nextCallbackResult;

  int signUpCallCount = 0;
  int signInCallCount = 0;
  int sendPasswordResetCallCount = 0;
  int updatePasswordCallCount = 0;
  int resendVerificationCallCount = 0;
  int signOutCallCount = 0;
  int handleCallbackCallCount = 0;

  String? lastSignUpEmail;
  String? lastSignInEmail;
  String? lastPasswordResetEmail;
  String? lastUpdatedPassword;
  String? lastResendEmail;

  @override
  Stream<AuthStatus> get statusStream => _statusController.stream;

  @override
  AuthStatus get currentStatus => _currentStatus;

  @override
  AuthUser? get currentUser => _currentUser;

  void setStatus(AuthStatus status, {AuthUser? user}) {
    _currentStatus = status;
    _currentUser = user;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  @override
  Future<AuthResult<void>> initialize() async {
    if (!isConfigured) {
      setStatus(AuthStatus.unconfigured);
    }
    return const AuthResult.success(null);
  }

  @override
  Future<AuthResult<AuthUser>> signUp({
    required String email,
    required String password,
  }) async {
    signUpCallCount++;
    lastSignUpEmail = email;

    if (nextSignUpResult != null) {
      final res = nextSignUpResult!;
      res.when(
        success: (user) {
          if (!user.emailVerified) {
            setStatus(AuthStatus.verificationPending);
          } else {
            setStatus(AuthStatus.authenticated, user: user);
          }
        },
        failure: (_) {},
      );
      return res;
    }

    final user = AuthUser(
      id: '00000000-0000-0000-0000-000000000001',
      email: email,
      emailVerified: false,
      createdAt: DateTime.now(),
    );
    setStatus(AuthStatus.verificationPending);
    return AuthResult.success(user);
  }

  @override
  Future<AuthResult<AuthUser>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCallCount++;
    lastSignInEmail = email;

    if (nextSignInResult != null) {
      final res = nextSignInResult!;
      res.when(
        success: (user) => setStatus(AuthStatus.authenticated, user: user),
        failure: (_) {},
      );
      return res;
    }

    final user = AuthUser(
      id: '00000000-0000-0000-0000-000000000001',
      email: email,
      emailVerified: true,
      createdAt: DateTime.now(),
    );
    setStatus(AuthStatus.authenticated, user: user);
    return AuthResult.success(user);
  }

  @override
  Future<AuthResult<void>> sendPasswordResetEmail({
    required String email,
  }) async {
    sendPasswordResetCallCount++;
    lastPasswordResetEmail = email;
    if (nextSendPasswordResetResult != null) {
      return nextSendPasswordResetResult!;
    }
    return const AuthResult.success(null);
  }

  @override
  Future<AuthResult<void>> updatePassword({required String newPassword}) async {
    updatePasswordCallCount++;
    lastUpdatedPassword = newPassword;
    if (nextUpdatePasswordResult != null) {
      return nextUpdatePasswordResult!;
    }
    setStatus(AuthStatus.authenticated);
    return const AuthResult.success(null);
  }

  @override
  Future<AuthResult<void>> resendVerificationEmail({
    required String email,
  }) async {
    resendVerificationCallCount++;
    lastResendEmail = email;
    if (nextResendVerificationResult != null) {
      return nextResendVerificationResult!;
    }
    return const AuthResult.success(null);
  }

  @override
  Future<AuthResult<void>> signOut({bool global = false}) async {
    signOutCallCount++;
    if (nextSignOutResult != null) {
      return nextSignOutResult!;
    }
    setStatus(AuthStatus.unauthenticated, user: null);
    return const AuthResult.success(null);
  }

  @override
  Future<AuthResult<void>> handleAuthCallback(Uri uri) async {
    handleCallbackCallCount++;
    if (nextCallbackResult != null) {
      return nextCallbackResult!;
    }
    return const AuthResult.success(null);
  }

  @override
  void dispose() {
    _statusController.close();
  }
}
