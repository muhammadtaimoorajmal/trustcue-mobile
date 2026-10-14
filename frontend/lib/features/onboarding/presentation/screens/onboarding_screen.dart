import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
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
            Icon(
              Icons.shield_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            Text(
              'Understand the signals. Verify before you act.',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            Text(
              'TrustCue is being built to help you examine suspicious digital communication, understand potential warning signs, and choose safer verification steps.',
              style: theme.textTheme.bodyLarge,
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
