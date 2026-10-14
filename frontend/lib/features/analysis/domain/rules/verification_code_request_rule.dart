import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting requests to disclose or transmit
/// one-time passcodes, verification codes, or 2FA tokens in English text.
class VerificationCodeRequestRule implements LocalRule {
  @override
  String get id => 'rule.verification_code.disclosure_request';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category =>
      IndicatorCategory.requestsForVerificationCodes;

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  List<String> get limitations => const [
    'English-language heuristic rule; does not detect code disclosure requests in other languages.',
    'Requires an explicit request to disclose or transmit a verification code or OTP; delivery of a code or password reset token without a disclosure demand is intentionally not flagged.',
    'Supports reviewed and redacted text placeholders (such as [VERIFICATION CODE]); does not require raw digits.',
  ];

  static const String _explanation =
      'Message requests disclosure or transmission of a one-time verification code, OTP, or two-factor authentication token.';

  static final List<RegExp> _patterns = [
    // Disclosure action + verification code target (e.g. "send me the OTP", "share your verification code")
    RegExp(
      r'\b(?:send|share|reply with|text back|forward|disclose|give|provide|read out|tell me)\b[^\r\n.!?]{0,35}\b(?:the|your|that)?\s*(?:sms|received|phone|\d+[- ]digit|six[- ]digit)?\s*(?:otp|one[- ]time (?:passcode|password|code|pin)|verification code|security code|2fa code|two[- ]factor code|authentication code|login code|\[verification code\]|code)\b',
      caseSensitive: false,
    ),
    // Explicit placeholder match ensuring closing bracket is captured
    RegExp(
      r'\b(?:send|share|reply with|text back|forward|disclose|give|provide|read out|tell me)\b[^\r\n.!?]{0,35}\[verification code\]',
      caseSensitive: false,
    ),
    // Short reply with code demand (e.g. "reply with the code", "send the code back")
    RegExp(
      r'\b(?:reply|send)\b[^\r\n.!?]{0,15}\b(?:with|the)\b[^\r\n.!?]{0,15}\b(?:code|otp|\[verification code\])\b',
      caseSensitive: false,
    ),
    // Target + must be shared/sent (e.g. "OTP must be shared to complete login")
    RegExp(
      r'\b(?:otp|one[- ]time (?:passcode|password|code)|verification code|\[verification code\])\b[^\r\n.!?]{0,30}\b(?:must be shared|needs to be sent|should be sent|reply to me|send it to)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _negationPatterns = [
    RegExp(
      r'\b(?:never|do not|don\x27t|should not|shouldn\x27t|will not|will never|we never|nobody will|we will not)\b',
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
      negationPatterns: _negationPatterns,
    );
  }
}
