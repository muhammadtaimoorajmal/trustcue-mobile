import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting claims of account suspension,
/// restriction, termination, or punitive legal threats in English text.
class AccountThreatRule implements LocalRule {
  @override
  String get id => 'rule.account.threat_or_suspension';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category =>
      IndicatorCategory.accountSuspensionOrThreats;

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  List<String> get limitations => const [
    'English-language heuristic rule; does not detect account threats in other languages.',
    'Identifies claims of account restriction, termination, or punitive consequences; does not verify actual account status with any service provider.',
    'Does not trigger on unrelated benign uses such as suspending a file download or closing a browser window.',
  ];

  static const String _explanation =
      'Message asserts that an account has been or will be suspended, restricted, or subject to punitive action unless steps are taken.';

  static final List<RegExp> _patterns = [
    // Account status assertion (e.g. "your account has been suspended", "account will be restricted")
    RegExp(
      r'\b(?:your\s+)?account\b[^\r\n.!?]{0,30}\b(?:has been|will be|is|is being)\s+(?:suspended|restricted|blocked|locked|terminated|disabled|frozen|closed)\b',
      caseSensitive: false,
    ),
    // Demands to act to avoid suspension (e.g. "to avoid account suspension", "before account termination")
    RegExp(
      r'\b(?:to avoid|before)\s+(?:account\s+)?(?:suspension|termination|restriction|closure|locking)\b',
      caseSensitive: false,
    ),
    // Threats to take action against account (e.g. "will suspend your account", "terminate your account")
    RegExp(
      r'\b(?:suspend|restrict|terminate|freeze|close|lock)\s+your\s+account\b',
      caseSensitive: false,
    ),
    // Formal threat notices (e.g. "account suspension notice", "account closure warning")
    RegExp(
      r'\baccount\s+(?:suspension|termination|closure|restriction)\s+(?:notice|warning|alert)\b',
      caseSensitive: false,
    ),
    // Legal or law-enforcement consequences (e.g. "legal action will be taken", "arrest warrant will be issued")
    RegExp(
      r'\b(?:legal action|lawsuit|arrest warrant|court summons|police report)\b[^\r\n.!?]{0,35}\b(?:will be taken|issued|filed|initiated)\b',
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
