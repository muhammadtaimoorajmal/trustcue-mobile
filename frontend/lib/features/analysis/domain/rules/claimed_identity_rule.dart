import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting explicit claims to represent an organization,
/// authority, bank, or support team in an actionable context in English text.
class ClaimedIdentityRule implements LocalRule {
  @override
  String get id => 'rule.impersonation.claimed_authority';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category =>
      IndicatorCategory.claimedIdentityOrImpersonation;

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  List<String> get limitations => const [
    'English-language heuristic rule; does not detect authority or impersonation claims in other languages.',
    'Detects explicit claims to represent an organization, authority, bank, or support team in an actionable context; does not verify sender identity, official domains, or brand ownership.',
    'Brand mentions, email signatures, news articles, or organization references without an actionable demand are intentionally not flagged.',
  ];

  static const String _explanation =
      'The message claims to represent an organization, authority, or support team in an actionable context.';

  static final List<RegExp> _patterns = [
    // Direct representation claim + actionable call (e.g. "We are the security team, please verify", "This is the fraud department calling")
    RegExp(
      r'\b(?:this is|we are|speaking on behalf of|calling from|contacting you from|message from)\s+(?:the|your)?\s*(?:bank|fraud department|security team|support team|technical support|helpdesk|customer service|it department|irs|police|customs|tax authority|law enforcement|federal reserve)\b[^\r\n!?]{0,50}\b(?:please|must|need to|required to|action required|verify|confirm|contact|call back|reply|update|click)\b',
      caseSensitive: false,
    ),
    // Official alert / notice claiming entity representation + action required
    RegExp(
      r'\b(?:official|urgent|important)?\s*(?:alert|notice|notification)\s+(?:from|by)\s+(?:your\s+)?(?:bank|security team|support team|fraud department|it department|customer care)\b[^\r\n!?]{0,45}\b(?:action required|verify|update|confirm|call|click|resolve)\b',
      caseSensitive: false,
    ),
    // Agent / representative impersonation claim in actionable context (e.g. "I am an agent from the fraud department")
    RegExp(
      r'\b(?:i am|i\x27m)\s+(?:an?|the)?\s*(?:agent|representative|officer|investigator|specialist)\s+(?:from|with)\s+(?:the|your)?\s*(?:bank|security|fraud department|support|customer care|police|irs)\b[^\r\n!?]{0,45}\b(?:please|need|contact|verify|confirm|call|assist)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _exclusionPatterns = [
    // News articles, reporting, or third-party discussions
    RegExp(
      r'\b(?:reported that|according to|stated in a press release|in a recent news article|news report)\b',
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
      exclusionPatterns: _exclusionPatterns,
    );
  }
}
