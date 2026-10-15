import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/register_controller.dart';

class RegisterScreen extends GetView<RegisterController> {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: AppPageBody(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Join TrustCue', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Create an account to manage your session and prepare for future features.',
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
                label: 'Email address',
                hint: 'name@example.com',
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.pagePaddingMedium),
              Obx(
                () => AppTextField(
                  label: 'Password',
                  hint: 'At least 6 characters',
                  helperText: 'Minimum 6 characters',
                  controller: controller.passwordController,
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
                  label: 'Confirm password',
                  controller: controller.confirmPasswordController,
                  obscureText: !controller.isConfirmVisible.value,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => controller.signUp(),
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
                  label: 'Create account',
                  isLoading: controller.isSubmitting.value,
                  onPressed: controller.isSubmitting.value
                      ? null
                      : () => controller.signUp(),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => Get.offNamed(AppRoutes.authLogin),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Get.offAllNamed(AppRoutes.home),
                  child: const Text('Continue as guest'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
