import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/category_educational_context.dart';

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

  static const Map<String, CategoryEducationalContext> _catalog = {
    'urgency_or_pressure': CategoryEducationalContext(
      id: 'edu.urgency_or_pressure',
      categoryId: 'urgency_or_pressure',
      whatObserved: 'The message uses language creating a short deadline, immediate requirement to respond, or consequences if delayed.',
      whyAttention: 'Artificial urgency is frequently used to pressure individuals into taking actions without verifying the request.',
      whatCannotEstablish: 'This check does not determine whether the deadline is genuine, whether the situation is real, or whether the sender has legitimate cause for urgency.',
      independentVerificationStep: 'Pause before reacting. Check account status or communications directly through an independent app or bookmarked website.',
    ),
    'requests_for_credentials': CategoryEducationalContext(
      id: 'edu.requests_for_credentials',
      categoryId: 'requests_for_credentials',
      whatObserved: 'The message requests passwords, PINs, passphrases, or account sign-in credentials.',
      whyAttention: 'Legitimate organizations and service providers rarely ask customers to transmit secret sign-in credentials through messages or forms.',
      whatCannotEstablish: 'This check does not establish whether the sender is authorized, whether the request is part of a password reset flow, or whether an account exists.',
      independentVerificationStep: 'Never send passwords or PINs via text or email. Sign in only through official apps or manually typed website addresses.',
    ),
    'requests_for_verification_codes': CategoryEducationalContext(
      id: 'edu.requests_for_verification_codes',
      categoryId: 'requests_for_verification_codes',
      whatObserved: 'The message solicits one-time passcodes (OTPs), authentication numbers, or multi-factor verification tokens.',
      whyAttention: 'Authentication codes grant temporary access to accounts. Sharing them allows others to complete unauthorized logins or transactions.',
      whatCannotEstablish: 'This check cannot verify whether an authentication session is currently active or who initiated the verification request.',
      independentVerificationStep: 'Do not share verification codes with anyone, including individuals claiming to represent customer support or technical staff.',
    ),
    'requests_for_payment': CategoryEducationalContext(
      id: 'edu.requests_for_payment',
      categoryId: 'requests_for_payment',
      whatObserved: 'The message requests money transfers, payments, gift cards, or unconventional transaction methods.',
      whyAttention: 'Deceptive messages often direct funds to unrecoverable channels such as wire transfers, cryptocurrency, or gift cards.',
      whatCannotEstablish: 'This check does not determine whether an invoice, fee, or debt is authentic, or whether the payment request was solicited.',
      independentVerificationStep: 'Confirm the payment request independently using known contact details or existing billing portals before transferring funds.',
    ),
    'account_suspension_or_threats': CategoryEducationalContext(
      id: 'edu.account_suspension_or_threats',
      categoryId: 'account_suspension_or_threats',
      whatObserved: 'The message warns of impending account suspension, service termination, legal action, or penalties.',
      whyAttention: 'Threats of account loss or penalties create anxiety that can bypass normal caution.',
      whatCannotEstablish: 'This check cannot inspect your actual account standing, subscription status, or whether official action has occurred.',
      independentVerificationStep: 'Sign in to the service directly through its official application or verified website to check your actual account status.',
    ),
    'claimed_identity_or_impersonation': CategoryEducationalContext(
      id: 'edu.claimed_identity_or_impersonation',
      categoryId: 'claimed_identity_or_impersonation',
      whatObserved: 'The message claims representation from an authority, financial institution, government body, or executive.',
      whyAttention: 'Impersonating recognized authorities or institutions is a common technique to establish false credibility.',
      whatCannotEstablish: 'This check cannot authenticate the sender\'s email address, phone number, or organizational affiliation.',
      independentVerificationStep: 'Contact the organization through a publicly verified phone number or directory, not through contact information provided in the message.',
    ),
    'rewards_or_prizes': CategoryEducationalContext(
      id: 'edu.rewards_or_prizes',
      categoryId: 'rewards_or_prizes',
      whatObserved: 'The message announces a prize, lottery win, gift, or financial award requiring recipient action or fees.',
      whyAttention: 'Unsolicited prize notifications often require personal data or processing fees for awards that do not exist.',
      whatCannotEstablish: 'This check does not verify whether you entered a competition, sweepstakes, or loyalty program.',
      independentVerificationStep: 'Verify the prize notification through official competition channels before paying fees or sharing personal information.',
    ),
    'job_or_recruitment_offers': CategoryEducationalContext(
      id: 'edu.job_or_recruitment_offers',
      categoryId: 'job_or_recruitment_offers',
      whatObserved: 'The message offers employment or tasks requiring advance payments, purchases, or promising unusually high pay for minimal effort.',
      whyAttention: 'Employment scams often require job seekers to pay for equipment, training, or starter kits upfront.',
      whatCannotEstablish: 'This check does not verify the hiring status, company registration, or business model of the employer.',
      independentVerificationStep: 'Research the employer independently and apply only through verified company career portals.',
    ),
    'investment_or_return_promises': CategoryEducationalContext(
      id: 'edu.investment_or_return_promises',
      categoryId: 'investment_or_return_promises',
      whatObserved: 'The message promises guaranteed, risk-free returns or rapid capital multiplication.',
      whyAttention: 'Genuine investments always involve risk; promises of guaranteed or risk-free returns are characteristic of fraudulent investment schemes.',
      whatCannotEstablish: 'This check does not assess financial markets, asset viability, or regulatory registration.',
      independentVerificationStep: 'Consult registered financial advisors and verify any investment platform through recognized financial regulatory registries.',
    ),
    'link_structural_indicators': CategoryEducationalContext(
      id: 'edu.link_structural_indicators',
      categoryId: 'link_structural_indicators',
      whatObserved: 'The web link contains unusual structural characteristics, such as an IP address, user-info credentials, punycode, non-standard port, or destination parameter.',
      whyAttention: 'Anomalous link structures can conceal true web destinations or direct users to unexpected domains.',
      whatCannotEstablish: 'This check cannot verify whether the destination website is currently active, safe, or hosting malicious software.',
      independentVerificationStep: 'Do not click unverified links. Navigate to the organization\'s verified domain by typing its web address directly into your browser.',
    ),
  };

  /// Retrieves the educational context for a recognized category, or provides a neutral fallback.
  static CategoryEducationalContext getContext(String categoryId) {
    final context = _catalog[categoryId];
    if (context != null) return context;

    // Neutral fallback for uncataloged or custom categories
    return CategoryEducationalContext(
      id: 'edu.unknown_indicator',
      categoryId: categoryId,
      whatObserved:
          'The message contains an indicator pattern classified under category "$categoryId".',
      whyAttention: 'Unfamiliar or uncataloged indicator patterns warrant careful independent review.',
      whatCannotEstablish: 'This check does not have specific heuristic guidance for this category.',
      independentVerificationStep: 'Exercise caution and verify the communication through an independent channel before proceeding.',
    );
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
