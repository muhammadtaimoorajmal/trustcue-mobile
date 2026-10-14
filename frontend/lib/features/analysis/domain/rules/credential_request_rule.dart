import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting requests to disclose or transmit
/// account credentials, passwords, PINs, or security answers in English text.
class CredentialRequestRule implements LocalRule {
  @override
  String get id => 'rule.credential.disclosure_request';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category => IndicatorCategory.requestsForCredentials;

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  List<String> get limitations => const [
    'English-language heuristic rule; does not detect credential requests in other languages.',
    'Flags explicit requests to disclose, send, or submit passwords, PINs, or credentials; standard instructions to sign in via official applications are intentionally not flagged.',
    'Does not detect credential solicitation obscured by heavy typosquatting or embedded images.',
    'Does not perform general pronoun resolution; only narrow antecedent patterns such as "[credential] ... but send it to [agent/representative]" are detected.',
  ];

  static const String _explanation =
      'Message requests disclosure or transmission of sensitive account credentials such as passwords, PINs, or security answers.';

  static final List<RegExp> _patterns = [
    // Action verb + credential target (e.g. "reply with your password", "send your PIN")
    RegExp(
      r'\b(?:send|share|provide|reply with|text back|forward|disclose|give|submit|confirm|verify)\b[^\r\n.!?]{0,35}\b(?:your|the)?\s*(?:current|account|login|online|temporary)?\s*(?:password|passcode|atm pin|pin number|pin|security (?:question|questions|answer|answers)|secret answer|login credentials|credentials|seed phrase|recovery phrase|private key)\b',
      caseSensitive: false,
    ),
    // Target + must be shared/sent (e.g. "password must be shared")
    RegExp(
      r'\b(?:password|passcode|pin|credentials)\b[^\r\n.!?]{0,30}\b(?:must be shared|needs to be sent|should be provided|send it to)\b',
      caseSensitive: false,
    ),
    // Input / enter credentials via link or form (e.g. "enter your password at the link")
    RegExp(
      r'\b(?:enter|type|input|submit)\s+(?:your|the)?\s*(?:password|passcode|pin|credentials)\s+(?:here|below|at the link|via the link|in this form)\b',
      caseSensitive: false,
    ),
    // Narrow antecedent pronoun pattern (e.g. "Never share your password, but send it to our agent")
    RegExp(
      r'\b(?:password|passcode|pin|credentials)\b[^\r\n.!?]{0,30}\b(?:but|however|yet)\b[^\r\n.!?]{0,30}\b(?:send|give|forward|provide)\s+it\s+to\b[^\r\n.!?]{0,30}\b(?:us|our|me|the|an?)\s*(?:agent|representative|team|staff|support|number|email)\b',
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
