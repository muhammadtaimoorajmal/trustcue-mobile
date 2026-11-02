import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/profile_setup_controller.dart';

class ProfileSetupScreen extends GetView<ProfileSetupController> {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete profile'),
        automaticallyImplyLeading: false,
      ),
      body: AppPageBody(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to TrustCue!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your email is verified. Choose a display name to personalize your account.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: AppSpacing.pagePaddingLarge),

              // Error display
              Obx(() {
                final error = controller.errorMessage.value;
                if (error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppCard(
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            error,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              AppTextField(
                label: 'Display Name',
                hint: 'e.g. Alex M.',
                helperText: 'Maximum 64 characters',
                controller: controller.displayNameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => controller.saveProfile(),
              ),
              const SizedBox(height: AppSpacing.pagePaddingLarge),

              Obx(
                () => AppButton.primary(
                  label: 'Save & Continue',
                  isLoading: controller.isSubmitting.value,
                  onPressed: controller.isSubmitting.value
                      ? null
                      : () => controller.saveProfile(),
                ),
              ),
              const SizedBox(height: 12),

              Obx(
                () => TextButton(
                  onPressed: controller.isSubmitting.value
                      ? null
                      : controller.skip,
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: Text(
                  'You can change your display name anytime in Account Settings.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
