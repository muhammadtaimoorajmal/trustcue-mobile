import 'package:flutter/material.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/category_educational_context.dart';
import 'package:trustcue_mobile/features/education/domain/models/educational_topic.dart';

/// Central catalog defining educational context and safe next actions
/// for each recognized scam indicator category.
///
/// Principles:
/// - Factual, objective explanations describing what the local rule observed.
/// - Explicit boundaries stating what the check CANNOT establish.
/// - Safe independent verification guidance without country-specific numbers,
///   invented contacts, or unsupported instructions.
/// - Guidance MUST NEVER reuse contacts, emails, or links from suspicious content.
/// - Guidance MUST NEVER interpolate raw passwords, codes, or URL credentials.
/// - Post-action advice is explicitly labeled conditional ("If you already shared...").
class CategoryEducationalCatalog {
  const CategoryEducationalCatalog._();

  static const Map<String, EducationalTopic> _catalog = {
    'urgency_or_pressure': EducationalTopic(
      id: 'edu.urgency_or_pressure',
      categoryId: 'urgency_or_pressure',
      title: 'Urgency or artificial pressure',
      whatObserved: 'The message uses language creating a short deadline, immediate requirement to respond, or consequences if delayed.',
      whyAttention: 'Artificial urgency is frequently used to pressure individuals into taking actions without verifying the request.',
      whatCannotEstablish: 'This check does not determine whether the deadline is genuine, whether the situation is real, or whether the sender has legitimate cause for urgency.',
      independentVerificationStep: 'Pause before reacting. Check account status or communications directly through an independent app or bookmarked website.',
      syntheticSuspiciousExample: 'URGENT: Your account access expires in 15 minutes! To avoid immediate account deactivation, verify now at http://account-update.example.com',
      contrastingOrdinaryExample: 'Reminder: Your appointment with Dr. Taylor is scheduled for tomorrow at 3:00 PM. Reply 1 to confirm or 2 to reschedule.',
      contrastingExplanation: 'Legitimate reminders often state dates or times, but they do not manufacture arbitrary 15-minute deadlines or threaten punitive account destruction.',
      primarySourceTitle:
          'FTC Consumer Advice: How To Recognize and Avoid Phishing Scams',
      primarySourceUrl: 'https://consumer.ftc.gov/articles/how-recognize-and-avoid-phishing-scams',
      reviewDate: 'October 2026',
      icon: Icons.timer_outlined,
    ),
    'requests_for_credentials': EducationalTopic(
      id: 'edu.requests_for_credentials',
      categoryId: 'requests_for_credentials',
      title: 'Requests for credentials',
      whatObserved: 'The message requests passwords, PINs, passphrases, or account sign-in credentials.',
      whyAttention: 'Legitimate organizations and service providers rarely ask customers to transmit secret sign-in credentials through messages or forms.',
      whatCannotEstablish: 'This check does not establish whether the sender is authorized, whether the request is part of a password reset flow, or whether an account exists.',
      independentVerificationStep: 'Never send passwords or PINs via text or email. Sign in only through official apps or manually typed website addresses.',
      syntheticSuspiciousExample: 'Security Notice: We detected an unrecognized login attempt. Please reply with your online banking username and password to secure your account.',
      contrastingOrdinaryExample: 'Your password for Apex Service was successfully changed on Oct 17. If you did not make this change, please reset your password at https://apex.example.com',
      contrastingExplanation: 'Legitimate organizations notify you of security actions, but they never ask you to reply with your secret password or PIN in a message or unverified form.',
      primarySourceTitle: 'NCSC UK: Phishing Spot and Report',
      primarySourceUrl: 'https://www.ncsc.gov.uk/collection/phishing-scams',
      reviewDate: 'October 2026',
      icon: Icons.key_outlined,
    ),
    'requests_for_verification_codes': EducationalTopic(
      id: 'edu.requests_for_verification_codes',
      categoryId: 'requests_for_verification_codes',
      title: 'Requests for verification codes',
      whatObserved: 'The message solicits one-time passcodes (OTPs), authentication numbers, or multi-factor verification tokens.',
      whyAttention: 'Authentication codes grant temporary access to accounts. Sharing them allows others to complete unauthorized logins or transactions.',
      whatCannotEstablish: 'This check cannot verify whether an authentication session is currently active or who initiated the verification request.',
      independentVerificationStep: 'Do not share verification codes with anyone, including individuals claiming to represent customer support or technical staff.',
      syntheticSuspiciousExample: 'Apex Tech Support: A representative needs your 6-digit one-time code to verify your identity and restore your account. Please read back the code now.',
      contrastingOrdinaryExample: '592814 is your verification code for Apex portal. Valid for 10 minutes. Do not share this code with anyone, including Apex staff.',
      contrastingExplanation: 'Genuine authentication codes are generated when you initiate an action, and providers explicitly instruct you never to share the code with anyone.',
      primarySourceTitle: 'CISA: Multi-Factor Authentication Guidance',
      primarySourceUrl:
          'https://www.cisa.gov/secure-our-world/use-strong-passwords',
      reviewDate: 'October 2026',
      icon: Icons.pin_outlined,
    ),
    'requests_for_payment': EducationalTopic(
      id: 'edu.requests_for_payment',
      categoryId: 'requests_for_payment',
      title: 'Requests for payment',
      whatObserved: 'The message requests money transfers, payments, gift cards, or unconventional transaction methods.',
      whyAttention: 'Deceptive messages often direct funds to unrecoverable channels such as wire transfers, cryptocurrency, or gift cards.',
      whatCannotEstablish: 'This check does not determine whether an invoice, fee, or debt is authentic, or whether the payment request was solicited.',
      independentVerificationStep: 'Confirm the payment request independently using known contact details or existing billing portals before transferring funds.',
      syntheticSuspiciousExample: 'NOTICE: You owe an overdue delivery fee of \$18.50. Pay immediately using Apple Gift Cards or Bitcoin to avoid package confiscation: http://pay.example.com',
      contrastingOrdinaryExample: 'Your electricity utility bill of \$65.40 is due on Nov 10. View and pay through your regular online account at https://utility.example.com',
      contrastingExplanation: 'Standard bills use established invoicing cycles and recognized banking portals. Demands for prepaid gift cards, cryptocurrency, or peer-to-peer apps are strong indicators of fraud.',
      primarySourceTitle:
          'FTC Consumer Advice: Paying Scammers with Gift Cards or Crypto',
      primarySourceUrl: 'https://consumer.ftc.gov/articles/paying-scammers',
      reviewDate: 'October 2026',
      icon: Icons.payments_outlined,
    ),
    'account_suspension_or_threats': EducationalTopic(
      id: 'edu.account_suspension_or_threats',
      categoryId: 'account_suspension_or_threats',
      title: 'Account suspension or account threats',
      whatObserved: 'The message warns of impending account suspension, service termination, legal action, or penalties.',
      whyAttention: 'Threats of account loss or penalties create anxiety that can bypass normal caution.',
      whatCannotEstablish: 'This check cannot inspect your actual account standing, subscription status, or whether official action has occurred.',
      independentVerificationStep: 'Sign in to the service directly through its official application or verified website to check your actual account status.',
      syntheticSuspiciousExample: 'FINAL WARNING: Your debit card has been suspended due to suspicious activity. Unlock immediately or legal action will be initiated: http://card-unlock.example.com',
      contrastingOrdinaryExample: 'Your membership renewal payment was unsuccessful. Please update your payment method in your profile settings before Nov 1 to maintain uninterrupted service.',
      contrastingExplanation: 'Legitimate service notices provide reasonable grace periods and direct you to standard in-app settings rather than threatening arrest, legal action, or instant termination.',
      primarySourceTitle: 'APWG Phishing Activity Trends Report',
      primarySourceUrl: 'https://apwg.org/trendsreports/',
      reviewDate: 'October 2026',
      icon: Icons.warning_amber_outlined,
    ),
    'claimed_identity_or_impersonation': EducationalTopic(
      id: 'edu.claimed_identity_or_impersonation',
      categoryId: 'claimed_identity_or_impersonation',
      title: 'Claimed identity or impersonation cues',
      whatObserved: 'The message claims representation from an authority, financial institution, government body, or executive.',
      whyAttention: 'Impersonating recognized authorities or institutions is a common technique to establish false credibility.',
      whatCannotEstablish: 'This check cannot authenticate the sender\'s email address, phone number, or organizational affiliation.',
      independentVerificationStep: 'Contact the organization through a publicly verified phone number or directory, not through contact information provided in the message.',
      syntheticSuspiciousExample: 'This is Officer Davis from the Federal Revenue Department. A warrant has been issued in your name. Call 555-0199 immediately to settle this matter.',
      contrastingOrdinaryExample: 'FastParcel Express: Package tracking #987654321 is scheduled for delivery today between 1 PM and 5 PM. Signature is required upon arrival.',
      contrastingExplanation: 'Legitimate delivery and government services communicate through formal channels and do not threaten arrest over phone or demand callbacks to unknown personal numbers.',
      primarySourceTitle:
          'FTC Consumer Advice: Government and Business Imposter Scams',
      primarySourceUrl: 'https://consumer.ftc.gov/articles/how-avoid-government-imposter-scams',
      reviewDate: 'October 2026',
      icon: Icons.badge_outlined,
    ),
    'rewards_or_prizes': EducationalTopic(
      id: 'edu.rewards_or_prizes',
      categoryId: 'rewards_or_prizes',
      title: 'Rewards or prizes',
      whatObserved: 'The message announces a prize, lottery win, gift, or financial award requiring recipient action or fees.',
      whyAttention: 'Unsolicited prize notifications often require personal data or processing fees for awards that do not exist.',
      whatCannotEstablish: 'This check does not verify whether you entered a competition, sweepstakes, or loyalty program.',
      independentVerificationStep: 'Verify the prize notification through official competition channels before paying fees or sharing personal information.',
      syntheticSuspiciousExample: 'Congratulations! Your phone number won \$25,000 in the National Shopper Lottery! Claim your winnings now by paying a \$50 processing fee at http://claim.example.com',
      contrastingOrdinaryExample: 'Apex Grocery: You earned 120 loyalty points on your purchase today. Your current reward balance is 350 points.',
      contrastingExplanation: 'Genuine loyalty programs reflect actual purchases you made. Legitimate lotteries never require you to pay upfront processing fees or taxes to claim winnings.',
      primarySourceTitle: 'NCSC UK: Spotting Fake Competitions and Prize Draws',
      primarySourceUrl: 'https://www.ncsc.gov.uk',
      reviewDate: 'October 2026',
      icon: Icons.card_giftcard_outlined,
    ),
    'job_or_recruitment_offers': EducationalTopic(
      id: 'edu.job_or_recruitment_offers',
      categoryId: 'job_or_recruitment_offers',
      title: 'Job or recruitment offers',
      whatObserved: 'The message offers employment or tasks requiring advance payments, purchases, or promising unusually high pay for minimal effort.',
      whyAttention: 'Employment scams often require job seekers to pay for equipment, training, or starter kits upfront.',
      whatCannotEstablish: 'This check does not verify the hiring status, company registration, or business model of the employer.',
      independentVerificationStep: 'Research the employer independently and apply only through verified company career portals.',
      syntheticSuspiciousExample: 'Work from home! Earn \$200 to \$500 daily reviewing mobile apps for 1 hour. No experience needed. Purchase our starter training kit for \$49 to begin: http://jobs.example.com',
      contrastingOrdinaryExample: 'Hi Muhammad, thank you for applying for the Software Engineer role at Apex Labs. We would like to invite you to a 30-minute technical discussion.',
      contrastingExplanation: 'Real recruitment is tied to positions you applied for and involves interviews. Legitimate employers never require applicants to pay for training kits, equipment, or starter fees upfront.',
      primarySourceTitle: 'FTC Consumer Advice: Job and Employment Scams',
      primarySourceUrl: 'https://consumer.ftc.gov/articles/job-scams',
      reviewDate: 'October 2026',
      icon: Icons.work_outline,
    ),
    'investment_or_return_promises': EducationalTopic(
      id: 'edu.investment_or_return_promises',
      categoryId: 'investment_or_return_promises',
      title: 'Investment or return promises',
      whatObserved: 'The message promises guaranteed, risk-free returns or rapid capital multiplication.',
      whyAttention: 'Genuine investments always involve risk; promises of guaranteed or risk-free returns are characteristic of fraudulent investment schemes.',
      whatCannotEstablish: 'This check does not assess financial markets, asset viability, or regulatory registration.',
      independentVerificationStep: 'Consult registered financial advisors and verify any investment platform through recognized financial regulatory registries.',
      syntheticSuspiciousExample: 'Guaranteed 300% return in 72 hours! Our automated crypto trading platform has zero risk. Invest \$100 today and receive \$400. Contact us on WhatsApp 555-0144.',
      contrastingOrdinaryExample: 'Apex Investment Fund: Your quarterly portfolio statement is ready to view. Note: Past performance does not guarantee future results. Investments are subject to market risks.',
      contrastingExplanation: 'Real investments carry market risk and are required by regulators to disclose risks. Promises of guaranteed profits, risk-free returns, or rapid doubling are hallmarks of Ponzi and investment fraud.',
      primarySourceTitle:
          'SEC Office of Investor Education: Spotting Investment Fraud',
      primarySourceUrl: 'https://www.investor.gov',
      reviewDate: 'October 2026',
      icon: Icons.trending_up_outlined,
    ),
    'link_structural_indicators': EducationalTopic(
      id: 'edu.link_structural_indicators',
      categoryId: 'link_structural_indicators',
      title: 'Link-related structural indicators',
      whatObserved: 'The web link contains unusual structural characteristics, such as an IP address, user-info credentials, punycode, non-standard port, or destination parameter.',
      whyAttention: 'Anomalous link structures can conceal true web destinations or direct users to unexpected domains.',
      whatCannotEstablish: 'This check cannot verify whether the destination website is currently active, safe, or hosting malicious software.',
      independentVerificationStep: 'Do not click unverified links. Navigate to the organization\'s verified domain by typing its web address directly into your browser.',
      syntheticSuspiciousExample: 'Sign in to update your security preferences: http://192.168.1.1:8080/secure?redirect=http://example.com/login',
      contrastingOrdinaryExample: 'Review our updated terms of service at https://www.example.com/terms-and-conditions',
      contrastingExplanation: 'Legitimate organizations use branded domains with secure HTTPS on standard ports, rather than bare IP addresses, non-standard ports, or hidden destination redirect parameters.',
      primarySourceTitle: 'CISA: Recognizing and Reporting Suspicious Links',
      primarySourceUrl: 'https://www.cisa.gov',
      reviewDate: 'October 2026',
      icon: Icons.link_outlined,
    ),
  };

  /// Retrieves the rich educational topic for a recognized category, or provides a neutral fallback topic.
  static EducationalTopic getTopic(String categoryId) {
    final topic = _catalog[categoryId];
    if (topic != null) return topic;

    // Neutral fallback for uncataloged or custom categories
    return EducationalTopic(
      id: 'edu.unknown_indicator',
      categoryId: categoryId,
      title: 'Uncataloged indicator',
      whatObserved:
          'The message contains an indicator pattern classified under category "$categoryId".',
      whyAttention: 'Unfamiliar or uncataloged indicator patterns warrant careful independent review.',
      whatCannotEstablish: 'This check does not have specific heuristic guidance for this category.',
      independentVerificationStep: 'Exercise caution and verify the communication through an independent channel before proceeding.',
      syntheticSuspiciousExample:
          'Example message demonstrating pattern: "$categoryId".',
      contrastingOrdinaryExample: 'Routine notification without unusual pressure or hidden destinations.',
      contrastingExplanation: 'Ordinary notifications communicate routine information without demanding instant compliance or secrets.',
      primarySourceTitle: 'General Consumer Protection Guidance',
      primarySourceUrl: 'https://consumer.ftc.gov',
      reviewDate: 'October 2026',
      icon: Icons.help_outline,
    );
  }

  /// Retrieves the educational context for a recognized category, or provides a neutral fallback.
  ///
  /// Preserves complete backward compatibility with existing analysis callers.
  static CategoryEducationalContext getContext(String categoryId) {
    return getTopic(categoryId);
  }

  /// Returns all 10 canonical educational topics.
  static List<EducationalTopic> getAllTopics() {
    return _catalog.values.toList();
  }

  /// Generates the deterministic list of recommended actions for a given category and its finding IDs.
  static List<AssessmentAction> getActionsForCategory({
    required String categoryId,
    required List<String> findingIds,
  }) {
    final catIds = [categoryId];
    switch (categoryId) {
      case 'urgency_or_pressure':
        return [
          AssessmentAction(
            id: 'action.pause_before_acting',
            title: 'Pause before responding or acting',
            description: 'Take time to evaluate the request. Do not allow urgency or deadlines to rush you into making decisions.',
            priority: AssessmentActionPriority.immediate,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
        ];

      case 'requests_for_credentials':
        return [
          AssessmentAction(
            id: 'action.protect_credentials',
            title: 'Do not disclose passwords or PINs',
            description: 'Never share passwords, PINs, or sign-in secrets through messages, emails, or unverified links.',
            priority: AssessmentActionPriority.immediate,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
          AssessmentAction(
            id: 'action.post_credential_disclosure',
            title: 'If you already shared credentials',
            description: 'If you already provided a password or PIN, change your password immediately on the official service and enable multi-factor authentication.',
            priority: AssessmentActionPriority.conditional,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
            isConditionalPostAction: true,
          ),
        ];

      case 'requests_for_verification_codes':
        return [
          AssessmentAction(
            id: 'action.protect_verification_codes',
            title: 'Do not share one-time verification codes',
            description: 'Keep one-time authentication passcodes confidential. Legitimate support staff and banks will not ask for your codes.',
            priority: AssessmentActionPriority.immediate,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
          AssessmentAction(
            id: 'action.post_code_disclosure',
            title: 'If you already shared a verification code',
            description: 'If you already shared an authentication code, sign in immediately on the official service, review active sessions, and change your password.',
            priority: AssessmentActionPriority.conditional,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
            isConditionalPostAction: true,
          ),
        ];

      case 'requests_for_payment':
        return [
          AssessmentAction(
            id: 'action.verify_payment_independently',
            title: 'Verify payment requests through independent channels',
            description: 'Confirm any payment instructions directly with the recipient using a known, trusted phone number or billing portal.',
            priority: AssessmentActionPriority.recommended,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
        ];

      case 'account_suspension_or_threats':
        return [
          AssessmentAction(
            id: 'action.pause_before_acting',
            title: 'Pause before responding or acting',
            description: 'Take time to evaluate the request. Do not allow urgency or deadlines to rush you into making decisions.',
            priority: AssessmentActionPriority.immediate,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
          AssessmentAction(
            id: 'action.verify_account_directly',
            title: 'Check account standing through official app or site',
            description: 'Log in to your account through the official application or a manually typed website address to check for alerts.',
            priority: AssessmentActionPriority.recommended,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
        ];

      case 'claimed_identity_or_impersonation':
        return [
          AssessmentAction(
            id: 'action.verify_organization_independently',
            title: 'Verify sender identity independently',
            description: 'Contact the organization using a phone number or website from an independent directory or official card, not from this message.',
            priority: AssessmentActionPriority.recommended,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
        ];

      case 'rewards_or_prizes':
        return [
          AssessmentAction(
            id: 'action.verify_prize_independently',
            title: 'Verify prize claim before sharing details or paying fees',
            description: 'Check official organization channels directly. Legitimate prize organizers do not require advance fees to claim winnings.',
            priority: AssessmentActionPriority.recommended,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
        ];

      case 'job_or_recruitment_offers':
        return [
          AssessmentAction(
            id: 'action.verify_job_channel',
            title: 'Verify job offer through official careers portal',
            description: 'Look up the employer\'s official website independently to check for listed openings before paying fees or sharing documents.',
            priority: AssessmentActionPriority.recommended,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
        ];

      case 'investment_or_return_promises':
        return [
          AssessmentAction(
            id: 'action.investigate_investment_claim',
            title: 'Investigate investment claims through registered advisors',
            description: 'Verify investment opportunities through recognized financial authorities and consult qualified independent advisors.',
            priority: AssessmentActionPriority.recommended,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
        ];

      case 'link_structural_indicators':
        return [
          AssessmentAction(
            id: 'action.inspect_link_destination',
            title: 'Examine web destinations without opening links',
            description: 'Inspect the destination domain carefully. If you need to visit the service, type its official domain directly into your browser.',
            priority: AssessmentActionPriority.recommended,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
        ];

      default:
        // Neutral fallback for uncataloged category
        return [
          AssessmentAction(
            id: 'action.verify_independently',
            title: 'Verify communication independently',
            description: 'Exercise caution and verify the authenticity of this request through a trusted independent channel.',
            priority: AssessmentActionPriority.recommended,
            supportingFindingIds: findingIds,
            supportingCategoryIds: catIds,
          ),
        ];
    }
  }

  /// Default action when completed with no matching indicators.
  static AssessmentAction createGeneralCautionAction() {
    return AssessmentAction(
      id: 'action.general_caution',
      title: 'Continue exercising ordinary caution',
      description: 'No specific indicators were detected by these local checks. Always verify unexpected requests through known trusted channels.',
      priority: AssessmentActionPriority.recommended,
      supportingFindingIds: const [],
      supportingCategoryIds: const [],
    );
  }
}
