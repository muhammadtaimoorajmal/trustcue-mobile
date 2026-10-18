import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting explicit recipient-facing prize, lottery,
/// or reward claims that demand action, personal details, or fees to collect.
class RewardClaimRule implements LocalRule {
  @override
  String get id => 'rule.reward.prize_claim';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category => IndicatorCategory.rewardsOrPrizes;

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  List<String> get limitations => const [
    'English-language heuristic rule; does not detect reward or prize claims in other languages.',
    'Flags recipient-facing claims of winning lotteries, prizes, or rewards that demand action, disclosure, or fees to collect. General competition announcements, contest rules, and loyalty programs are intentionally not flagged.',
    'Does not evaluate whether an alleged sweepstakes or drawing actually took place.',
  ];

  static const String _explanation =
      'The message claims the recipient has won a prize, lottery, or reward and requests action, personal information, or a fee to claim it.';

  static final List<RegExp> _patterns = [
    // Winning announcement + call to action / claim demand (e.g. "Congratulations, you won $1,000,000! Click here to claim your prize.", "You won a $500 gift card. Claim here:")
    RegExp(
      r'\b(?:congratulations|you (?:have )?won|you are (?:the|our) (?:lucky )?winner)\b[^\r\n]{0,60}\b(?:claim (?:here|now|today|below|your (?:prize|reward|winnings?|gift|payout))|reply (?:to|with)|click (?:here|below) to claim|fill (?:in|out) (?:the|your) details)\b',
      caseSensitive: false,
    ),
    // Selected / chosen for reward + claim instruction (e.g. "Selected to receive a free $500 gift card, claim immediately.")
    RegExp(
      r'\b(?:selected|chosen)\b[^\r\n!?]{0,45}\b(?:prize|gift card|reward|\$?\d+[\d,]*|lottery|sweepstakes)\b[^\r\n!?]{0,45}\b(?:claim|collect|redeem|verify|reply)\b',
      caseSensitive: false,
    ),
    // Unclaimed refund or money notification (e.g. "You have an unclaimed refund of $1,240")
    RegExp(
      r'\b(?:unclaimed|pending)\s+(?:tax\s+)?(?:refund|payout|settlement|reward)\s+(?:of\s+)?\$?\d+[\d,]*\b',
      caseSensitive: false,
    ),
    // Prize release requiring fee / payment (e.g. "Wire clearance fee to release your lottery winnings.")
    RegExp(
      r'\b(?:pay|send|wire)\b[^\r\n!?]{0,35}\b(?:processing fee|delivery fee|shipping fee|clearance fee|tax)\b[^\r\n!?]{0,35}\b(?:to claim|to receive|to release)\s+(?:your\s+)?(?:lottery\s+)?(?:prize|reward|winnings?|gift)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _exclusionPatterns = [
    // Competition rules, terms, or general sweepstakes announcements
    RegExp(
      r'\b(?:contest rules|terms and conditions|official rules|no purchase necessary|void where prohibited|enter for a chance|earned \d+ points|points balance|rewards program|redeem points for discount)\b',
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
