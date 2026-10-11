import 'dart:convert';

import '../../../../core/errors/analysis_failure.dart';
import '../../../../core/types/result.dart';
import '../../../input/data/serialization/text_snapshot_codec.dart';
import '../../domain/models/analysis_finding.dart';
import '../../domain/models/analysis_report.dart';
import 'analysis_finding_codec.dart';

/// Codec for encoding and strictly decoding [AnalysisReport] instances to/from JSON maps.
class AnalysisReportCodec {
  final TextSnapshotCodec snapshotCodec;
  final AnalysisFindingCodec findingCodec;

  const AnalysisReportCodec({
    this.snapshotCodec = const TextSnapshotCodec(),
    this.findingCodec = const AnalysisFindingCodec(),
  });

  /// Encodes an [AnalysisReport] into a version-1 JSON-compatible map.
  Map<String, dynamic> encode(AnalysisReport report) {
    return {
      'id': report.id,
      'schemaVersion': report.schemaVersion,
      'snapshot': snapshotCodec.encode(report.snapshot),
      'analyzedAt': report.analyzedAt.toIso8601String(),
      'findings': report.findings.map(findingCodec.encode).toList(),
      'limitations': report.limitations.toList(),
      'suggestedActions': report.suggestedActions.toList(),
    };
  }

  /// Encodes an [AnalysisReport] into a formatted JSON string.
  String encodeJsonString(AnalysisReport report) {
    return jsonEncode(encode(report));
  }

  /// Strictly decodes a JSON map into an [AnalysisReport].
  ///
  /// Throws [FormatException] if:
  /// - Required fields are missing or not of expected types.
  /// - [schemaVersion] is not strict int or is unsupported.
  /// - [analyzedAt] is invalid or lacks explicit timezone.
  /// - Duplicate finding IDs or mismatched evidence references are detected.
  AnalysisReport decode(Map<String, dynamic> json) {
    final idValue = json['id'];
    if (idValue is! String) {
      throw const FormatException(
        'AnalysisReport "id" must be a non-null String.',
      );
    }

    final schemaVersionValue = json['schemaVersion'];
    if (schemaVersionValue is! int) {
      throw const FormatException(
        'AnalysisReport "schemaVersion" must be a non-null integer.',
      );
    }
    if (schemaVersionValue != AnalysisReport.currentSchemaVersion) {
      throw FormatException(
        'Unsupported schema version: $schemaVersionValue (supported: ${AnalysisReport.currentSchemaVersion}).',
      );
    }

    final rawSnapshot = json['snapshot'];
    if (rawSnapshot is! Map) {
      throw const FormatException(
        'AnalysisReport "snapshot" must be a non-null JSON object.',
      );
    }
    final snapshot = snapshotCodec.decode(rawSnapshot.cast<String, dynamic>());

    final analyzedAtValue = json['analyzedAt'];
    if (analyzedAtValue is! String) {
      throw const FormatException(
        'AnalysisReport "analyzedAt" must be a non-null String.',
      );
    }
    final analyzedAt = TextSnapshotCodec.parseUtcTimestamp(
      analyzedAtValue,
      'analyzedAt',
    );

    final rawFindings = json['findings'];
    if (rawFindings is! List) {
      throw const FormatException(
        'AnalysisReport "findings" must be a non-null List.',
      );
    }

    final findings = <AnalysisFinding>[];
    for (var i = 0; i < rawFindings.length; i++) {
      final rawItem = rawFindings[i];
      if (rawItem is! Map) {
        throw FormatException(
          'AnalysisReport finding at index $i is not a JSON object.',
        );
      }
      findings.add(findingCodec.decode(rawItem.cast<String, dynamic>()));
    }

    final rawLimitations = json['limitations'];
    if (rawLimitations is! List) {
      throw const FormatException(
        'AnalysisReport "limitations" must be a non-null List.',
      );
    }
    final limitations = <String>[];
    for (var i = 0; i < rawLimitations.length; i++) {
      final item = rawLimitations[i];
      if (item is! String) {
        throw FormatException(
          'AnalysisReport limitation at index $i must be a String.',
        );
      }
      limitations.add(item);
    }

    final rawActions = json['suggestedActions'];
    if (rawActions is! List) {
      throw const FormatException(
        'AnalysisReport "suggestedActions" must be a non-null List.',
      );
    }
    final suggestedActions = <String>[];
    for (var i = 0; i < rawActions.length; i++) {
      final item = rawActions[i];
      if (item is! String) {
        throw FormatException(
          'AnalysisReport suggestedAction at index $i must be a String.',
        );
      }
      suggestedActions.add(item);
    }

    try {
      return AnalysisReport(
        id: idValue,
        schemaVersion: schemaVersionValue,
        snapshot: snapshot,
        analyzedAt: analyzedAt,
        findings: findings,
        limitations: limitations,
        suggestedActions: suggestedActions,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Invalid AnalysisReport: ${e.message}');
    }
  }

  /// Strictly decodes a raw JSON string into a [Result<AnalysisReport>].
  ///
  /// Traps [FormatException] and returns a typed [Failure] with code
  /// [AnalysisFailureCode.malformedData], ensuring sensitive input text or stack
  /// traces are never exposed to callers.
  Result<AnalysisReport> decodeJsonString(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        return const Result.failure(
          AnalysisFailure.malformedData(
            'JSON payload must be an object at root level.',
          ),
        );
      }
      final report = decode(decoded.cast<String, dynamic>());
      return Result.success(report);
    } on FormatException catch (e) {
      return Result.failure(
        AnalysisFailure.malformedData('Malformed report data: ${e.message}'),
      );
    } catch (_) {
      return const Result.failure(
        AnalysisFailure.malformedData(
          'Unexpected error while parsing report data.',
        ),
      );
    }
  }
}
