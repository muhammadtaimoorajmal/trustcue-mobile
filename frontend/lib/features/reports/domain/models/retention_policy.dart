/// Enumeration of local report retention policy options for Module 40.
enum RetentionPolicy {
  never(days: 0, label: 'Keep indefinitely (Default)'),
  days30(days: 30, label: '30 days'),
  days60(days: 60, label: '60 days'),
  days90(days: 90, label: '90 days');

  final int days;
  final String label;

  const RetentionPolicy({required this.days, required this.label});

  /// Parse from stored string key with safe fallback to [never].
  static RetentionPolicy fromString(String? value) {
    if (value == null) return RetentionPolicy.never;
    return RetentionPolicy.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RetentionPolicy.never,
    );
  }
}
