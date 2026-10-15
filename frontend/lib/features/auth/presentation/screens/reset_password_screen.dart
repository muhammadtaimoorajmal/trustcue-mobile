import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/reset_password_controller.dart';

class ResetPasswordScreen extends GetView<ResetPasswordController> {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Update password')),
      body: AppPageBody(
        child: SingleChildScrollView(
          child: Obx(() {
            if (controller.isSuccess.value) {
              return _buildSuccessView(theme);
            }
            return _buildFormView(theme);
          }),
        ),
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Password updated',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Text(
            'Your password has been changed successfully. You can now use your new credentials to sign in.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        AppButton.primary(
          label: 'Continue to sign in',
          onPressed: () => Get.offAllNamed(AppRoutes.authLogin),
        ),
      ],
    );
  }

  Widget _buildFormView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose a new password', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Enter a new password for your account.',
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
        Obx(
          () => AppTextField(
            label: 'New password',
            hint: 'At least 6 characters',
            helperText: 'Minimum 6 characters',
            controller: controller.newPasswordController,
            obscureText: !controller.isPasswordVisible.value,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              icon: Icon(
                controller.isPasswordVisible.value
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              tooltip: controller.isPasswordVisible.value
                  ? 'Hide password'
                  : 'Show password',
              onPressed: controller.togglePasswordVisibility,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingMedium),
        Obx(
          () => AppTextField(
            label: 'Confirm new password',
            controller: controller.confirmPasswordController,
            obscureText: !controller.isConfirmVisible.value,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => controller.updatePassword(),
            suffixIcon: IconButton(
              icon: Icon(
                controller.isConfirmVisible.value
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              tooltip: controller.isConfirmVisible.value
                  ? 'Hide password'
                  : 'Show password',
              onPressed: controller.toggleConfirmVisibility,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        Obx(
          () => AppButton.primary(
            label: 'Save new password',
            isLoading: controller.isSubmitting.value,
            onPressed: controller.isSubmitting.value
                ? null
                : () => controller.updatePassword(),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Get.offAllNamed(AppRoutes.home),
            child: const Text('Cancel and return to home'),
          ),
        ),
      ],
    );
  }
}
