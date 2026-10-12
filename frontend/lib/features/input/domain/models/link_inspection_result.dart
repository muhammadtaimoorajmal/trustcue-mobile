/// The rejection categories for digital link inspection.
enum LinkRejectionCode {
  empty,
  tooLong,
  missingScheme,
  unsupportedScheme,
  containsUserInfo,
  containsBackslash,
  containsControlChars,
  containsInvisibleChars,
  containsBidiChars,
  malformedUrl,
  malformedPercentEncoding,
  malformedPort,
  malformedHost,
  unicodeHostUnsupported,
  localOrPrivateHost,
}

/// The local, offline inspection result of a digital web address.
///
/// Contains structural details, factual observations, and eligibility
/// for explicit external opening. Zero external network requests or DNS queries
/// are performed to produce this result.
class LinkInspectionResult {
  const LinkInspectionResult({
    required this.rawInput,
    required this.isValid,
    required this.isLaunchable,
    this.scheme,
    this.host,
    this.port,
    this.path,
    this.query,
    this.fragment,
    this.hasUserInfo = false,
    this.isIpAddress = false,
    this.isPunycode = false,
    this.observations = const <String>[],
    this.rejectionReason,
    this.rejectionCode,
    this.parsedUri,
  });

  /// The exact unedited input text inspected.
  final String rawInput;

  /// Whether the input successfully parsed as a structurally valid URL.
  final bool isValid;

  /// Whether this destination meets all strict criteria to be safely eligible
  /// for external application launching (http/https, public host, no embedded credentials, etc.).
  final bool isLaunchable;

  /// The parsed protocol scheme (e.g. 'https' or 'http').
  final String? scheme;

  /// The full parsed complete hostname (e.g. 'example.com' or '192.0.2.1').
  /// Registrable domain guessing is deliberately avoided.
  final String? host;

  /// The explicit port number if provided in the URL and non-default.
  final int? port;

  /// The URL path component.
  final String? path;

  /// The raw query component.
  final String? query;

  /// The URL fragment/hash component.
  final String? fragment;

  /// Whether the URL contained credentials or userinfo (e.g. 'user:pass@').
  final bool hasUserInfo;

  /// Whether the destination host is a direct IP address rather than a domain name.
  final bool isIpAddress;

  /// Whether the host contains internationalized punycode labels ('xn--').
  final bool isPunycode;

  /// Factual, purely structural observations derived offline.
  /// Never contains fabricated reputation or claim of security.
  final List<String> observations;

  /// User-facing explanation of why opening is disallowed or why parsing failed.
  final String? rejectionReason;

  /// Programmatic reason code for rejection.
  final LinkRejectionCode? rejectionCode;

  /// The validated parsed [Uri] instance, non-null if [isLaunchable] is true.
  final Uri? parsedUri;

  /// Factory for empty or blank input.
  factory LinkInspectionResult.empty([String raw = '']) => LinkInspectionResult(
    rawInput: raw,
    isValid: false,
    isLaunchable: false,
    rejectionReason: 'Please enter a web address to inspect.',
    rejectionCode: LinkRejectionCode.empty,
  );

  /// Factory for oversized payloads exceeding 4,096 UTF-8 bytes.
  factory LinkInspectionResult.tooLong(String raw) => LinkInspectionResult(
    rawInput: raw,
    isValid: false,
    isLaunchable: false,
    rejectionReason:
        'Web address exceeds the maximum allowed length of 4,096 bytes.',
    rejectionCode: LinkRejectionCode.tooLong,
  );

  /// Factory for rejected or disallowed URLs.
  factory LinkInspectionResult.rejected({
    required String rawInput,
    required String reason,
    required LinkRejectionCode code,
    String? scheme,
    String? host,
    int? port,
    String? path,
    String? query,
    String? fragment,
    bool hasUserInfo = false,
    bool isIpAddress = false,
    bool isPunycode = false,
    List<String> observations = const <String>[],
  }) => LinkInspectionResult(
    rawInput: rawInput,
    isValid: false,
    isLaunchable: false,
    scheme: scheme,
    host: host,
    port: port,
    path: path,
    query: query,
    fragment: fragment,
    hasUserInfo: hasUserInfo,
    isIpAddress: isIpAddress,
    isPunycode: isPunycode,
    observations: observations,
    rejectionReason: reason,
    rejectionCode: code,
  );

  @override
  String toString() {
    return 'LinkInspectionResult(host: $host, isLaunchable: $isLaunchable, code: $rejectionCode)';
  }
}
