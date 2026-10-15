import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:trustcue_mobile/features/auth/data/services/auth_config.dart';
import 'package:trustcue_mobile/features/auth/data/services/secure_local_storage.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';

/// Production implementation of [AuthRepository] backed by Supabase Auth and [FlutterSecureStorage].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({AuthConfig? config, this._client})
    : _config = config ?? AuthConfig.fromEnvironment();

  final AuthConfig _config;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _authSubscription;

  final StreamController<AuthStatus> _statusController =
      StreamController<AuthStatus>.broadcast();

  AuthStatus _currentStatus = AuthStatus.unauthenticated;
  AuthUser? _currentUser;
  bool _isInitialized = false;

  @override
  Stream<AuthStatus> get statusStream => _statusController.stream;

  @override
  AuthStatus get currentStatus => _currentStatus;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  bool get isConfigured => _config.isConfigured;

  SupabaseClient get _activeClient {
    if (_client != null) return _client!;
    return Supabase.instance.client;
  }

  @override
  Future<AuthResult<void>> initialize() async {
    if (_isInitialized) return const AuthResult.success(null);

    if (!_config.isConfigured) {
      _updateStatus(AuthStatus.unconfigured);
      _isInitialized = true;
      return const AuthResult.success(null);
    }

    try {
      if (_client == null) {
        // Initialize Supabase Flutter SDK singleton if not already initialized
        try {
          _client = Supabase.instance.client;
        } catch (_) {
          await Supabase.initialize(
            url: _config.supabaseUrl!,
            publishableKey: _config.supabaseAnonKey!,
            authOptions: FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
              localStorage: SecureLocalStorage(),
            ),
          );
          _client = Supabase.instance.client;
        }
      }

      // Check current session from secure storage
      final session = _activeClient.auth.currentSession;
      if (session != null && !session.isExpired) {
        _currentUser = _mapUser(session.user);
        _updateStatus(AuthStatus.authenticated);
      } else {
        _currentUser = null;
        _updateStatus(AuthStatus.unauthenticated);
      }

      // Listen to auth state transitions
      _authSubscription = _activeClient.auth.onAuthStateChange.listen(
        _handleAuthStateChange,
        onError: (Object error) {
          // Log or handle error without crashing or looping
        },
      );

      _isInitialized = true;
      return const AuthResult.success(null);
    } on SocketException {
      _updateStatus(AuthStatus.unauthenticated);
      _isInitialized = true;
      return AuthResult.failure(AuthFailure.networkError());
    } catch (e) {
      _updateStatus(AuthStatus.unauthenticated);
      _isInitialized = true;
      return AuthResult.failure(AuthFailure.unknown());
    }
  }

  void _handleAuthStateChange(AuthState state) {
    final event = state.event;
    final session = state.session;

    switch (event) {
      case AuthChangeEvent.signedIn:
        if (session != null) {
          _currentUser = _mapUser(session.user);
          _updateStatus(AuthStatus.authenticated);
        }
        break;
      case AuthChangeEvent.signedOut:
        _currentUser = null;
        _updateStatus(AuthStatus.unauthenticated);
        break;
      case AuthChangeEvent.passwordRecovery:
        _updateStatus(AuthStatus.recoverySession);
        break;
      case AuthChangeEvent.tokenRefreshed:
        if (session != null) {
          _currentUser = _mapUser(session.user);
          _updateStatus(AuthStatus.authenticated);
        }
        break;
      case AuthChangeEvent.userUpdated:
        if (session != null) {
          _currentUser = _mapUser(session.user);
        }
        break;
      default:
        break;
    }
  }

  void _updateStatus(AuthStatus newStatus) {
    _currentStatus = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  AuthUser _mapUser(User user) {
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      emailVerified: user.emailConfirmedAt != null,
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }

  @override
  Future<AuthResult<AuthUser>> signUp({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) return AuthResult.failure(AuthFailure.unconfigured());

    try {
      final response = await _activeClient.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: _config.redirectUrl,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult.failure(
          AuthFailure.unknown('Failed to create account.'),
        );
      }

      final mappedUser = _mapUser(user);

      // If email verification is required and email is not yet confirmed
      if (user.emailConfirmedAt == null) {
        _updateStatus(AuthStatus.verificationPending);
      } else {
        _currentUser = mappedUser;
        _updateStatus(AuthStatus.authenticated);
      }

      return AuthResult.success(mappedUser);
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return AuthResult.failure(AuthFailure.networkError());
    } catch (_) {
      return AuthResult.failure(AuthFailure.unknown());
    }
  }

  @override
  Future<AuthResult<AuthUser>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) return AuthResult.failure(AuthFailure.unconfigured());

    try {
      final response = await _activeClient.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult.failure(AuthFailure.invalidCredentials());
      }

      final mappedUser = _mapUser(user);
      _currentUser = mappedUser;
      _updateStatus(AuthStatus.authenticated);
      return AuthResult.success(mappedUser);
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return AuthResult.failure(AuthFailure.networkError());
    } catch (_) {
      return AuthResult.failure(AuthFailure.unknown());
    }
  }

  @override
  Future<AuthResult<void>> sendPasswordResetEmail({
    required String email,
  }) async {
    if (!isConfigured) return AuthResult.failure(AuthFailure.unconfigured());

    try {
      await _activeClient.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: _config.redirectUrl,
      );
      // Always succeed to prevent user enumeration
      return const AuthResult.success(null);
    } on AuthException catch (e) {
      // If rate limited, surface rate limit
      if (e.message.toLowerCase().contains('rate limit')) {
        return AuthResult.failure(AuthFailure.rateLimitExceeded());
      }
      // Otherwise generic success to avoid enumeration
      return const AuthResult.success(null);
    } on SocketException {
      return AuthResult.failure(AuthFailure.networkError());
    } catch (_) {
      return const AuthResult.success(null);
    }
  }

  @override
  Future<AuthResult<void>> updatePassword({required String newPassword}) async {
    if (!isConfigured) return AuthResult.failure(AuthFailure.unconfigured());

    try {
      await _activeClient.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _updateStatus(AuthStatus.authenticated);
      return const AuthResult.success(null);
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return AuthResult.failure(AuthFailure.networkError());
    } catch (_) {
      return AuthResult.failure(AuthFailure.unknown());
    }
  }

  @override
  Future<AuthResult<void>> resendVerificationEmail({
    required String email,
  }) async {
    if (!isConfigured) return AuthResult.failure(AuthFailure.unconfigured());

    try {
      await _activeClient.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: _config.redirectUrl,
      );
      return const AuthResult.success(null);
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('rate limit') ||
          e.message.toLowerCase().contains('too many')) {
        return AuthResult.failure(AuthFailure.rateLimitExceeded());
      }
      return AuthResult.failure(_mapAuthException(e));
    } on SocketException {
      return AuthResult.failure(AuthFailure.networkError());
    } catch (_) {
      return AuthResult.failure(AuthFailure.unknown());
    }
  }

  @override
  Future<AuthResult<void>> signOut({bool global = false}) async {
    if (!isConfigured) {
      _currentUser = null;
      _updateStatus(AuthStatus.unauthenticated);
      return const AuthResult.success(null);
    }

    try {
      await _activeClient.auth.signOut(
        scope: global ? SignOutScope.global : SignOutScope.local,
      );
      _currentUser = null;
      _updateStatus(AuthStatus.unauthenticated);
      return const AuthResult.success(null);
    } on SocketException {
      // Best-effort offline logout: local state cleared
      _currentUser = null;
      _updateStatus(AuthStatus.unauthenticated);
      return const AuthResult.failure(
        AuthFailure(
          code: AuthFailureCode.networkError,
          message: 'Signed out locally. Server-side session revocation could not be confirmed offline.',
        ),
      );
    } catch (_) {
      _currentUser = null;
      _updateStatus(AuthStatus.unauthenticated);
      return const AuthResult.success(null);
    }
  }

  @override
  Future<AuthResult<void>> handleAuthCallback(Uri uri) async {
    if (!isConfigured) return AuthResult.failure(AuthFailure.unconfigured());

    try {
      await _activeClient.auth.getSessionFromUrl(uri);
      return const AuthResult.success(null);
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthException(e));
    } catch (_) {
      return AuthResult.failure(AuthFailure.invalidCallback());
    }
  }

  AuthFailure _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_grant') ||
        msg.contains('invalid credentials')) {
      return AuthFailure.invalidCredentials();
    }
    if (msg.contains('email not confirmed')) {
      return AuthFailure.emailNotConfirmed();
    }
    if (msg.contains('already registered') || msg.contains('already in use')) {
      return const AuthFailure(
        code: AuthFailureCode.userAlreadyExists,
        message: 'An account already exists for this email address. Please sign in instead.',
      );
    }
    if (msg.contains('at least 6 characters') ||
        msg.contains('weak password')) {
      return AuthFailure.weakPassword();
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return AuthFailure.rateLimitExceeded();
    }
    return AuthFailure.unknown(e.message);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _statusController.close();
  }
}
