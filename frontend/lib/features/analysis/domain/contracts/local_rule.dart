import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Minimal pure-Dart contract for deterministic on-device scam indicator rules.
///
/// Invariants & Rules:
/// - Implementations must be deterministic, pure functions of the provided [TextSnapshot].
/// - Must not perform I/O, network requests, disk operations, isolate spawning,
///   or retain mutable state across evaluations.
/// - Emitted findings must strictly link to the evaluated [TextSnapshot.id] with
///   valid UTF-16 code-unit offsets matching the exact snapshot substring.
/// - Rule identifiers must remain globally unique, stable, and lowercase
///   dot-separated strings (e.g. `rule.urgency.immediate_action`).
abstract class LocalRule {
  /// Globally unique, stable rule identifier.
  String get id;

  /// Semantic version of this rule implementation.
  int get version;

  /// The indicator category family observed by this rule.
  IndicatorCategory get category;

  /// Declared language code limitations (e.g. `['en']`, `['latin']`, or `['*']`).
  List<String> get supportedLanguages;

  /// Declared scope limitations, assumptions, or methodological constraints.
  List<String> get limitations;

  /// Evaluates the immutable [snapshot] text and returns zero or more evidence-backed findings.
  ///
  /// Must be completely side-effect free.
  List<AnalysisFinding> evaluate(TextSnapshot snapshot);
}
