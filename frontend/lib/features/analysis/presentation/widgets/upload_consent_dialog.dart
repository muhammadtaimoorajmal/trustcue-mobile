import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/upload_consent.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Modal dialog explicitly soliciting and recording affirmative user consent
/// before transmitting text outside the device for cloud AI analysis.
///
/// Invariants & Security Boundaries:
/// - Explicit consent is required per request; no persistent or blanket upload permissions.
/// - Shows exact reviewed plain text with length so the user can verify redactions.
/// - Discloses recipients: TrustCue backend and Groq Cloud (LPU ephemeral inference).
/// - Discloses zero-retention / no-training policy and TLS transit encryption.
/// - Dismissing or selecting 'Keep on-device only' returns `null`.
class UploadConsentDialog extends StatelessWidget {
  final TextSnapshot snapshot;
  final String? accountId;
  final String provider;

  const UploadConsentDialog({
    super.key,
    required this.snapshot,
    required this.accountId,
    this.provider = UploadConsent.defaultProvider,
  });

  /// Displays the consent dialog and returns [UploadConsent] if affirmatively granted, or `null`.
  static Future<UploadConsent?> show(
    BuildContext context, {
    required TextSnapshot snapshot,
    required String? accountId,
    String provider = UploadConsent.defaultProvider,
  }) {
    return showDialog<UploadConsent?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UploadConsentDialog(
        snapshot: snapshot,
        accountId: accountId,
        provider: provider,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload text for AI review',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Optional cloud-assisted evaluation',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.pagePaddingSmall),

              // Scrollable content area
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Disclosure items
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDisclosureRow(
                              theme,
                              icon: Icons.lock_outline,
                              title: 'Destination & Transit',
                              description: 'Text is encrypted via HTTPS and sent to the TrustCue backend and Groq Cloud LPUs.',
                            ),
                            const SizedBox(height: 8),
                            _buildDisclosureRow(
                              theme,
                              icon: Icons.memory_outlined,
                              title: 'Ephemeral Processing',
                              description: 'Processed in memory solely to analyze potential indicators. Not retained or used to train models.',
                            ),
                            const SizedBox(height: 8),
                            _buildDisclosureRow(
                              theme,
                              icon: Icons.privacy_tip_outlined,
                              title: 'No Images Uploaded',
                              description: 'Only the text shown below is uploaded. Screenshots, images, and device details stay on your phone.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.pagePaddingSmall),

                      // Preview section
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Text to be transmitted:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${snapshot.text.length} characters',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 110),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            snapshot.text,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Disclosure v${UploadConsent.currentDisclosureVersion} • Confirm sensitive details are redacted.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.pagePaddingSmall),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Keep on-device only',
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton.primary(
                      label: 'Agree & send',
                      icon: Icons.arrow_forward,
                      onPressed: () {
                        final consent = UploadConsent.affirmative(
                          snapshot: snapshot,
                          accountId: accountId,
                          provider: provider,
                        );
                        Navigator.of(context).pop(consent);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclosureRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
