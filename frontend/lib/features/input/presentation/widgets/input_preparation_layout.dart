import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';

class InputPreparationLayout extends StatelessWidget {
  const InputPreparationLayout({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.unavailabilityNotice,
    required this.methodSafetyGuidance,
  });

  final String title;
  final IconData icon;
  final String description;
  final String unavailabilityNotice;
  final String methodSafetyGuidance;

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.offAllNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Get.offAllNamed(AppRoutes.home);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: BackButton(onPressed: () => _handleBack(context)),
        ),
        body: AppPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
              Text(description, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.pagePaddingLarge),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Coming soon',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      unavailabilityNotice,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.pagePaddingLarge),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safety reminder', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      methodSafetyGuidance,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.pagePaddingLarge),
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
      ),
    );
  }
}
