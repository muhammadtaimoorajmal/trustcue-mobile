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
            return _buildAuthenticatedView(context, theme, user);
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

  Widget _buildAuthenticatedView(
    BuildContext context,
    ThemeData theme,
    dynamic user,
  ) {
    final profile = controller.profile.value;
    final displayName = profile?.displayName ?? 'Not set';
    final quota = profile?.quotaRemainingToday ?? 15;
    final syncEnabled = profile?.syncEnabled ?? false;
    final createdDateStr = _formatDate(user.createdAt);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your Account', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.pagePaddingMedium),

          // Identity & Display Name Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 44,
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

                // Display Name row with edit action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Display Name',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showEditDisplayNameDialog(
                        context,
                        profile?.displayName,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // User ID
                Text(
                  'User ID',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  user.id,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 12),

                // Account Created Timestamp
                Text(
                  'Member since',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(createdDateStr, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.pagePaddingMedium),

          // Services & Quota Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protected Cloud AI Quota',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.bolt_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$quota of 15 analysis queries remaining today',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Cloud Backup & Sync',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      syncEnabled
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      size: 20,
                      color: syncEnabled ? Colors.green : theme.hintColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      syncEnabled
                          ? 'Sync enabled'
                          : 'Disabled by default (Module 39)',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Quotas, roles, timestamps, and cloud sync policies are protected and cannot be modified.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.pagePaddingMedium),

          // Session Security Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

          // Sign out Button
          AppButton.secondary(
            label: 'Sign out',
            icon: Icons.logout,
            onPressed: () => _confirmSignOut(theme),
          ),
          const SizedBox(height: AppSpacing.pagePaddingMedium),

          // Delete Account Button (Destructive)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.6),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete Account'),
            onPressed: () => _showAccountDeletionDialog(context),
          ),
          const SizedBox(height: AppSpacing.pagePaddingLarge),
        ],
      ),
    );
  }

  void _showEditDisplayNameDialog(BuildContext context, String? currentName) {
    final textController = TextEditingController(text: currentName ?? '');
    final formKey = GlobalKey<FormState>();

    Get.dialog<void>(
      AlertDialog(
        title: const Text('Edit Display Name'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: textController,
                maxLength: 64,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Enter a name (max 64 characters)',
                  counterText: '',
                ),
                validator: (val) {
                  if (val != null && val.trim().length > 64) {
                    return 'Cannot exceed 64 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final success = await controller.updateDisplayName(
                  textController.text,
                );
                if (success) {
                  Get.back();
                } else {
                  Get.snackbar(
                    'Error',
                    controller.profileError.value ??
                        'Failed to update display name.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAccountDeletionDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final theme = Theme.of(context);
    final errorRx = RxnString();

    Get.dialog<void>(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Expanded(child: Text('Delete Account')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action is irreversible. Please review what happens to your data:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildDisclosureItem(
                theme,
                icon: Icons.cloud_outlined,
                title: 'Hosted Cloud Data',
                description: 'Your server profile, daily AI quota allocation, and encrypted sync data will be permanently wiped from the database.',
              ),
              const SizedBox(height: 8),
              _buildDisclosureItem(
                theme,
                icon: Icons.phone_android_outlined,
                title: 'This Device Storage',
                description: 'All saved analysis reports and history linked to this account on this device will be permanently purged. (Local guest reports remain safe).',
              ),
              const SizedBox(height: 8),
              _buildDisclosureItem(
                theme,
                icon: Icons.hub_outlined,
                title: 'Third-Party AI Diagnostics',
                description: 'AI inference queries previously sent to Groq Cloud may have transient diagnostic logs retained up to 30 days per Groq policy, which cannot be erased immediately by TrustCue.',
              ),
              const SizedBox(height: 16),
              Text(
                'Enter your password to authorize permanent deletion:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              Obx(() {
                final err = errorRx.value;
                if (err == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    err,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          Obx(() {
            final isDeleting = controller.isDeletingAccount.value;
            return FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      final pwd = passwordController.text.trim();
                      if (pwd.isEmpty) {
                        errorRx.value = 'Please enter your password.';
                        return;
                      }
                      final success = await controller.deleteAccount(
                        password: pwd,
                      );
                      if (success) {
                        Get.back();
                        Get.offAllNamed(AppRoutes.home);
                        Get.snackbar(
                          'Account Deleted',
                          'Your account and associated local records have been permanently removed.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      } else {
                        errorRx.value = controller.deletionError.value ?? 'Account deletion failed. Please check credentials.';
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Delete Permanently'),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDisclosureItem(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
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

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
