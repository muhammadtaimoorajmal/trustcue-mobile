import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Immutable record of explicit, per-request affirmative user consent to transmit
/// a specific text snapshot outside the device for cloud AI analysis.
///
/// Invariants & Security Boundaries:
/// - Consent is NEVER persistent or blanket; it is strictly scoped to one immutable snapshot.
/// - Editing the reviewed text or creating a new snapshot invalidates previous consent.
/// - Logging out or switching user accounts invalidates previous consent.
/// - Never authorizes uploading screenshots, images, OCR metadata, or clipboard history.
class UploadConsent {
  static const String currentDisclosureVersion = '1.0.0';
  static const String defaultRecipient = 'trustcue-backend';
  static const String defaultProvider = 'groq-cloud';

  final bool granted;
  final String disclosureVersion;
  final DateTime timestamp;
  final String recipient;
  final String provider;
  final String snapshotId;
  final String text;
  final String? accountId;

  const UploadConsent({
    required this.granted,
    this.disclosureVersion = currentDisclosureVersion,
    required this.timestamp,
    this.recipient = defaultRecipient,
    this.provider = defaultProvider,
    required this.snapshotId,
    required this.text,
    this.accountId,
  });

  /// Factory creating valid affirmative consent bound to an immutable text snapshot.
  factory UploadConsent.affirmative({
    required TextSnapshot snapshot,
    required String? accountId,
    String provider = defaultProvider,
  }) {
    return UploadConsent(
      granted: true,
      disclosureVersion: currentDisclosureVersion,
      timestamp: DateTime.now().toUtc(),
      recipient: defaultRecipient,
      provider: provider,
      snapshotId: snapshot.id,
      text: snapshot.text,
      accountId: accountId,
    );
  }

  /// Factory creating an explicit rejection / cancellation of consent.
  factory UploadConsent.declined({
    required TextSnapshot snapshot,
    required String? accountId,
  }) {
    return UploadConsent(
      granted: false,
      disclosureVersion: currentDisclosureVersion,
      timestamp: DateTime.now().toUtc(),
      recipient: defaultRecipient,
      provider: defaultProvider,
      snapshotId: snapshot.id,
      text: snapshot.text,
      accountId: accountId,
    );
  }

  /// Evaluates whether this consent record is strictly valid and binding for
  /// the given [candidateSnapshot] and [candidateAccountId].
  ///
  /// Returns `false` if:
  /// - Consent was not affirmatively granted.
  /// - The snapshot ID does not match.
  /// - The reviewed text was modified (even by 1 character).
  /// - The authenticated account changed or was cleared.
  /// - The disclosure version is outdated or unsupported.
  bool isValidFor(
    TextSnapshot candidateSnapshot, {
    required String? candidateAccountId,
  }) {
    if (!granted) return false;
    if (disclosureVersion != currentDisclosureVersion) return false;
    if (recipient != defaultRecipient) return false;
    if (snapshotId != candidateSnapshot.id) return false;
    if (text != candidateSnapshot.text) return false;
    if (accountId != candidateAccountId) return false;
    return true;
  }

  /// Serializes consent metadata for transmission in `AnalysisAiRequest.consent`.
  Map<String, dynamic> toJson() {
    return {
      'granted': granted,
      'disclosureVersion': disclosureVersion,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'recipient': recipient,
      'provider': provider,
    };
  }
}
