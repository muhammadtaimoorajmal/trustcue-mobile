import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';
import 'package:trustcue_mobile/features/localization/presentation/widgets/language_selector_dialog.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Saved Reports',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () {
              if (Get.currentRoute != AppRoutes.history) {
                Get.toNamed(AppRoutes.history);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Account',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () {
              if (Get.currentRoute != AppRoutes.account) {
                Get.toNamed(AppRoutes.account);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About TrustCue',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () {
              if (Get.currentRoute != AppRoutes.about) {
                Get.toNamed(AppRoutes.about);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onSelected: (value) {
              switch (value) {
                case 'education':
                  if (Get.currentRoute != AppRoutes.education) {
                    Get.toNamed(AppRoutes.education);
                  }
                  break;
                case 'privacy':
                  if (Get.currentRoute != AppRoutes.privacy) {
                    Get.toNamed(AppRoutes.privacy);
                  }
                  break;
                case 'language':
                  LanguageSelectorDialog.show(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'education',
                child: Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Text('Scam Education'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'privacy',
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Text('Privacy & Data'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'language',
                child: Row(
                  children: [
                    Icon(
                      Icons.language,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Text('Language'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/branding/logo.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Understand the signals.',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            Text(
              'Choose how you want to review a suspicious message or link.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Local checks are available. Results are indicators, not a verdict.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.22,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '100% On-Device Local Checks • No Account Required',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.pagePaddingMedium),
            const _InputOptionCard(
              title: 'Message text',
              description: 'For messages copied from SMS, email, or chat. Review and local checks are available on this device.',
              icon: Icons.chat_bubble_outline,
              route: AppRoutes.inputText,
              statusText: 'Local checks available',
              actionLabel: 'Enter message',
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            const _InputOptionCard(
              title: 'Screenshot',
              description: 'For suspicious messages captured in an image. Preview, local text extraction, and local checks are available.',
              icon: Icons.image_outlined,
              route: AppRoutes.inputScreenshot,
              statusText: 'OCR & local checks available',
              actionLabel: 'Choose screenshot',
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            const _InputOptionCard(
              title: 'Link or QR code',
              description: 'For reviewing a destination before opening it. Link inspection, QR decoding, and local checks are available.',
              icon: Icons.link_outlined,
              route: AppRoutes.inputLink,
              statusText: 'Inspection & local checks available',
              actionLabel: 'Inspect link or QR',
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 28,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'home_education_title'.tr,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Practice examples & verification',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'home_education_desc'.tr,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  AppButton.secondary(
                    label: 'home_education_action'.tr,
                    icon: Icons.menu_book_outlined,
                    onPressed: () {
                      if (Get.currentRoute != AppRoutes.education) {
                        Get.toNamed(AppRoutes.education);
                      }
                    },
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
                    'Pause before you act.',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Verify unexpected requests through contact details you already trust. Never share passwords or one-time codes in response to an unverified message.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  AppButton.secondary(
                    label: 'Review safe-use guidance',
                    onPressed: () {
                      if (Get.currentRoute != AppRoutes.guidance) {
                        Get.toNamed(AppRoutes.guidance);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputOptionCard extends StatelessWidget {
  const _InputOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    this.statusText = 'Coming soon',
    this.actionLabel = 'View input options',
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;
  final String? statusText;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 24, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (statusText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        statusText!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: actionLabel,
              onPressed: () {
                if (Get.currentRoute != route) {
                  Get.toNamed(route);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
