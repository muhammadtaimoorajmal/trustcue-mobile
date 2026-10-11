/// The supported intake vectors for TrustCue analysis.
///
/// Note: [link] and [qrCode] are represented distinctly in data models and
/// serialization contracts even though they share an entry point on the
/// product dashboard.
enum InputSource {
  messageText,
  screenshot,
  link,
  qrCode;

  String toSerializedString() => name;

  static InputSource fromSerializedString(String value) {
    for (final source in InputSource.values) {
      if (source.name == value) {
        return source;
      }
    }
    throw FormatException('Unknown InputSource: "$value"');
  }
}
