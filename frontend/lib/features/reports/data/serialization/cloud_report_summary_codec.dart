import 'dart:convert';

import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report_summary.dart';

/// Codec for serializing non-sensitive report summaries for Module 39 Cloud Sync.
///
/// Invariants & Strict Privacy Boundaries:
/// - Strictly prohibits: raw message text (`snapshot.text`), OCR text, evidence quotes,
///   screenshots/binary images, and message hashes.
/// - Only serializes high-level summary fields: format version, outcome state,
///   indicator count, category identifiers, and input source.
/// - Fails closed with an exception if any sensitive field is detected.
class CloudReportSummaryCodec {
  static const int currentFormatVersion = 1;

  static const Set<String> forbiddenKeys = {
    'text',
    'rawtext',
    'raw_text',
    'excerpt',
    'evidence',
    'screenshot',
    'hash',
    'ocrtext',
    'ocr_text',
    'inputtext',
    'input_text',
  };

  const CloudReportSummaryCodec();

  /// Encodes a local [SavedReport] into a privacy-safe cloud summary map.
  Map<String, dynamic> encodeReport(SavedReport report) {
    final categories = <String>{};
    for (final finding in report.localReport.findings) {
      categories.add(finding.category);
    }
    if (report.aiReport != null) {
      for (final finding in report.aiReport!.findings) {
        categories.add(finding.category);
      }
    }

    final payload = <String, dynamic>{
      'formatVersion': currentFormatVersion,
      'outcomeState': report.outcomeState.name,
      'hasAiAnalysis': report.hasAiAnalysis,
      'indicatorCount': report.totalFindingsCount,
      'categories': categories.toList()..sort(),
      'source': report.inputSource.name,
    };

    assertPrivacySanitized(payload);
    return payload;
  }

  /// Encodes a [SavedReportSummary] into a privacy-safe cloud summary map.
  Map<String, dynamic> encodeSummary(SavedReportSummary summary) {
    final payload = <String, dynamic>{
      'formatVersion': currentFormatVersion,
      'outcomeState': summary.outcomeState.name,
      'hasAiAnalysis': summary.hasAiAnalysis,
      'indicatorCount': summary.findingsCount,
      'categories': <String>[],
      'source': summary.inputSource.name,
    };

    assertPrivacySanitized(payload);
    return payload;
  }

  /// Asserts that a map and all its nested children contain zero forbidden content keys.
  void assertPrivacySanitized(dynamic data) {
    if (data is Map) {
      for (final entry in data.entries) {
        final keyStr = entry.key.toString().trim().toLowerCase().replaceAll(
          RegExp(r'[-_]'),
          '',
        );
        if (forbiddenKeys.contains(keyStr)) {
          throw StateError(
            'Privacy Violation: forbidden key "${entry.key}" detected in cloud summary payload!',
          );
        }
        assertPrivacySanitized(entry.value);
      }
    } else if (data is List) {
      for (final item in data) {
        assertPrivacySanitized(item);
      }
    }
  }

  /// Serializes payload to bounded JSON string (max 500 KB).
  String toJsonString(Map<String, dynamic> payload) {
    assertPrivacySanitized(payload);
    final str = jsonEncode(payload);
    if (utf8.encode(str).length > 500000) {
      throw ArgumentError('Cloud payload exceeds 500 KB limit.');
    }
    return str;
  }
}
