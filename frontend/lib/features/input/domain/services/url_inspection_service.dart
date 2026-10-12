import 'dart:convert';

import '../models/link_inspection_result.dart';

/// Pure-Dart offline parser and security inspector for digital URLs.
///
/// Strictly guarantees:
/// 1. Zero external network calls (no DNS lookups, HTTP requests, or favicon fetches).
/// 2. Bounded input length (max 4,096 UTF-8 bytes).
/// 3. Rejection of dangerous schemes (javascript:, data:, file:, intent:, tel:, sms:, mailto:).
/// 4. Rejection of embedded credentials/userinfo, control characters, invisible/bidi markers.
/// 5. Rejection of local, private, and internal addresses (RFC 1918, RFC 4193, loopback, link-local).
/// 6. Factual structural observations only (never claiming "safe" or "verified").
class UrlInspectionService {
  const UrlInspectionService();

  static const int maxUtf8Bytes = 4096;

  static final RegExp _schemePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9+\-.]*):');

  static final RegExp _ipv4Pattern = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
  );

  static final RegExp _hexPairPattern = RegExp(r'^[0-9a-fA-F]{2}');

  static final List<String> _redirectParamKeys = <String>[
    'url',
    'redirect',
    'redirect_url',
    'redirect_uri',
    'target',
    'dest',
    'destination',
    'next',
    'return',
    'return_to',
    'r',
    'u',
    'goto',
    'link',
  ];

  /// Inspects a raw input string and produces an offline [LinkInspectionResult].
  LinkInspectionResult inspect(String input) {
    final byteLength = utf8.encode(input).length;
    if (byteLength > maxUtf8Bytes) {
      return LinkInspectionResult.tooLong(input);
    }

    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return LinkInspectionResult.empty(input);
    }

    // Check for control characters (0x00 - 0x1F, 0x7F)
    for (var i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      if ((codeUnit >= 0x00 && codeUnit <= 0x1F) || codeUnit == 0x7F) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          reason: 'URL contains prohibited control characters.',
          code: LinkRejectionCode.containsControlChars,
        );
      }
    }

    // Check for invisible / zero-width characters:
    // \u200B (ZWSP), \u200C (ZWNJ), \u200D (ZWJ), \uFEFF (BOM/ZWNBSP)
    for (var i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      if (codeUnit == 0x200B ||
          codeUnit == 0x200C ||
          codeUnit == 0x200D ||
          codeUnit == 0xFEFF) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          reason: 'URL contains prohibited zero-width or invisible formatting characters.',
          code: LinkRejectionCode.containsInvisibleChars,
        );
      }
    }

    // Check for bidi formatting / override characters:
    // \u202A-\u202E, \u2066-\u2069, \u200E, \u200F
    for (var i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      if ((codeUnit >= 0x202A && codeUnit <= 0x202E) ||
          (codeUnit >= 0x2066 && codeUnit <= 0x2069) ||
          codeUnit == 0x200E ||
          codeUnit == 0x200F) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          reason: 'URL contains bidirectional formatting characters, which can manipulate visual presentation.',
          code: LinkRejectionCode.containsBidiChars,
        );
      }
    }

    // Check for backslashes: prohibited due to cross-browser parsing discrepancies
    if (input.contains(r'\')) {
      return LinkInspectionResult.rejected(
        rawInput: input,
        reason: 'URL contains backslashes ("\\"), which are prohibited due to cross-platform parsing discrepancies.',
        code: LinkRejectionCode.containsBackslash,
      );
    }

    // Check for valid percent-encoding: every '%' must be followed by two hex digits
    for (var i = 0; i < input.length; i++) {
      if (input[i] == '%') {
        if (i + 2 >= input.length ||
            !_hexPairPattern.hasMatch(input.substring(i + 1, i + 3))) {
          return LinkInspectionResult.rejected(
            rawInput: input,
            reason: 'URL contains invalid percent-encoding ("%" must be followed by two hexadecimal digits).',
            code: LinkRejectionCode.malformedPercentEncoding,
          );
        }
      }
    }

    // Interior whitespace is invalid in URLs
    if (trimmed.contains(RegExp(r'\s'))) {
      return LinkInspectionResult.rejected(
        rawInput: input,
        reason: 'URL contains whitespace characters.',
        code: LinkRejectionCode.malformedUrl,
      );
    }

    // Detect scheme
    final schemeMatch = _schemePattern.firstMatch(trimmed);
    if (schemeMatch == null) {
      return LinkInspectionResult.rejected(
        rawInput: input,
        reason: 'Web address is missing an explicit protocol scheme. Please prefix with "https://" or "http://" to inspect this destination.',
        code: LinkRejectionCode.missingScheme,
      );
    }

    final rawScheme = schemeMatch.group(1)!;
    final schemeLower = rawScheme.toLowerCase();

    // Verify allowed launch schemes
    if (schemeLower != 'http' && schemeLower != 'https') {
      return LinkInspectionResult.rejected(
        rawInput: input,
        scheme: rawScheme,
        reason:
            'The "$rawScheme:" scheme is not supported for web navigation. Only standard "http://" and "https://" links can be inspected or opened.',
        code: LinkRejectionCode.unsupportedScheme,
      );
    }

    // Check authority section for userinfo (embedded credentials before @)
    // The authority comes after "scheme://" and before the first '/', '?', or '#'
    final schemeEnd = trimmed.indexOf('://');
    if (schemeEnd == -1) {
      return LinkInspectionResult.rejected(
        rawInput: input,
        scheme: schemeLower,
        reason: 'Malformed URL: missing "://" after scheme.',
        code: LinkRejectionCode.malformedUrl,
      );
    }

    final afterScheme = trimmed.substring(schemeEnd + 3);
    final authorityEndIndex = _findFirstOf(afterScheme, const <String>[
      '/',
      '?',
      '#',
    ]);
    final authority = authorityEndIndex == -1
        ? afterScheme
        : afterScheme.substring(0, authorityEndIndex);

    if (authority.contains('@')) {
      return LinkInspectionResult.rejected(
        rawInput: input,
        scheme: schemeLower,
        hasUserInfo: true,
        reason: 'URL contains embedded user credentials ("@"), which are prohibited due to spoofing and phishing risks.',
        code: LinkRejectionCode.containsUserInfo,
      );
    }

    // Check authority for non-ASCII Unicode characters (IDNA Unicode domain)
    for (var i = 0; i < authority.length; i++) {
      if (authority.codeUnitAt(i) > 127) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          scheme: schemeLower,
          reason: 'Internationalized Unicode domain names are not supported directly for external opening. Standard ASCII punycode ("xn--") is required.',
          code: LinkRejectionCode.unicodeHostUnsupported,
        );
      }
    }

    // Parse URI with standard Dart parser
    final Uri parsed;
    try {
      parsed = Uri.parse(trimmed);
    } catch (_) {
      return LinkInspectionResult.rejected(
        rawInput: input,
        scheme: schemeLower,
        reason: 'URL could not be parsed as a valid destination.',
        code: LinkRejectionCode.malformedUrl,
      );
    }

    final host = parsed.host;
    if (host.isEmpty) {
      return LinkInspectionResult.rejected(
        rawInput: input,
        scheme: schemeLower,
        reason: 'URL is missing a valid destination host or domain.',
        code: LinkRejectionCode.malformedHost,
      );
    }

    // Check for Unicode code units in host (non-ASCII hostnames)
    for (var i = 0; i < host.length; i++) {
      if (host.codeUnitAt(i) > 127) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          scheme: schemeLower,
          host: host,
          reason: 'Internationalized Unicode domain names are not supported directly for external opening. Standard ASCII punycode ("xn--") is required.',
          code: LinkRejectionCode.unicodeHostUnsupported,
        );
      }
    }

    final observations = <String>[];
    bool isIpAddress = false;
    bool isPunycode = false;

    // Check for Punycode labels in host
    final hostLabels = host.split('.');
    for (final label in hostLabels) {
      if (label.toLowerCase().startsWith('xn--')) {
        isPunycode = true;
        observations.add(
          'Destination contains an internationalized punycode label ("$label"), which may visually resemble another domain.',
        );
        break;
      }
    }

    // IP address classification
    final ipv4Match = _ipv4Pattern.firstMatch(host);
    if (ipv4Match != null) {
      final octets = <int>[];
      bool validOctets = true;
      for (var i = 1; i <= 4; i++) {
        final text = ipv4Match.group(i)!;
        // Reject leading zeros on multi-digit octets (e.g. 012)
        if (text.length > 1 && text.startsWith('0')) {
          validOctets = false;
          break;
        }
        final val = int.tryParse(text);
        if (val == null || val < 0 || val > 255) {
          validOctets = false;
          break;
        }
        octets.add(val);
      }

      if (!validOctets) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          scheme: schemeLower,
          host: host,
          reason: 'Malformed IPv4 address in host.',
          code: LinkRejectionCode.malformedHost,
        );
      }

      isIpAddress = true;

      // Local / Private / Loopback / Link-local check for IPv4
      final o0 = octets[0];
      final o1 = octets[1];
      final isLocalOrPrivate =
          (o0 == 0) || // 0.0.0.0/8 (unspecified)
          (o0 == 127) || // 127.0.0.0/8 (loopback)
          (o0 == 10) || // 10.0.0.0/8 (private)
          (o0 == 172 && o1 >= 16 && o1 <= 31) || // 172.16.0.0/12 (private)
          (o0 == 192 && o1 == 168) || // 192.168.0.0/16 (private)
          (o0 == 169 && o1 == 254) || // 169.254.0.0/16 (link-local)
          (o0 == 255); // 255.255.255.255 (broadcast)

      if (isLocalOrPrivate) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          scheme: schemeLower,
          host: host,
          isIpAddress: true,
          reason:
              'Destination points to a local, private, or loopback network address ($host) and cannot be opened externally.',
          code: LinkRejectionCode.localOrPrivateHost,
        );
      }

      observations.add(
        'Destination uses a numerical IP address ($host) instead of a registered domain name.',
      );
    } else if (authority.startsWith('[') ||
        host.contains(':') ||
        (host.startsWith('[') && host.endsWith(']'))) {
      // IPv6 literal
      isIpAddress = true;
      var cleanIpv6 = host.toLowerCase();
      if (cleanIpv6.startsWith('[') && cleanIpv6.endsWith(']')) {
        cleanIpv6 = cleanIpv6.substring(1, cleanIpv6.length - 1);
      }

      final isLocalIpv6 =
          cleanIpv6 == '::1' ||
          cleanIpv6 == '::' ||
          cleanIpv6.startsWith('fc') ||
          cleanIpv6.startsWith('fd') ||
          cleanIpv6.startsWith('fe80');

      if (isLocalIpv6) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          scheme: schemeLower,
          host: host,
          isIpAddress: true,
          reason: 'Destination points to a local, private, or loopback IPv6 address and cannot be opened externally.',
          code: LinkRejectionCode.localOrPrivateHost,
        );
      }

      observations.add(
        'Destination uses an IPv6 literal address ($host) instead of a registered domain name.',
      );
    } else {
      // Standard DNS hostname checks
      final lowerHost = host.toLowerCase();
      if (lowerHost == 'localhost' ||
          lowerHost.endsWith('.localhost') ||
          lowerHost.endsWith('.local') ||
          !lowerHost.contains('.')) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          scheme: schemeLower,
          host: host,
          reason:
              'Local, intranet, and single-label destinations ($host) cannot be opened externally.',
          code: LinkRejectionCode.localOrPrivateHost,
        );
      }

      // Validate DNS host labels
      final labelRegex = RegExp(
        r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$',
      );
      for (final label in hostLabels) {
        if (!labelRegex.hasMatch(label)) {
          return LinkInspectionResult.rejected(
            rawInput: input,
            scheme: schemeLower,
            host: host,
            reason:
                'Host label "$label" contains invalid formatting or characters.',
            code: LinkRejectionCode.malformedHost,
          );
        }
      }
    }

    // Port validation
    int? port;
    if (parsed.hasPort) {
      port = parsed.port;
      if (port <= 0 || port > 65535) {
        return LinkInspectionResult.rejected(
          rawInput: input,
          scheme: schemeLower,
          host: host,
          reason: 'URL specifies an invalid port number ($port).',
          code: LinkRejectionCode.malformedPort,
        );
      }

      final isDefaultPort =
          (schemeLower == 'http' && port == 80) ||
          (schemeLower == 'https' && port == 443);
      if (!isDefaultPort) {
        observations.add(
          'Destination connects to non-standard network port :$port.',
        );
      }
    }

    // Unencrypted HTTP observation
    if (schemeLower == 'http') {
      observations.add(
        'Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption.',
      );
    }

    // Query parameters & open redirect observations
    if (parsed.hasQuery && parsed.query.isNotEmpty) {
      observations.add(
        'Destination contains query parameters (${parsed.queryParameters.keys.length} parameter(s)), which may contain session tokens or tracking identifiers.',
      );

      for (final key in parsed.queryParameters.keys) {
        if (_redirectParamKeys.contains(key.toLowerCase())) {
          final paramVal = parsed.queryParameters[key];
          observations.add(
            'Query parameter "$key${paramVal != null && paramVal.isNotEmpty ? '=$paramVal' : ''}" may indicate an open redirect forwarding to another site.',
          );
          break;
        }
      }
    }

    return LinkInspectionResult(
      rawInput: input,
      isValid: true,
      isLaunchable: true,
      scheme: schemeLower,
      host: host,
      port: port,
      path: parsed.path.isEmpty ? '/' : parsed.path,
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
      isIpAddress: isIpAddress,
      isPunycode: isPunycode,
      observations: observations,
      parsedUri: parsed,
    );
  }

  static int _findFirstOf(String source, List<String> needles) {
    var minIndex = -1;
    for (final needle in needles) {
      final idx = source.indexOf(needle);
      if (idx != -1 && (minIndex == -1 || idx < minIndex)) {
        minIndex = idx;
      }
    }
    return minIndex;
  }
}
