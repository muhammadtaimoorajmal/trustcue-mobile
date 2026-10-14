/// Stable indicator category taxonomy for TrustCue scam-indicator observations.
///
/// Principles & Governance:
/// - These categories represent observable patterns and contextual signals,
///   NOT definitive verdicts of malice or fraud.
/// - Ordinary legitimate communications frequently contain one or more of
///   these patterns (e.g. legitimate bank alerts, urgent flight updates,
///   job recruiters, promotional prize draws, or password reset requests).
/// - A matching phrase or structural feature alone NEVER proves deception,
///   impersonation, or malicious intent.
/// - Stable [id] strings are decoupled from user-facing [label]s to ensure
///   future localization and display enhancements never alter persistent
///   finding identifiers or serialized representations.
enum IndicatorCategory {
  /// Language creating immediate panic, manufactured deadlines, or artificial urgency.
  urgencyOrPressure(
    id: 'urgency_or_pressure',
    label: 'Urgency or pressure',
    description: 'Language creating immediate panic, artificial deadlines, or pressure to act without thinking.',
  ),

  /// Direct solicitation of sensitive account sign-in credentials, passwords, or PINs.
  requestsForCredentials(
    id: 'requests_for_credentials',
    label: 'Requests for credentials',
    description: 'Solicitation of passwords, PINs, usernames, or account sign-in credentials.',
  ),

  /// Solicitation of one-time authentication codes or multi-factor verification tokens.
  requestsForVerificationCodes(
    id: 'requests_for_verification_codes',
    label: 'Requests for verification codes',
    description: 'Solicitation of one-time passcodes, multi-factor authentication tokens, or verification SMS codes.',
  ),

  /// Demands or instructions for financial transfers, prepaid cards, or unusual payment methods.
  requestsForPayment(
    id: 'requests_for_payment',
    label: 'Requests for payment',
    description: 'Demands or instructions for immediate money transfers, gift cards, cryptocurrency, or unconventional fees.',
  ),

  /// Warnings or threats alleging that an account, membership, or service will be closed or penalized.
  accountSuspensionOrThreats(
    id: 'account_suspension_or_threats',
    label: 'Account suspension or account threats',
    description: 'Claims that an account, service, or legal status will be frozen, suspended, or penalized unless immediate action is taken.',
  ),

  /// Claims of representing established organizations, government agencies, tech support, or trusted individuals.
  claimedIdentityOrImpersonation(
    id: 'claimed_identity_or_impersonation',
    label: 'Claimed identity or impersonation cues',
    description: 'Cues claiming representation of official authorities, financial institutions, tech support, or family members in distress.',
  ),

  /// Unsolicited notifications alleging lottery wins, unexpected awards, free giveaways, or sweepstakes prizes.
  rewardsOrPrizes(
    id: 'rewards_or_prizes',
    label: 'Rewards or prizes',
    description: 'Unsolicited announcements of lottery wins, unexpected jackpots, promotional gifts, or unclaimed funds.',
  ),

  /// Unsolicited job recruitments, work-from-home offers, or recruitment requiring initial payments.
  jobOrRecruitmentOffers(
    id: 'job_or_recruitment_offers',
    label: 'Job or recruitment offers',
    description: 'Unsolicited high-paying job opportunities, minimal-effort tasks, or recruitment requiring upfront purchases or advance fees.',
  ),

  /// Guarantees of high-yield returns, risk-free investments, or rapid financial accumulation.
  investmentOrReturnPromises(
    id: 'investment_or_return_promises',
    label: 'Investment or return promises',
    description: 'Promises of guaranteed returns, risk-free profit schemes, or speculative cryptocurrency investment opportunities.',
  ),

  /// Structural anomalies observed in embedded web links or QR destinations.
  linkStructuralIndicators(
    id: 'link_structural_indicators',
    label: 'Link-related structural indicators',
    description: 'Structural link characteristics such as IP-based hosts, non-standard ports, open redirect parameters, or disguised addresses.',
  );

  const IndicatorCategory({
    required this.id,
    required this.label,
    required this.description,
  });

  /// Stable machine-readable identifier used in serialized findings and contracts.
  final String id;

  /// Human-readable plain-language category name in default English.
  final String label;

  /// Plain-language explanation of what this indicator category observes.
  final String description;

  /// Resolves an [IndicatorCategory] by its stable [id], or returns `null` if unrecognized.
  static IndicatorCategory? fromId(String id) {
    for (final category in IndicatorCategory.values) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}
