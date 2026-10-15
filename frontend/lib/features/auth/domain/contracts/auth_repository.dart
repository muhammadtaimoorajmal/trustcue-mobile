import 'package:trustcue_mobile/features/auth/domain/models/auth_result.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';

/// Contract defining authentication operations and session lifecycle management.
abstract class AuthRepository {
  /// Stream emitting status transitions (`unauthenticated`, `authenticated`, `verificationPending`, `recoverySession`, `unconfigured`).
  Stream<AuthStatus> get statusStream;

  /// Current authentication status snapshot.
  AuthStatus get currentStatus;

  /// Currently authenticated user, or null if unauthenticated.
  AuthUser? get currentUser;

  /// Whether cloud authentication credentials are fully configured.
  bool get isConfigured;

  /// Initializes the authentication subsystem and restores any persisted session.
  Future<AuthResult<void>> initialize();

  /// Registers a new user account with email and password.
  ///
  /// If email confirmation is required by provider settings, returns the registered user
  /// with `emailVerified = false` and sets status to `verificationPending`.
  Future<AuthResult<AuthUser>> signUp({
    required String email,
    required String password,
  });

  /// Authenticates an existing user account with email and password.
  Future<AuthResult<AuthUser>> signInWithPassword({
    required String email,
    required String password,
  });

  /// Initiates password recovery for the given email address.
  ///
  /// Returns success generically regardless of whether account exists, preventing account enumeration.
  Future<AuthResult<void>> sendPasswordResetEmail({required String email});

  /// Updates the password for the current session (typically in a password recovery state).
  Future<AuthResult<void>> updatePassword({required String newPassword});

  /// Requests a fresh verification email for an unconfirmed account.
  Future<AuthResult<void>> resendVerificationEmail({required String email});

  /// Terminates the local session and clears encrypted credentials.
  ///
  /// If [global] is true, requests provider-side revocation across all active devices.
  Future<AuthResult<void>> signOut({bool global = false});

  /// Processes an incoming deep link or OAuth/PKCE callback URI.
  Future<AuthResult<void>> handleAuthCallback(Uri uri);

  /// Releases resources, timers, and stream controllers.
  void dispose();
}
