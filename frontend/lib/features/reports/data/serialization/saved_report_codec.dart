import 'dart:convert';

import 'package:trustcue_mobile/features/analysis/data/serialization/ai_analysis_report_codec.dart';
import 'package:trustcue_mobile/features/analysis/data/serialization/analysis_report_codec.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/input/data/serialization/text_snapshot_codec.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';

/// Codec for encoding and strictly decoding [SavedReport] instances to/from JSON payloads.
///
/// Invariants & Guarantees:
/// - Reconstructs reports only with their exact authenticated [TextSnapshot].
/// - Validates all finding offsets against the snapshot upon deserialization.
/// - Explicit format version check ([currentFormatVersion] = 1); throws on unsupported versions.
/// - Never includes raw authentication credentials, tokens, or image file paths.
class SavedReportCodec {
  static const int currentFormatVersion = 1;

  final AnalysisReportCodec localReportCodec;
  final AiAnalysisReportCodec aiReportCodec;

  const SavedReportCodec({
    this.localReportCodec = const AnalysisReportCodec(),
    this.aiReportCodec = const AiAnalysisReportCodec(),
  });

  /// Encodes a [SavedReport] into a JSON-compatible map for durable SQLite storage.
  Map<String, dynamic> encode(SavedReport report) {
    return {
      'formatVersion': currentFormatVersion,
      'id': report.id,
      'schemaVersion': report.schemaVersion,
      'snapshotId': report.snapshot.id,
      'accountId': report.accountId,
      'analyzedAt': report.analyzedAt.toIso8601String(),
      'savedAt': report.savedAt.toIso8601String(),
      'localReport': localReportCodec.encode(report.localReport),
      'aiReport': report.aiReport != null
          ? aiReportCodec.encode(report.aiReport!)
          : null,
    };
  }

  /// Encodes a [SavedReport] into a UTF-8 JSON string.
  String encodeJson(SavedReport report) {
    return jsonEncode(encode(report));
  }

  /// Strictly decodes a JSON map and binds it to the provided [snapshot].
  ///
  /// Throws [FormatException] if:
  /// - Format version is invalid or unsupported.
  /// - Required fields are missing or wrong types.
  /// - Snapshot ID does not match the report payload.
  /// - Findings fail validation against [snapshot].
  SavedReport decode(Map<String, dynamic> json, TextSnapshot snapshot) {
    final formatVersionValue = json['formatVersion'];
    if (formatVersionValue is! int) {
      throw const FormatException(
        'SavedReport "formatVersion" must be a non-null integer.',
      );
    }
    if (formatVersionValue != currentFormatVersion) {
      throw FormatException(
        'Unsupported stored report format version: $formatVersionValue (supported: $currentFormatVersion).',
      );
    }

    final idValue = json['id'];
    if (idValue is! String || idValue.trim().isEmpty) {
      throw const FormatException(
        'SavedReport "id" must be a non-empty String.',
      );
    }

    final schemaVersionValue = json['schemaVersion'];
    if (schemaVersionValue is! int) {
      throw const FormatException(
        'SavedReport "schemaVersion" must be a non-null integer.',
      );
    }

    final snapshotIdValue = json['snapshotId'];
    if (snapshotIdValue is! String || snapshotIdValue.trim().isEmpty) {
      throw const FormatException(
        'SavedReport "snapshotId" must be a non-empty String.',
      );
    }
    if (snapshotIdValue != snapshot.id) {
      throw FormatException(
        'Snapshot ID mismatch: payload is bound to "$snapshotIdValue" but provided snapshot is "${snapshot.id}".',
      );
    }

    final accountIdValue = json['accountId'];
    final String? accountId = accountIdValue is String ? accountIdValue : null;

    final analyzedAtValue = json['analyzedAt'];
    if (analyzedAtValue is! String) {
      throw const FormatException(
        'SavedReport "analyzedAt" must be a non-null String.',
      );
    }
    final analyzedAt = TextSnapshotCodec.parseUtcTimestamp(
      analyzedAtValue,
      'analyzedAt',
    );

    final savedAtValue = json['savedAt'];
    if (savedAtValue is! String) {
      throw const FormatException(
        'SavedReport "savedAt" must be a non-null String.',
      );
    }
    final savedAt = TextSnapshotCodec.parseUtcTimestamp(
      savedAtValue,
      'savedAt',
    );

    // Decode local report
    final rawLocalReport = json['localReport'];
    if (rawLocalReport is! Map) {
      throw const FormatException(
        'SavedReport "localReport" must be a non-null JSON object.',
      );
    }
    final AnalysisReport localReport = localReportCodec.decode(
      rawLocalReport.cast<String, dynamic>(),
    );

    // Decode optional AI report
    AiAnalysisReport? aiReport;
    final rawAiReport = json['aiReport'];
    if (rawAiReport != null) {
      if (rawAiReport is! Map) {
        throw const FormatException(
          'SavedReport "aiReport" must be a JSON object if present.',
        );
      }
      aiReport = aiReportCodec.decode(rawAiReport.cast<String, dynamic>());
    }

    return SavedReport(
      id: idValue,
      schemaVersion: schemaVersionValue,
      snapshot: snapshot,
      accountId: accountId,
      analyzedAt: analyzedAt,
      savedAt: savedAt,
      localReport: localReport,
      aiReport: aiReport,
    );
  }

  /// Strictly decodes a JSON string and binds it to [snapshot].
  SavedReport decodeJson(String jsonString, TextSnapshot snapshot) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Stored report payload must be a JSON object.',
      );
    }
    return decode(decoded, snapshot);
  }
}
