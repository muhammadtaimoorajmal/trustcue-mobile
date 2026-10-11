import '../../domain/models/analysis_finding.dart';
import '../../domain/models/evidence_reference.dart';
import '../../domain/models/finding_origin.dart';
import 'evidence_reference_codec.dart';

/// Codec for encoding and strictly decoding [AnalysisFinding] instances.
class AnalysisFindingCodec {
  final EvidenceReferenceCodec evidenceCodec;

  const AnalysisFindingCodec({
    this.evidenceCodec = const EvidenceReferenceCodec(),
  });

  /// Encodes an [AnalysisFinding] into a version-1 JSON-compatible map.
  Map<String, dynamic> encode(AnalysisFinding finding) {
    return {
      'id': finding.id,
      'category': finding.category,
      'explanation': finding.explanation,
      'origin': finding.origin.toSerializedString(),
      'producerId': finding.producerId,
      'evidence': finding.evidence.map(evidenceCodec.encode).toList(),
    };
  }

  /// Strictly decodes a JSON map into an [AnalysisFinding].
  ///
  /// Throws [FormatException] if:
  /// - Required fields are missing or not of expected types.
  /// - [origin] is an unknown enum name.
  /// - [evidence] is not a non-empty list of valid evidence maps.
  AnalysisFinding decode(Map<String, dynamic> json) {
    final idValue = json['id'];
    if (idValue is! String) {
      throw const FormatException(
        'AnalysisFinding "id" must be a non-null String.',
      );
    }

    final categoryValue = json['category'];
    if (categoryValue is! String) {
      throw const FormatException(
        'AnalysisFinding "category" must be a non-null String.',
      );
    }

    final explanationValue = json['explanation'];
    if (explanationValue is! String) {
      throw const FormatException(
        'AnalysisFinding "explanation" must be a non-null String.',
      );
    }

    final originValue = json['origin'];
    if (originValue is! String) {
      throw const FormatException(
        'AnalysisFinding "origin" must be a non-null String.',
      );
    }
    final origin = FindingOrigin.fromSerializedString(originValue);

    final producerIdValue = json['producerId'];
    if (producerIdValue is! String) {
      throw const FormatException(
        'AnalysisFinding "producerId" must be a non-null String.',
      );
    }

    final evidenceListValue = json['evidence'];
    if (evidenceListValue is! List) {
      throw const FormatException(
        'AnalysisFinding "evidence" must be a non-null List.',
      );
    }
    if (evidenceListValue.isEmpty) {
      throw const FormatException(
        'AnalysisFinding "evidence" must contain at least one item.',
      );
    }

    final evidenceItems = <EvidenceReference>[];
    for (var i = 0; i < evidenceListValue.length; i++) {
      final rawItem = evidenceListValue[i];
      if (rawItem is! Map<String, dynamic>) {
        if (rawItem is Map) {
          evidenceItems.add(
            evidenceCodec.decode(rawItem.cast<String, dynamic>()),
          );
          continue;
        }
        throw FormatException(
          'AnalysisFinding evidence at index $i is not a JSON object.',
        );
      }
      evidenceItems.add(evidenceCodec.decode(rawItem));
    }

    try {
      return AnalysisFinding(
        id: idValue,
        category: categoryValue,
        explanation: explanationValue,
        origin: origin,
        producerId: producerIdValue,
        evidence: evidenceItems,
      );
    } on ArgumentError catch (e) {
      throw FormatException('Invalid AnalysisFinding: ${e.message}');
    }
  }
}
