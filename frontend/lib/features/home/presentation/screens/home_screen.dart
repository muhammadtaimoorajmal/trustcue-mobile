import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';

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
            icon: const Icon(Icons.info_outline),
            tooltip: 'About TrustCue',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () {
              if (Get.currentRoute != AppRoutes.about) {
                Get.toNamed(AppRoutes.about);
              }
            },
          ),
        ],
      ),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Understand the signals.',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            Text(
              'Choose how you want to review a suspicious message or link.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Analysis is not available in this development build yet.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.pagePaddingLarge),
            const _InputOptionCard(
              title: 'Message text',
              description: 'For messages copied from SMS, email, or chat.',
              icon: Icons.chat_bubble_outline,
              route: AppRoutes.inputText,
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            const _InputOptionCard(
              title: 'Screenshot',
              description: 'For suspicious messages captured in an image.',
              icon: Icons.image_outlined,
              route: AppRoutes.inputScreenshot,
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            const _InputOptionCard(
              title: 'Link or QR code',
              description: 'For reviewing a destination before opening it.',
              icon: Icons.link_outlined,
              route: AppRoutes.inputLink,
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
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Coming soon',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          AppButton.secondary(
            label: 'View input options',
            onPressed: () {
              if (Get.currentRoute != route) {
                Get.toNamed(route);
              }
            },
          ),
        ],
      ),
    );
  }
}
