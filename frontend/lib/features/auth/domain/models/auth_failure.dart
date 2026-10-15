/// Standardized codes for authentication failures.
enum AuthFailureCode {
  invalidCredentials,
  emailNotConfirmed,
  networkError,
  userNotFound,
  userAlreadyExists,
  weakPassword,
  passwordMismatch,
  serviceUnavailable,
  sessionExpired,
  invalidCallback,
  rateLimitExceeded,
  unconfigured,
  unknown,
}

/// Standardized, privacy-safe failure representation for authentication operations.
class AuthFailure {
  const AuthFailure({
    required this.code,
    required this.message,
    this.retryAfterSeconds,
  });

  final AuthFailureCode code;
  final String message;
  final int? retryAfterSeconds;

  factory AuthFailure.invalidCredentials() => const AuthFailure(
    code: AuthFailureCode.invalidCredentials,
    message: 'Invalid email or password. Please verify your details.',
  );

  factory AuthFailure.emailNotConfirmed() => const AuthFailure(
    code: AuthFailureCode.emailNotConfirmed,
    message: 'Email address has not been confirmed. Please verify your email before signing in.',
  );

  factory AuthFailure.networkError() => const AuthFailure(
    code: AuthFailureCode.networkError,
    message: 'Unable to connect to the authentication service. Please check your internet connection.',
  );

  factory AuthFailure.weakPassword() => const AuthFailure(
    code: AuthFailureCode.weakPassword,
    message: 'Password must be at least 6 characters in length.',
  );

  factory AuthFailure.passwordMismatch() => const AuthFailure(
    code: AuthFailureCode.passwordMismatch,
    message: 'Passwords do not match. Please re-enter both passwords.',
  );

  factory AuthFailure.serviceUnavailable() => const AuthFailure(
    code: AuthFailureCode.serviceUnavailable,
    message: 'Authentication service is temporarily unavailable. Local analysis remains active.',
  );

  factory AuthFailure.sessionExpired() => const AuthFailure(
    code: AuthFailureCode.sessionExpired,
    message: 'Your session has expired. Please sign in again.',
  );

  factory AuthFailure.invalidCallback() => const AuthFailure(
    code: AuthFailureCode.invalidCallback,
    message: 'The authentication link is invalid, expired, or has already been used.',
  );

  factory AuthFailure.rateLimitExceeded({int? retryAfterSeconds}) =>
      AuthFailure(
        code: AuthFailureCode.rateLimitExceeded,
        message: 'Too many requests. Please wait a moment before trying again.',
        retryAfterSeconds: retryAfterSeconds,
      );

  factory AuthFailure.unconfigured() => const AuthFailure(
    code: AuthFailureCode.unconfigured,
    message: 'Cloud authentication is not configured in this build. Local scam analysis remains fully operational.',
  );

  factory AuthFailure.unknown([String? customMessage]) => AuthFailure(
    code: AuthFailureCode.unknown,
    message:
        customMessage ??
        'An unexpected error occurred. Please try again later.',
  );

  @override
  String toString() => 'AuthFailure(code: $code, message: $message)';
}
