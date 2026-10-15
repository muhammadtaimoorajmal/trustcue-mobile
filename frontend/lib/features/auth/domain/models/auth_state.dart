import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';

/// The high-level authentication lifecycle status of the mobile client.
enum AuthStatus {
  /// User is operating in local guest mode without an active session.
  unauthenticated,

  /// User holds an active, locally stored session with verified identity.
  authenticated,

  /// Registration completed or login attempted, but email verification is pending.
  verificationPending,

  /// Client entered a password recovery session via authenticated callback.
  recoverySession,

  /// Cloud authentication service is not configured in this build.
  unconfigured,
}

/// Represents the active session state including the authenticated user.
class AuthSession {
  const AuthSession({
    required this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final AuthUser user;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  String toString() => 'AuthSession(user: ${user.id}, isExpired: $isExpired)';
}
