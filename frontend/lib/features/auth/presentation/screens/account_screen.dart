import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';

class AccountScreen extends GetView<AuthController> {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: AppPageBody(
        child: Obx(() {
          final status = controller.status.value;
          final user = controller.user.value;

          if (status == AuthStatus.unconfigured) {
            return _buildUnconfiguredView(theme);
          }

          if (status == AuthStatus.authenticated && user != null) {
            return _buildAuthenticatedView(theme, user);
          }

          return _buildGuestView(theme);
        }),
      ),
    );
  }

  Widget _buildUnconfiguredView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    color: theme.colorScheme.secondary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cloud Service Not Configured',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Cloud authentication is not configured in this build. '
                'All local scam analysis, text extraction, link inspection, and '
                'evidence review features remain 100% operational on this device.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        AppButton.secondary(
          label: 'Return to Home',
          onPressed: () => Get.offAllNamed(AppRoutes.home),
        ),
      ],
    );
  }

  Widget _buildGuestView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Guest Mode', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'You are currently using TrustCue locally without an account. '
          'Local scam checks, OCR text extraction, and safety rules work '
          'entirely on your device.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Optional Account Access',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'An account allows managing your session and preparing for '
                'optional features in upcoming modules. Signing in is never '
                'required for local analysis.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              AppButton.primary(
                label: 'Sign in',
                onPressed: () => Get.toNamed(AppRoutes.authLogin),
              ),
              const SizedBox(height: 8),
              AppButton.secondary(
                label: 'Create an account',
                onPressed: () => Get.toNamed(AppRoutes.authRegister),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthenticatedView(ThemeData theme, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your Account', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.pagePaddingMedium),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_circle,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.email,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              user.emailVerified
                                  ? Icons.check_circle_outline
                                  : Icons.hourglass_top_outlined,
                              size: 16,
                              color: user.emailVerified
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.emailVerified
                                  ? 'Email verified'
                                  : 'Verification pending',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: user.emailVerified
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'Session Security',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Session credentials are encrypted in local secure storage. '
                'Local analysis drafts and preferences remain isolated on this device.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.pagePaddingLarge),
        AppButton.secondary(
          label: 'Sign out',
          icon: Icons.logout,
          onPressed: () => _confirmSignOut(theme),
        ),
      ],
    );
  }

  void _confirmSignOut(ThemeData theme) {
    Get.dialog<void>(
      AlertDialog(
        title: const Text('Sign out of TrustCue?'),
        content: const Text(
          'Your active session will be cleared on this device. '
          'Your local analysis history, drafts, and preferences will be preserved.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Get.back();
              await controller.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
