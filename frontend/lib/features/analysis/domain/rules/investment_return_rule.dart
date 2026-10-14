import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting promises of guaranteed, risk-free returns
/// or rapid multiplication of funds in English text.
class InvestmentReturnRule implements LocalRule {
  @override
  String get id => 'rule.investment.guaranteed_return';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category =>
      IndicatorCategory.investmentOrReturnPromises;

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  List<String> get limitations => const [
    'English-language heuristic rule; does not detect investment return promises in other languages.',
    'Flags explicit claims of guaranteed or risk-free profits, and rapid capital multiplication promises. General financial news, ordinary savings rate disclosures or risk disclosures, cryptocurrency discussion, and standard investment offerings without guaranteed returns are intentionally not flagged.',
    'Does not provide financial advice or evaluate the market viability of any asset.',
  ];

  static const String _explanation =
      'The message promises guaranteed, risk-free investment returns or rapid multiplication of funds.';

  static final List<RegExp> _patterns = [
    // Guaranteed / risk-free returns or profits
    RegExp(
      r'\b(?:guaranteed|risk[- ]free|100% safe)\b[^\r\n!?]{0,35}\b(?:returns?|profits?|income|investment|payout|yield)\b',
      caseSensitive: false,
    ),
    // Invest / deposit for guaranteed profit
    RegExp(
      r'\b(?:invest|deposit)\b[^\r\n!?]{0,30}\b(?:with guaranteed|for guaranteed|zero risk)\b[^\r\n!?]{0,30}\b(?:returns?|profits?|payout)\b',
      caseSensitive: false,
    ),
    // Rapid capital multiplication in short intervals (e.g. "double your money in 24 hours")
    RegExp(
      r'\b(?:double|triple|multiply|2x|10x)\s+(?:your\s+)?(?:money|investment|funds|deposit|bitcoin|crypto)\b[^\r\n!?]{0,35}\b(?:in|within)\s+(?:\d+[- ](?:hours?|days?|minutes?)|24 hours|48 hours|overnight)\b',
      caseSensitive: false,
    ),
    // Turn $X into $Y rapidly (e.g. "turn $100 into $1000 in 2 days")
    RegExp(
      r'\b(?:invest|turn)\s+(?:\$|usd|eur|gbp)?\s*\d+\s+(?:into|and get)\s+(?:\$|usd|eur|gbp)?\s*\d+\b[^\r\n!?]{0,35}\b(?:in|within)\s+(?:\d+[- ](?:hours?|days?)|24 hours|48 hours|daily)\b',
      caseSensitive: false,
    ),
    // High fixed daily / weekly return claims
    RegExp(
      r'\b(?:earn|guarantee)\s+(?:\d+%\s*(?:daily|every day|per day|weekly)|fixed daily return)\b[^\r\n!?]{0,35}\b(?:on your investment|from your deposit|with our trading bot|crypto trading)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _exclusionPatterns = [
    // Standard risk disclosures, disclaimers, or bank savings yield
    RegExp(
      r'\b(?:past performance is not|investments are subject to|capital at risk|may fluctuate|terms apply|annual percentage yield|apy|savings account interest)\b',
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
