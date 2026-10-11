/// Provenance indicator identifying the origin type of an analysis finding.
///
/// Note: Origin is descriptive provenance, not proof that an AI call occurred.
/// Production code must not manufacture [remoteAi] findings; synthetic fixtures
/// stay in tests until verified AI analysis is scheduled in later modules.
enum FindingOrigin {
  localRule,
  remoteAi;

  String toSerializedString() => name;

  static FindingOrigin fromSerializedString(String value) {
    for (final origin in FindingOrigin.values) {
      if (origin.name == value) {
        return origin;
      }
    }
    throw FormatException('Unknown FindingOrigin: "$value"');
  }
}
