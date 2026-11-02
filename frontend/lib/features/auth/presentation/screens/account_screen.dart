import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/auth/data/services/avatar_image_service.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/user_profile.dart';
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
        const SizedBox(height: AppSpacing.pagePaddingMedium),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Privacy & Retention',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage local data retention policies, clear cached images, and delete guest reports stored on this device.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              AppButton.secondary(
                label: 'Open Privacy Center',
                icon: Icons.privacy_tip_outlined,
                onPressed: () => Get.toNamed(AppRoutes.privacy),
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
                    _buildAvatarWidget(theme, profile, user),
                    const SizedBox(width: 14),
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
                    OutlinedButton.icon(
                      onPressed: () => _showEditProfileDialog(context),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Profile'),
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
                    Expanded(
                      child: Text(
                        '$quota of 15 analysis queries remaining today',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Quotas reset daily at midnight UTC.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.pagePaddingMedium),

          // Cloud Report Backup Card (Module 39)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cloud Report Backup',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            syncEnabled
                                ? 'Enabled (Summary backup)'
                                : 'Disabled (Local only)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: syncEnabled
                                  ? Colors.green
                                  : theme.hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(() {
                      final isSyncing = controller.isSyncing.value;
                      return Semantics(
                        label: 'Cloud Report Backup',
                        child: Switch.adaptive(
                          value: syncEnabled,
                          onChanged: isSyncing
                              ? null
                              : (val) {
                                  if (val) {
                                    controller.toggleCloudSync(true);
                                  } else {
                                    _showDisableSyncDialog(context);
                                  }
                                },
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),

                // Privacy Disclosure Banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.25,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Strict Privacy Protection: Raw message text, images, and evidence quotes are NEVER uploaded. Only metadata summaries (timestamps, category, indicator count) are synced.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (syncEnabled) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Last synced time & Sync Now button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Obx(() {
                          final lastTime = controller.lastSyncTime.value;
                          final text = lastTime != null
                              ? 'Last synced: ${_formatDateTime(lastTime)}'
                              : 'Not synced yet';
                          return Text(
                            text,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          );
                        }),
                      ),
                      Obx(() {
                        final isSyncing = controller.isSyncing.value;
                        return OutlinedButton.icon(
                          onPressed: isSyncing
                              ? null
                              : () async {
                                  final res = await controller.syncNow();
                                  if (res != null) {
                                    Get.snackbar(
                                      'Sync Complete',
                                      'Uploaded ${res.pushedCount} summaries, checked ${res.pulledCount} updates.',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  }
                                },
                          icon: isSyncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync, size: 16),
                          label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Delete Cloud Backups action
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Obx(() {
                      final isPurging = controller.isPurgingSync.value;
                      return TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: isPurging
                            ? null
                            : () => _showPurgeCloudBackupsDialog(context),
                        icon: isPurging
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_off, size: 16),
                        label: const Text('Delete Cloud Backups'),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.pagePaddingMedium),

          // Privacy & Data Controls Card (Module 40)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Privacy & Data Controls',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage local report retention periods, purge cloud backups, clear cached images, and review data boundaries.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                AppButton.secondary(
                  label: 'Open Privacy Center',
                  icon: Icons.privacy_tip_outlined,
                  onPressed: () => Get.toNamed(AppRoutes.privacy),
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
          const SizedBox(height: AppSpacing.pagePaddingMedium),

          // Account Security Card (Password Change)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Password & Security',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showChangePasswordDialog(context),
                      icon: const Icon(Icons.lock_reset, size: 16),
                      label: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Update your account password with fresh authentication verification.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final success = await controller.sendPasswordResetEmail();
                    if (success) {
                      Get.snackbar(
                        'Reset Email Dispatched',
                        'A secure password recovery link has been sent to ${user.email}. Check your inbox to update your password.',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 5),
                      );
                    } else {
                      Get.snackbar(
                        'Error',
                        'Failed to send password reset email. Please try again.',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    }
                  },
                  icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                  label: const Text('Send Password Reset Email'),
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

  Widget _buildAvatarWidget(ThemeData theme, UserProfile? profile, dynamic user) {
    const double size = 52;
    final avatarUrl = profile?.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _buildFallbackAvatar(theme, profile, user, size),
        ),
      );
    }
    return _buildFallbackAvatar(theme, profile, user, size);
  }

  Widget _buildFallbackAvatar(
    ThemeData theme,
    UserProfile? profile,
    dynamic user,
    double size,
  ) {
    final name = profile?.displayName?.trim();
    String initials = '';
    if (name != null && name.isNotEmpty) {
      final parts = name.split(' ');
      if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (name.isNotEmpty) {
        initials = name[0].toUpperCase();
      }
    } else if (user?.email != null && (user.email as String).isNotEmpty) {
      initials = (user.email as String)[0].toUpperCase();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: initials.isNotEmpty
          ? Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            )
          : Icon(
              Icons.person,
              size: size * 0.55,
              color: theme.colorScheme.primary,
            ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final profile = controller.profile.value;
    final textController = TextEditingController(text: profile?.displayName ?? '');
    final formKey = GlobalKey<FormState>();
    final pickedBytes = Rxn<Uint8List>();
    final clearAvatarRx = false.obs;
    final avatarErrorRx = RxnString();
    final isSavingRx = false.obs;

    Get.dialog<void>(
      AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Obx(() {
                    final bytes = pickedBytes.value;
                    final isCleared = clearAvatarRx.value;
                    final currentUrl = profile?.avatarUrl;

                    Widget imageWidget;
                    if (bytes != null) {
                      imageWidget = Image.memory(
                        bytes,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      );
                    } else if (currentUrl != null && !isCleared && currentUrl.isNotEmpty) {
                      imageWidget = Image.network(
                        currentUrl,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildFallbackAvatar(
                          Theme.of(context),
                          profile,
                          controller.user.value,
                          90,
                        ),
                      );
                    } else {
                      imageWidget = _buildFallbackAvatar(
                        Theme.of(context),
                        profile,
                        controller.user.value,
                        90,
                      );
                    }

                    return ClipOval(
                      child: SizedBox(
                        width: 90,
                        height: 90,
                        child: imageWidget,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          final picker = ImagePicker();
                          final xFile = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (xFile != null) {
                            final bytes = await xFile.readAsBytes();
                            final validation = AvatarImageService.validate(bytes);
                            if (validation.isFailure) {
                              avatarErrorRx.value =
                                  validation.failureOrNull?.message;
                            } else {
                              avatarErrorRx.value = null;
                              pickedBytes.value = bytes;
                              clearAvatarRx.value = false;
                            }
                          }
                        } catch (e) {
                          avatarErrorRx.value = 'Failed to select image: $e';
                        }
                      },
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Choose Photo'),
                    ),
                    Obx(() {
                      final hasAvatar = pickedBytes.value != null ||
                          (profile?.avatarPath != null && !clearAvatarRx.value);
                      if (!hasAvatar) return const SizedBox.shrink();
                      return TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () {
                          pickedBytes.value = null;
                          clearAvatarRx.value = true;
                          avatarErrorRx.value = null;
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                      );
                    }),
                  ],
                ),
                Obx(() {
                  final err = avatarErrorRx.value;
                  if (err == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      err,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
                const SizedBox(height: 16),
                TextFormField(
                  controller: textController,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'Enter your preferred name',
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val != null && val.trim().length > 64) {
                      return 'Cannot exceed 64 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Privacy Note: Your avatar is stored in a private, encrypted storage bucket and is only accessible to your authenticated account.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          Obx(() {
            final isSaving = isSavingRx.value;
            return FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        isSavingRx.value = true;
                        final success = await controller.updateProfileData(
                          displayName: textController.text,
                          newAvatarBytes: pickedBytes.value,
                          clearAvatar: clearAvatarRx.value,
                        );
                        isSavingRx.value = false;
                        if (success) {
                          Get.back();
                          Get.snackbar(
                            'Profile Updated',
                            'Your profile details have been saved.',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        } else {
                          avatarErrorRx.value =
                              controller.profileError.value ??
                              'Failed to save profile. Please retry.';
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            );
          }),
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

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final errorRx = RxnString();
    final isSubmitting = false.obs;
    final isCurrentVisible = false.obs;
    final isNewVisible = false.obs;

    Get.dialog<void>(
      AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Obx(() {
                  final err = errorRx.value;
                  if (err == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      err,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
                Obx(
                  () => TextFormField(
                    controller: currentPasswordController,
                    obscureText: !isCurrentVisible.value,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      hintText: 'Enter current password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          isCurrentVisible.value
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            isCurrentVisible.value = !isCurrentVisible.value,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => TextFormField(
                    controller: newPasswordController,
                    obscureText: !isNewVisible.value,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Minimum 6 characters',
                      suffixIcon: IconButton(
                        icon: Icon(
                          isNewVisible.value
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            isNewVisible.value = !isNewVisible.value,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    hintText: 'Re-enter new password',
                  ),
                  validator: (val) {
                    if (val != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          Obx(
            () => FilledButton(
              onPressed: isSubmitting.value
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        isSubmitting.value = true;
                        errorRx.value = null;

                        final user = controller.user.value;
                        if (user == null) {
                          errorRx.value = 'No authenticated user session.';
                          isSubmitting.value = false;
                          return;
                        }

                        // 1. Re-authenticate with current password
                        final reauth = await controller.authRepository
                            .signInWithPassword(
                              email: user.email,
                              password: currentPasswordController.text,
                            );

                        if (reauth.isFailure) {
                          errorRx.value = 'Current password is incorrect.';
                          isSubmitting.value = false;
                          return;
                        }

                        // 2. Update password
                        final updateResult = await controller.authRepository
                            .updatePassword(
                              newPassword: newPasswordController.text,
                            );

                        isSubmitting.value = false;

                        updateResult.when(
                          success: (_) {
                            Get.back();
                            Get.rawSnackbar(
                              title: 'Password Updated',
                              message: 'Your account password has been changed successfully.',
                              duration: const Duration(seconds: 4),
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          },
                          failure: (failure) {
                            errorRx.value = failure.message;
                          },
                        );
                      }
                    },
              child: isSubmitting.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
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

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  void _showDisableSyncDialog(BuildContext context) {
    final theme = Theme.of(context);
    Get.dialog<void>(
      AlertDialog(
        title: const Text('Turn Off Cloud Backup?'),
        content: const Text(
          'Choose what you would like to do with previously synchronized cloud report summaries:\n\n'
          '• Keep cloud copies: Existing summaries remain stored in your cloud account.\n'
          '• Delete cloud copies: Cloud summaries are permanently wiped. Your local reports on this device are untouched.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          OutlinedButton(
            onPressed: () async {
              Get.back();
              await controller.toggleCloudSync(false, purgeCloud: false);
            },
            child: const Text('Keep Cloud Copies'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () async {
              Get.back();
              await controller.toggleCloudSync(false, purgeCloud: true);
            },
            child: const Text('Delete Cloud Copies'),
          ),
        ],
      ),
    );
  }

  void _showPurgeCloudBackupsDialog(BuildContext context) {
    final theme = Theme.of(context);
    Get.dialog<void>(
      AlertDialog(
        title: const Text('Delete Cloud Backups?'),
        content: const Text(
          'This will permanently erase all synchronized report summaries from TrustCue cloud servers.\n\n'
          'All reports saved locally on this device will be 100% preserved.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () async {
              Get.back();
              final success = await controller.purgeCloudBackups();
              if (success) {
                Get.snackbar(
                  'Cloud Backups Deleted',
                  'Cloud report summaries have been erased. Local reports remain intact.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('Delete Cloud Copies'),
          ),
        ],
      ),
    );
  }
}
