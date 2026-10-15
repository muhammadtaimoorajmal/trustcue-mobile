/// Domain model representing an authenticated user identity.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.emailVerified = false,
    this.createdAt,
  });

  /// Unique user UUID from authentication provider.
  final String id;

  /// User email address.
  final String email;

  /// Whether user has verified their email address.
  final bool emailVerified;

  /// Account creation timestamp.
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          emailVerified == other.emailVerified &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, email, emailVerified, createdAt);

  /// Privacy-safe string representation: never logs email address or credentials.
  @override
  String toString() => 'AuthUser(id: $id, emailVerified: $emailVerified)';
}
