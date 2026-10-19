import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/feedback/domain/models/app_feedback.dart';
import 'package:trustcue_mobile/features/feedback/presentation/widgets/feedback_dialog.dart';
import 'package:trustcue_mobile/features/localization/presentation/widgets/language_selector_dialog.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About TrustCue')),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/branding/logo.png',
                    width: 56,
                    height: 56,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Understand the signals. Verify before you act.',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TrustCue is being built to help people understand potential scam indicators in suspicious digital communication.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Local checks are available. Results are indicators, not a verdict. Cloud analysis, history, and report storage are not available.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton.secondary(
              label: 'User Guide & Safe Practice',
              icon: Icons.help_outline_rounded,
              onPressed: () {
                if (Get.currentRoute != AppRoutes.guide) {
                  Get.toNamed(AppRoutes.guide);
                }
              },
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Review safe-use guidance',
              onPressed: () {
                if (Get.currentRoute != AppRoutes.guidance) {
                  Get.toNamed(AppRoutes.guidance);
                }
              },
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Scam Education Center',
              icon: Icons.school_outlined,
              onPressed: () {
                if (Get.currentRoute != AppRoutes.education) {
                  Get.toNamed(AppRoutes.education);
                }
              },
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Privacy & Data Controls',
              icon: Icons.shield_outlined,
              onPressed: () {
                if (Get.currentRoute != AppRoutes.privacy) {
                  Get.toNamed(AppRoutes.privacy);
                }
              },
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Language / زبان',
              icon: Icons.language,
              onPressed: () => LanguageSelectorDialog.show(context),
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Share anonymous feedback',
              icon: Icons.rate_review_outlined,
              onPressed: () {
                FeedbackDialog.show(
                  context,
                  targetType: FeedbackTargetType.appExperience,
                  targetId: 'general',
                  targetTitle: 'General TrustCue Experience',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
