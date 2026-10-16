/// Application user profile metadata retrieved from server.
///
/// Invariants:
/// - Strictly typed domain model mirroring backend UserProfileResponse.
/// - Encapsulates verified identity, display name, timestamps, and AI quota.
/// - Unchangeable server attributes (quotas, timestamps, sync flags) are immutable.
class UserProfile {
  final String userId;
  final String? displayName;
  final String email;
  final bool emailVerified;
  final DateTime createdAt;
  final bool syncEnabled;
  final int quotaRemainingToday;

  const UserProfile({
    required this.userId,
    this.displayName,
    required this.email,
    required this.emailVerified,
    required this.createdAt,
    required this.syncEnabled,
    required this.quotaRemainingToday,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      syncEnabled: json['syncEnabled'] as bool? ?? false,
      quotaRemainingToday: json['quotaRemainingToday'] as int? ?? 15,
    );
  }

  UserProfile copyWith({
    String? displayName,
    int? quotaRemainingToday,
    bool? syncEnabled,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      email: email,
      emailVerified: emailVerified,
      createdAt: createdAt,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      quotaRemainingToday: quotaRemainingToday ?? this.quotaRemainingToday,
    );
  }
}
