import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_service.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/rule_registry.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';

/// Pure-Dart deterministic engine for evaluating registered [LocalRule]s against a [TextSnapshot].
///
/// Guarantees:
/// - Zero platform, widget, GetX, storage, network, or third-party dependencies.
/// - Pure function evaluation: rules are evaluated against exact snapshot text without side effects.
/// - Enforces existing input validation policy ([MessageTextValidator]) for code points, bytes, and encoding.
/// - Validates strict evidence integrity: offsets, excerpts, snapshot ID matching, surrogate safety.
/// - Enforces reasonable upper bounds on emitted findings ([maxFindings]) returning typed failure on overflow.
/// - Deterministic finding ordering across runs.
/// - Returns privacy-safe typed failures on rule errors; never exposes user message text in failure messages.
/// - An empty findings report is NEVER presented as a guarantee of safety or legitimacy.
class LocalRuleEngine implements AnalysisService {
  /// Default reasonable upper bound for findings emitted from a single snapshot analysis.
  static const int defaultMaxFindings = 100;

  final RuleRegistry registry;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final int maxFindings;

  LocalRuleEngine({
    required this.registry,
    DateTime Function()? clock,
    String Function()? idGenerator,
    this.maxFindings = defaultMaxFindings,
  }) : _clock = clock ?? _defaultClock,
       _idGenerator = idGenerator ?? _defaultIdGenerator;

  @override
  Future<Result<AnalysisReport>> analyze(TextSnapshot snapshot) async {
    // 1. Enforce existing input limits and text validation policy
    final validation = MessageTextValidator.validate(snapshot.text);
    if (validation.isInvalid) {
      return Result.failure(validation.error!.toAnalysisFailure());
    }

    // 2. Evaluate all registered rules
    final rules = registry.rules;
    final accumulatedFindings = <AnalysisFinding>[];

    final collectedLimitations = <String>[
      'Analysis is limited to deterministic on-device local rule evaluation of exact snapshot text.',
      'Ordinary legitimate messages can contain these patterns. A matching phrase alone does not prove fraud, impersonation, or malicious intent.',
      'An empty findings report indicates only that no configured local rules matched. It is never a guarantee of safety or legitimacy.',
    ];

    final collectedActions = <String>[
      'Verify the sender and message content through trusted, independent channels before taking action.',
      'Do not share passwords, verification codes, or make payments requested in unexpected messages.',
    ];

    for (final rule in rules) {
      List<AnalysisFinding> ruleFindings;
      try {
        ruleFindings = rule.evaluate(snapshot);
      } catch (_) {
        return Result.failure(
          AnalysisFailure.malformedData(
            'Local rule evaluation failed for rule "${rule.id}".',
            'rule_evaluation_exception',
          ),
        );
      }

      for (final finding in ruleFindings) {
        // Enforce evidence integrity and rule contract invariants
        try {
          EvidenceValidator.validateFinding(
            finding,
            snapshot,
            expectedProducerId: rule.id,
            expectedCategoryId: rule.category.id,
          );
        } catch (_) {
          return Result.failure(
            AnalysisFailure.malformedData(
              'Local rule "${rule.id}" produced finding with invalid evidence references or mismatched metadata.',
              'rule_evidence_violation',
            ),
          );
        }

        accumulatedFindings.add(finding);

        // Enforce finding limit bound
        if (accumulatedFindings.length > maxFindings) {
          return Result.failure(
            AnalysisFailure.unsupportedInput(
              'Maximum finding limit ($maxFindings) exceeded during rule evaluation.',
              'max_findings_exceeded',
            ),
          );
        }
      }

      for (final limitation in rule.limitations) {
        if (!collectedLimitations.contains(limitation)) {
          collectedLimitations.add(limitation);
        }
      }
    }

    // 3. Detect duplicate finding IDs across distinct rules
    final seenFindingIds = <String>{};
    for (final finding in accumulatedFindings) {
      if (!seenFindingIds.add(finding.id)) {
        return Result.failure(
          AnalysisFailure.malformedData(
            'Duplicate finding ID "${finding.id}" detected across evaluated rules.',
            'duplicate_finding_id',
          ),
        );
      }
    }

    // 4. Deterministic sorting:
    //    Primary: Evidence start offset ascending (earlier in text first)
    //    Secondary: Evidence end offset descending (longer span first)
    //    Tertiary: Category identifier alphabetically
    //    Quaternary: Producer ID alphabetically
    //    Quinary: Finding ID alphabetically
    accumulatedFindings.sort((a, b) {
      final aStart = a.evidence.first.startOffset;
      final bStart = b.evidence.first.startOffset;
      if (aStart != bStart) return aStart.compareTo(bStart);

      final aEnd = a.evidence.first.endOffset;
      final bEnd = b.evidence.first.endOffset;
      if (aEnd != bEnd) return bEnd.compareTo(aEnd);

      final catComp = a.category.compareTo(b.category);
      if (catComp != 0) return catComp;

      final prodComp = a.producerId.compareTo(b.producerId);
      if (prodComp != 0) return prodComp;

      return a.id.compareTo(b.id);
    });

    // 5. Construct immutable report
    final report = AnalysisReport(
      id: 'report-${_idGenerator()}',
      snapshot: snapshot,
      analyzedAt: _clock().toUtc(),
      findings: accumulatedFindings,
      limitations: collectedLimitations,
      suggestedActions: collectedActions,
    );

    return Result.success(report);
  }

  static DateTime _defaultClock() => DateTime.now().toUtc();

  static String _defaultIdGenerator() =>
      DateTime.now().toUtc().microsecondsSinceEpoch.toString();
}
