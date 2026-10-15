import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/forgot_password_controller.dart';

class ForgotPasswordScreen extends GetView<ForgotPasswordController> {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: AppPageBody(
        child: SingleChildScrollView(
          child: Obx(() {
            if (controller.requestSent.value) {
              return _buildConfirmationView(theme);
            }
            return _buildFormView(theme);
          }),
        ),
      ),
    );
  }

  Widget _buildConfirmationView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Icon(
            Icons.mark_email_read_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset link requested',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'If an account is associated with this email, password reset instructions '
                'have been sent. Tap the link in your email to choose a new password.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'For security, we do not indicate whether an email address is registered.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        AppButton.primary(
          label: 'Return to sign in',
          onPressed: () => Get.offNamed(AppRoutes.authLogin),
        ),
      ],
    );
  }

  Widget _buildFormView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Forgot your password?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Enter your email address and we will send you instructions to reset your password.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        Obx(() {
          final error = controller.errorMessage.value;
          if (error == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppCard(
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
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
          label: 'Email address',
          hint: 'name@example.com',
          controller: controller.emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.sendResetEmail(),
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        Obx(
          () => AppButton.primary(
            label: 'Send reset link',
            isLoading: controller.isSubmitting.value,
            onPressed: controller.isSubmitting.value
                ? null
                : () => controller.sendResetEmail(),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Get.back(),
            child: const Text('Back to sign in'),
          ),
        ),
      ],
    );
  }
}
