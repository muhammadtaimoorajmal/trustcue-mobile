import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/core/widgets/illustrations/app_illustrations.dart';
import 'package:trustcue_mobile/features/onboarding/presentation/controllers/onboarding_controller.dart';

enum OnboardingMode { firstRun, review }

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.mode});
  final OnboardingMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          mode == OnboardingMode.firstRun
              ? 'Welcome to TrustCue'
              : 'Safe-use guidance',
        ),
      ),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/branding/logo.png',
                width: 56,
                height: 56,
              ),
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            Text(
              'Understand the signals. Verify before you act.',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            Text(
              'TrustCue helps you examine suspicious digital communication, understand potential warning signs, and choose safer verification steps.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.pagePaddingLarge),

            // Step 1: Evidence Review Card with Illustration
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: const EvidenceReviewIllustration(
                        width: 220,
                        height: 110,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Evidence-grounded analysis',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pinpoints specific patterns—like urgent threats or pressure to pay—and highlights exact words so you understand why a message is flagged.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),

            // Step 2: On-Device Extraction Card with Illustration
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: const TextExtractionIllustration(
                        width: 220,
                        height: 110,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '2. On-device extraction',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Analyzes message text, screenshots, and links locally on your phone without sending your messages anywhere.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),

            // Step 3: Local & Cloud Privacy Boundary Card with Illustration
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: const LocalCloudBoundaryIllustration(
                        width: 240,
                        height: 110,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '3. Private by default',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Core checks require no account. Optional Cloud AI requires an account and your explicit consent for every request.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.pagePaddingLarge),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use guidance with care',
                    style: theme.textTheme.titleLarge,
                  ),
                  for (final point in const [
                    'Warning signs are not proof of fraud. Few warning signs do not guarantee that a message is safe.',
                    'Verify requests through contact details you independently know are official.',
                    'Do not share passwords, verification codes, or payment details in response to an unverified request.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(point, style: theme.textTheme.bodyLarge),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.pagePaddingLarge),
            Text(
              'Local checks are available. Results are indicators, not a verdict.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            Text(
              'Completing this introduction does not authorize uploading your messages or screenshots. Nothing is uploaded by this local workflow.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.pagePaddingLarge),
            if (mode == OnboardingMode.firstRun) _Acknowledgment(),
          ],
        ),
      ),
    );
  }
}

class _Acknowledgment extends GetView<OnboardingController> {
  @override
  Widget build(BuildContext context) => Obx(
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: controller.acknowledged.value,
          onChanged: controller.saving.value
              ? null
              : (value) => controller.acknowledged.value = value ?? false,
          title: const Text(
            'I understand that TrustCue provides guidance, not a guarantee of safety or fraud.',
          ),
        ),
        if (controller.error.value != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Semantics(
              liveRegion: true,
              child: Text(
                controller.error.value!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        const SizedBox(height: 16),
        AppButton.primary(
          label: 'Continue to TrustCue',
          isLoading: controller.saving.value,
          onPressed: controller.acknowledged.value ? controller.complete : null,
        ),
      ],
    ),
  );
}
