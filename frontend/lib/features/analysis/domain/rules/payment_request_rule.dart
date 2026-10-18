import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

import 'rule_matcher_utils.dart';

/// Pure-Dart heuristic rule detecting explicit requests to transfer funds,
/// pay fees, or purchase gift cards in English text.
class PaymentRequestRule implements LocalRule {
  @override
  String get id => 'rule.payment.solicitation';

  @override
  int get version => 1;

  @override
  IndicatorCategory get category => IndicatorCategory.requestsForPayment;

  @override
  List<String> get supportedLanguages => const ['en'];

  @override
  List<String> get limitations => const [
    'English-language heuristic rule; does not detect payment requests in other languages.',
    'Identifies explicit requests to transmit funds or purchase gift cards; does not evaluate whether a payment request is legitimate, and does not flag invoices, receipts, or refund notices.',
    'Does not classify payment methods as inherently fraudulent.',
  ];

  static const String _explanation =
      'Message contains an explicit request to send money, make a payment, or purchase gift cards.';

  static final List<RegExp> _patterns = [
    // Money transmission via specific or unconventional rails (e.g. "wire money via Western Union", "send payment through Bitcoin")
    RegExp(
      r'\b(?:wire|transfer|send|pay)\b[^\r\n!?]{0,30}\b(?:money|funds|cash|payment|deposit|fee|balance)\b[^\r\n!?]{0,35}\b(?:via|through|using)?\s*(?:western union|moneygram|wire transfer|bank transfer|cryptocurrency|crypto|bitcoin|btc|usdt|eth|ethereum|cash app|venmo|zelle)\b',
      caseSensitive: false,
    ),
    // Direct rail payment demand with amount, supporting decimal amounts (e.g. "wire $10.50 via MoneyGram")
    RegExp(
      r'\b(?:wire|send|transfer)\s+(?:\$|usd|eur|gbp)?\s*\d+(?:\.\d+)?[^\r\n!?]{0,35}\b(?:via|through|using)?\s*(?:western union|moneygram|wire transfer|cryptocurrency|crypto|bitcoin|btc|usdt|cash app|venmo|zelle)\b',
      caseSensitive: false,
    ),
    // Fee / fine / penalty payment request (e.g. "pay the clearance fee", "pay $1.99 redelivery fee")
    RegExp(
      r'\b(?:send|pay|transfer)\b[^\r\n!?]{0,35}\b(?:the|a|\$?\d+(?:\.\d+)?\s*)?\s*(?:processing fee|clearance fee|advance fee|delivery fee|redelivery fee|rebooking fee|release fee|activation fee|late fee|fee|fine|penalty)\b',
      caseSensitive: false,
    ),
    // Gift card purchase / payment request (e.g. "purchase a $100 Google Play gift card", "pay with Apple gift card")
    RegExp(
      r'\b(?:buy|purchase|send|pay with|pay using)\b[^\r\n!?]{0,30}\b(?:gift cards?|apple gift cards?|google play cards?|steam cards?|itunes cards?|amazon gift cards?)\b',
      caseSensitive: false,
    ),
    // Payment required to claim / release (e.g. "pay $10.50 to release your package")
    RegExp(
      r'\b(?:pay|send)\s+(?:\$|usd|eur|gbp)?\s*\d+(?:\.\d+)?[^\r\n!?]{0,35}\b(?:to claim|to release|to receive|to unlock)\b',
      caseSensitive: false,
    ),
    // Casual or direct request to use payment rail (e.g. "can you Zelle me", "pay via Bitcoin")
    RegExp(
      r'\b(?:can you|please|you can)?\s*(?:zelle|venmo|cash app)\s+(?:me|us|\$?\d+)\b',
      caseSensitive: false,
    ),
    // Demands to pay immediately / today (e.g. "call 1-555-0100 to pay immediately", "please pay today")
    RegExp(
      r'\b(?:to pay|please pay)\s+(?:immediately|today|now|at once|in advance)\b',
      caseSensitive: false,
    ),
    // Avoid fee / penalty (e.g. "avoid a $50 late fee", "avoid late penalty")
    RegExp(
      r'\b(?:avoid|to avoid)\s+(?:a\s+)?(?:\$?\d+(?:\.\d+)?\s*)?(?:late fee|penalty|fine)\b',
      caseSensitive: false,
    ),
    // Deposit demand (e.g. "send deposit today", "pay deposit to secure")
    RegExp(
      r'\b(?:send|pay)\s+(?:a\s+)?deposit\b[^\r\n!?]{0,25}\b(?:today|now|immediately|in advance)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _exclusionPatterns = [
    RegExp(
      r'\b(?:payment received|received payment|thank you for your payment|paid in full|receipt for|refund (?:has been|of)|invoice (?:has been paid|paid))\b',
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
