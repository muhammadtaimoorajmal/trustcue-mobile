import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting suspicious job or task offers that combine
/// employment promises with upfront fees, deposits, or minimal-work/high-pay claims.
class JobOfferRule implements LocalRule {
  @override
  String get id => 'rule.job.advance_fee_or_guarantee';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category => IndicatorCategory.jobOrRecruitmentOffers;

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  List<String> get limitations => const [
    'English-language heuristic rule; does not detect job or recruitment patterns in other languages.',
    'Requires contextual combinations of employment/task offers with upfront payment demands, deposits, or minimal-work/high-pay promises. Standard job vacancies, interview invitations, salary figures, and remote work discussions are intentionally not flagged.',
    'Does not evaluate the legal validity or legitimacy of any employer or business.',
  ];

  static const String _explanation =
      'The message offers employment or tasks requiring an upfront payment, deposit, or promising unusually high pay for minimal effort.';

  static final List<RegExp> _patterns = [
    // Job / recruitment + upfront fee / deposit / recharge requirement
    RegExp(
      r'\b(?:job|work|employment|position|hiring|earn|tasks?)\b[^\r\n!?]{0,45}\b(?:registration fee|starter kit|prepay|deposit required|pay to start|buy equipment|recharge (?:balance|account))\b',
      caseSensitive: false,
    ),
    // Reverse: Pay / deposit / recharge to unlock work or earnings
    RegExp(
      r'\b(?:pay|deposit|recharge)\b[^\r\n!?]{0,35}\b(?:to start work|before starting|to unlock (?:tasks?|jobs?|commissions?)|to receive (?:job|work|earnings?))\b',
      caseSensitive: false,
    ),
    // Minimal work / time + high daily earnings promise (e.g. "earn $500 daily for 15 minutes of work")
    RegExp(
      r'\b(?:work|earn|make)\b[^\r\n!?]{0,25}\b(?:\$|usd|eur|gbp)?\s*\d+\s*(?:daily|per day|hourly|a day|weekly|per week)\b[^\r\n!?]{0,40}\b(?:for|with|in)?\s*(?:\d+[- ](?:minutes?|mins?)|minimal (?:work|effort)|no experience|just (?:by )?(?:watching|liking|clicking|rating))\b',
      caseSensitive: false,
    ),
    // Part-time / work from home + high pay for short minutes
    RegExp(
      r'\b(?:part[- ]time|work from home|online job)\b[^\r\n!?]{0,35}\b(?:earn|make)\s+(?:\$|usd|eur|gbp)?\s*\d+\s*(?:daily|per day|per week|a day)\b[^\r\n!?]{0,30}\b(?:in|just)?\s*\d+[- ](?:minutes?|mins?)\b',
      caseSensitive: false,
    ),
    // Task balance / commission release requiring deposit or fee
    RegExp(
      r'\b(?:deposit|transfer|pay)\b[^\r\n!?]{0,35}\b(?:to release|to withdraw|to unlock)\s+(?:your\s+)?(?:commission|earnings|task balance|salary)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _exclusionPatterns = [
    // Legitimate recruitment processes and interview invitations
    RegExp(
      r'\b(?:interview (?:scheduled|invitation|time)|submit your (?:resume|cv)|apply (?:on|at) our careers page|job description|requirements:|offer letter attached|benefits include|health insurance|401k)\b',
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
