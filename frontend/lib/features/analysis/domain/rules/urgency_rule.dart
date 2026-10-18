import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting explicit urgency, artificial deadlines,
/// or high-pressure ultimatums in English text.
class UrgencyRule implements LocalRule {
  @override
  String get id => 'rule.urgency.immediate_action';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category => IndicatorCategory.urgencyOrPressure;

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  List<String> get limitations => const [
    'English-language heuristic rule; does not detect urgency in other languages.',
    'Contextual patterns require explicit deadlines, immediate action qualifiers, or ultimatum phrasing; ordinary calendar dates, scheduling, or benign uses of "now" or "today" are intentionally not flagged.',
    'Does not interpret figurative language, sarcasm, or quoted conversation.',
  ];

  static const String _explanation =
      'Message contains phrasing that demands immediate action, imposes an urgent deadline, or conveys a time-sensitive ultimatum.';

  static final List<RegExp> _patterns = [
    // Action verb + immediate qualifier (e.g. "respond immediately", "act right now")
    RegExp(
      r'\b(?:act|respond|reply|verify|confirm|call|click|update|pay|resolve|contact us)\b[^\r\n.!?]{0,35}\b(?:immediately|urgently|right now|at once|without delay)\b',
      caseSensitive: false,
    ),
    // Immediate qualifier + action/attention noun + required/needed (e.g. "immediate attention required")
    RegExp(
      r'\b(?:immediate|urgent)\b[^\r\n.!?]{0,30}\b(?:action|attention|response|verification|update)\b[^\r\n.!?]{0,25}\b(?:required|needed)\b',
      caseSensitive: false,
    ),
    // Action/attention noun + required + immediately (e.g. "action required immediately")
    RegExp(
      r'\b(?:action|response|verification|attention)\b[^\r\n.!?]{0,25}\b(?:required|needed)\b[^\r\n.!?]{0,30}\b(?:immediately|urgently|right now|at once|without delay)\b',
      caseSensitive: false,
    ),
    // Explicit action + short deadline (e.g. "verify your account within 24 hours", "pay within 48h")
    RegExp(
      r'\b(?:respond|reply|verify|confirm|update|pay|act|resolve)\b[^\r\n.!?]{0,35}\b(?:within|in the next)\s+(?:\d+|one|two|three|twenty[- ]four|forty[- ]eight)\s*(?:minutes?|mins?|hours?|hrs?|h)\b',
      caseSensitive: false,
    ),
    // Short deadline + consequence/ultimatum (e.g. "within 24 hours to avoid suspension", "within 24h to avoid")
    RegExp(
      r'\b(?:within|in the next)\s+(?:\d+|one|two|three|twenty[- ]four|forty[- ]eight)\s*(?:minutes?|mins?|hours?|hrs?|h)\b[^\r\n.!?]{0,45}\b(?:or|to avoid|before|otherwise|failure to)\b',
      caseSensitive: false,
    ),
    // Ultimatum / expiring notice (e.g. "final notice before closure", "time is running out")
    RegExp(
      r'\b(?:final|last)\s+(?:notice|warning|reminder)\b[^\r\n.!?]{0,40}\b(?:before|to avoid|or|will be)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:time is running out|clock is ticking|limited time remaining)\b',
      caseSensitive: false,
    ),
    // Standalone or clause-level urgency assertion (e.g. "It's urgent.", "Urgent: please reply", "codes. Urgent.")
    RegExp(
      r'\b(?:it\x27s|this is)\s+urgent\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:urgent|urgently)\b\s*[.!]',
      caseSensitive: false,
    ),
    RegExp(
      r'\burgent\s*:\s*[^\r\n]{1,35}\b',
      caseSensitive: false,
    ),
  ];

  @override
  List<AnalysisFinding> evaluate(TextSnapshot snapshot) {
    return RuleMatcherUtils.evaluatePatterns(
      snapshot: snapshot,
      ruleId: id,
      categoryId: category.id,
      explanation: _explanation,
      patterns: _patterns,
    );
  }
}
