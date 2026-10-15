import 'dart:convert';

import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';

/// Codec strictly decoding backend `POST /api/v1/analysis/ai` response envelopes into [AiAnalysisReport].
class AiAnalysisReportCodec {
  const AiAnalysisReportCodec();

  /// Strictly decodes a JSON-compatible map into an [AiAnalysisReport].
  ///
  /// Throws [FormatException] if required fields are missing or invalid.
  AiAnalysisReport decode(Map<String, dynamic> json) {
    final reportId = json['reportId'];
    if (reportId is! String || reportId.trim().isEmpty) {
      throw const FormatException(
        'Missing or invalid "reportId" in AI response.',
      );
    }

    final snapshotId = json['snapshotId'];
    if (snapshotId is! String || snapshotId.trim().isEmpty) {
      throw const FormatException(
        'Missing or invalid "snapshotId" in AI response.',
      );
    }

    final provider = json['provider'];
    if (provider is! String || provider.trim().isEmpty) {
      throw const FormatException(
        'Missing or invalid "provider" in AI response.',
      );
    }

    final model = json['model'];
    if (model is! String || model.trim().isEmpty) {
      throw const FormatException('Missing or invalid "model" in AI response.');
    }

    final rawAnalyzedAt = json['analyzedAt'];
    if (rawAnalyzedAt is! String) {
      throw const FormatException(
        'Missing or invalid "analyzedAt" in AI response.',
      );
    }
    final analyzedAt = DateTime.tryParse(rawAnalyzedAt);
    if (analyzedAt == null) {
      throw FormatException('Invalid ISO-8601 "analyzedAt": $rawAnalyzedAt');
    }

    final factualSummary = json['factualSummary'];
    if (factualSummary is! String || factualSummary.trim().isEmpty) {
      throw const FormatException(
        'Missing or invalid "factualSummary" in AI response.',
      );
    }

    // Decode findings
    final rawFindings = json['findings'];
    if (rawFindings is! List) {
      throw const FormatException(
        'Missing or invalid "findings" list in AI response.',
      );
    }

    final findings = <AnalysisFinding>[];
    for (final rawFinding in rawFindings) {
      if (rawFinding is! Map<String, dynamic>) {
        throw const FormatException('Invalid finding entry in AI response.');
      }

      final fId = rawFinding['id'] as String? ?? '';
      final fCategory = rawFinding['category'] as String? ?? '';
      final fTitle = rawFinding['title'] as String? ?? '';
      final fExplanation = rawFinding['explanation'] as String? ?? '';
      final explanationCombined = fTitle.isNotEmpty
          ? '$fTitle: $fExplanation'
          : fExplanation;

      final rawEvidence =
          rawFinding['evidenceReferences'] ?? rawFinding['evidence'];
      if (rawEvidence is! List || rawEvidence.isEmpty) {
        throw const FormatException(
          'Finding must contain at least one evidence reference.',
        );
      }

      final evidenceList = <EvidenceReference>[];
      for (final ev in rawEvidence) {
        if (ev is! Map<String, dynamic>) {
          throw const FormatException(
            'Invalid evidence reference in AI response.',
          );
        }
        final startOffset = ev['startOffset'] as int?;
        final endOffset = ev['endOffset'] as int?;
        final excerpt =
            ev['excerpt'] as String? ?? ev['exactExcerpt'] as String?;

        if (startOffset == null || endOffset == null || excerpt == null) {
          throw const FormatException('Incomplete evidence reference fields.');
        }

        evidenceList.add(
          EvidenceReference(
            snapshotId: snapshotId,
            startOffset: startOffset,
            endOffset: endOffset,
            exactExcerpt: excerpt,
          ),
        );
      }

      final rawProducer = rawFinding['producerId'] as String?;
      final producerId = (rawProducer != null && rawProducer.trim().isNotEmpty)
          ? rawProducer.trim()
          : 'trustcue-ai-$provider';

      findings.add(
        AnalysisFinding(
          id: fId,
          category: fCategory,
          explanation: explanationCombined,
          origin: FindingOrigin.remoteAi,
          producerId: producerId,
          evidence: evidenceList,
        ),
      );
    }

    // Decode uncertainty notes
    final rawUncertainty = json['uncertaintyNotes'];
    final uncertaintyNotes = <String>[];
    if (rawUncertainty is List) {
      for (final note in rawUncertainty) {
        if (note is String && note.trim().isNotEmpty) {
          uncertaintyNotes.add(note.trim());
        }
      }
    }

    // Decode suggested actions
    final rawActions = json['suggestedActions'];
    final suggestedActions = <AssessmentAction>[];
    if (rawActions is List) {
      for (final act in rawActions) {
        if (act is Map<String, dynamic>) {
          final actId = act['id'] as String? ?? 'action-unknown';
          final actTitle = act['title'] as String? ?? 'Safety Guidance';
          final actDetailRaw =
              act['detail'] as String? ?? act['description'] as String? ?? '';
          final actDetail = actDetailRaw.trim().isNotEmpty
              ? actDetailRaw.trim()
              : actTitle;
          final rawPriority = act['priority'] as String? ?? 'recommended';

          AssessmentActionPriority priority;
          switch (rawPriority.toLowerCase()) {
            case 'immediate':
              priority = AssessmentActionPriority.immediate;
              break;
            case 'conditional':
              priority = AssessmentActionPriority.conditional;
              break;
            default:
              priority = AssessmentActionPriority.recommended;
              break;
          }

          final rawCategories = act['supportingCategoryIds'];
          final categoryIds = <String>[];
          if (rawCategories is List) {
            for (final cat in rawCategories) {
              if (cat is String && cat.trim().isNotEmpty) {
                categoryIds.add(cat.trim());
              }
            }
          }

          suggestedActions.add(
            AssessmentAction(
              id: actId,
              title: actTitle,
              description: actDetail,
              priority: priority,
              supportingFindingIds: const [],
              supportingCategoryIds: categoryIds,
            ),
          );
        }
      }
    }

    return AiAnalysisReport(
      reportId: reportId,
      snapshotId: snapshotId,
      provider: provider,
      model: model,
      analyzedAt: analyzedAt,
      factualSummary: factualSummary,
      findings: findings,
      uncertaintyNotes: uncertaintyNotes,
      suggestedActions: suggestedActions,
    );
  }

  /// Convenience method decoding from JSON string directly into a [Result].
  Result<AiAnalysisReport> decodeJsonString(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const Result.failure(
          AnalysisFailure.malformedData(
            'Top-level AI response must be a JSON object.',
          ),
        );
      }
      return Result.success(decode(decoded));
    } on FormatException catch (e) {
      return Result.failure(AnalysisFailure.malformedData(e.message));
    } catch (e) {
      return Result.failure(AnalysisFailure.malformedData(e.toString()));
    }
  }
}
