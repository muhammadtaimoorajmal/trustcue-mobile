import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting factual structural anomalies in embedded
/// web addresses (URLs), such as numerical IP hosts, embedded user credentials,
/// punycode domain labels, non-standard ports, and parameters commonly used to specify a destination.
class LinkStructuralRule implements LocalRule {
  @override
  String get id => 'rule.link.structural_risk';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category => IndicatorCategory.linkStructuralIndicators;

  @override
  List<String> get supportedLanguages => const ['*'];

  @override
  List<String> get limitations => const [
    'Evaluates explicit http:// and https:// URLs parsed directly from text snapshots. Does not perform DNS resolution, network connections, HTTP redirects, or URL expansion.',
    'Reports purely factual structural observations: numerical IP hosts, user credentials preceding host, punycode labels, non-standard network ports, and parameters commonly used to specify a destination. Does not evaluate domain reputation or make a determination of fraud.',
    'Does not treat HTTPS as proof of safety, nor does it flag standard subdomains, path depth, or ordinary query strings as inherently suspicious.',
    'Displayed-text versus destination-link mismatch is not supported in unformatted text snapshots.',
  ];

  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );

  static final RegExp _ipv4Pattern = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
  );

  static final List<String> _redirectKeys = <String>[
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
    'goto',
    'link',
    'r',
    'u',
  ];

  @override
  List<AnalysisFinding> evaluate(TextSnapshot snapshot) {
    final text = snapshot.text;
    if (text.isEmpty) return const [];

    final rawMatches = _urlRegex.allMatches(text);
    if (rawMatches.isEmpty) return const [];

    final findings = <AnalysisFinding>[];

    for (final match in rawMatches) {
      var start = match.start;
      var end = match.end;

      if (start >= end) continue;

      // Extract raw candidate string
      var candidate = text.substring(start, end);

      // Trim trailing prose punctuation and unclosed parentheses
      candidate = _trimTrailingPunctuation(candidate);
      end = start + candidate.length;

      if (candidate.isEmpty || start >= end) continue;

      // Guard against splitting surrogate pairs
      if (EvidenceReference.isSurrogateSplit(text, start) ||
          EvidenceReference.isSurrogateSplit(text, end)) {
        continue;
      }

      // Perform pure structural inspection on trimmed candidate URL
      final structuralObservation = _inspectUrlStructure(candidate);
      if (structuralObservation == null) {
        continue; // No structural anomaly identified
      }

      final evidence = EvidenceValidator.createReference(
        snapshot: snapshot,
        startOffset: start,
        endOffset: end,
      );

      findings.add(
        AnalysisFinding(
          id: '${id}_${start}_$end',
          category: category.id,
          explanation: structuralObservation,
          origin: FindingOrigin.localRule,
          producerId: id,
          evidence: [evidence],
        ),
      );

      if (findings.length > RuleMatcherUtils.maxMatchesPerRule) {
        throw RuleLimitExceededException(
          ruleId: id,
          limit: RuleMatcherUtils.maxMatchesPerRule,
        );
      }
    }

    return List.unmodifiable(findings);
  }

  /// Trims trailing punctuation (.,;:!?) and unmatched closing parentheses.
  static String _trimTrailingPunctuation(String raw) {
    var trimmed = raw;
    while (trimmed.isNotEmpty) {
      final lastChar = trimmed[trimmed.length - 1];

      // Trim standard prose punctuation
      if (lastChar == '.' ||
          lastChar == ',' ||
          lastChar == ';' ||
          lastChar == ':' ||
          lastChar == '!' ||
          lastChar == '?' ||
          lastChar == '>' ||
          lastChar == '"' ||
          lastChar == "'") {
        trimmed = trimmed.substring(0, trimmed.length - 1);
        continue;
      }

      // Check unbalanced closing parenthesis
      if (lastChar == ')') {
        final openCount = '('.allMatches(trimmed).length;
        final closeCount = ')'.allMatches(trimmed).length;
        if (closeCount > openCount) {
          trimmed = trimmed.substring(0, trimmed.length - 1);
          continue;
        }
      }

      // Check unbalanced closing square bracket
      if (lastChar == ']') {
        final openCount = '['.allMatches(trimmed).length;
        final closeCount = ']'.allMatches(trimmed).length;
        if (closeCount > openCount) {
          trimmed = trimmed.substring(0, trimmed.length - 1);
          continue;
        }
      }

      break;
    }
    return trimmed;
  }

  /// Pure structural inspector returning a factual explanation of any detected anomaly,
  /// or null if the URL contains only standard structure.
  static String? _inspectUrlStructure(String urlString) {
    // 1. Check for embedded user information (credentials before @)
    final schemeEnd = urlString.indexOf('://');
    if (schemeEnd == -1) return null;

    final afterScheme = urlString.substring(schemeEnd + 3);
    final authorityEnd = _findFirstOf(afterScheme, const ['/', '?', '#']);
    final authority = authorityEnd == -1
        ? afterScheme
        : afterScheme.substring(0, authorityEnd);

    final observations = <String>[];

    // Embedded user credentials check
    if (authority.contains('@')) {
      final atIndex = authority.lastIndexOf('@');
      var actualHostPart = authority.substring(atIndex + 1);
      if (actualHostPart.contains(':')) {
        actualHostPart = actualHostPart.split(':').first;
      }
      observations.add(
        'The link contains embedded user information before the host; the actual destination host is "$actualHostPart".',
      );
    }

    // Parse URI for standard structural elements
    Uri? parsed;
    try {
      parsed = Uri.parse(urlString);
    } catch (_) {
      // Malformed URL candidates that fail standard parsing are reported safely
      // without halting analysis or throwing unhandled exceptions.
      if (observations.isNotEmpty) {
        return observations.join(' ');
      }
      return null;
    }

    final host = parsed.host.toLowerCase();
    if (host.isEmpty) {
      if (observations.isNotEmpty) return observations.join(' ');
      return null;
    }

    // 2. Numerical IP address host check
    if (_ipv4Pattern.hasMatch(host) ||
        authority.startsWith('[') ||
        host.contains(':')) {
      observations.add(
        'The link specifies a direct numerical IP address ($host) instead of a domain name.',
      );
    }

    // 3. Internationalized punycode label check
    if (host.split('.').any((label) => label.startsWith('xn--'))) {
      observations.add(
        'The link destination contains an internationalized punycode label ("xn--"), which may visually imitate another domain.',
      );
    }

    // 4. Non-standard network port check
    if (parsed.hasPort) {
      final port = parsed.port;
      final isDefault =
          (parsed.scheme == 'http' && port == 80) ||
          (parsed.scheme == 'https' && port == 443);
      if (!isDefault && port > 0) {
        observations.add(
          'The link specifies a non-standard network port (:$port).',
        );
      }
    }

    // 5. Destination parameter check
    if (parsed.hasQuery && parsed.queryParameters.isNotEmpty) {
      for (final key in parsed.queryParameters.keys) {
        if (_redirectKeys.contains(key.toLowerCase())) {
          final val = parsed.queryParameters[key];
          final valSnippet = val != null && val.isNotEmpty ? '=$val' : '';
          observations.add(
            'The URL contains a parameter commonly used to specify a destination ("$key$valSnippet").',
          );
          break;
        }
      }
    }

    if (observations.isEmpty) return null;
    return observations.join(' ');
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
