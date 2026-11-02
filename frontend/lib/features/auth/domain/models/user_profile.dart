/// Application user profile metadata retrieved from server.
///
/// Invariants:
/// - Strictly typed domain model mirroring backend UserProfileResponse.
/// - Encapsulates verified identity, display name, avatar references, timestamps, and AI quota.
/// - Unchangeable server attributes (quotas, timestamps, sync flags) are immutable.
class UserProfile {
  final String userId;
  final String? displayName;
  final String? avatarPath;
  final String? avatarUrl;
  final String email;
  final bool emailVerified;
  final DateTime createdAt;
  final bool syncEnabled;
  final int syncGeneration;
  final int quotaRemainingToday;

  const UserProfile({
    required this.userId,
    this.displayName,
    this.avatarPath,
    this.avatarUrl,
    required this.email,
    required this.emailVerified,
    required this.createdAt,
    required this.syncEnabled,
    this.syncGeneration = 1,
    required this.quotaRemainingToday,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String?,
      avatarPath: json['avatarPath'] as String? ?? json['avatar_path'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      email: json['email'] as String? ?? '',
      emailVerified: json['emailVerified'] as bool? ?? json['email_verified'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? json['created_at'] as String? ?? '') ?? DateTime.now(),
      syncEnabled: json['syncEnabled'] as bool? ?? json['sync_enabled'] as bool? ?? false,
      syncGeneration: json['syncGeneration'] as int? ?? json['sync_generation'] as int? ?? 1,
      quotaRemainingToday: json['quotaRemainingToday'] as int? ?? json['quota_remaining_today'] as int? ?? 15,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'avatarPath': avatarPath,
      'avatarUrl': avatarUrl,
      'email': email,
      'emailVerified': emailVerified,
      'createdAt': createdAt.toIso8601String(),
      'syncEnabled': syncEnabled,
      'syncGeneration': syncGeneration,
      'quotaRemainingToday': quotaRemainingToday,
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? avatarPath,
    String? avatarUrl,
    bool clearAvatar = false,
    int? quotaRemainingToday,
    bool? syncEnabled,
    int? syncGeneration,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      email: email,
      emailVerified: emailVerified,
      createdAt: createdAt,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncGeneration: syncGeneration ?? this.syncGeneration,
      quotaRemainingToday: quotaRemainingToday ?? this.quotaRemainingToday,
    );
  }
}
