import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  void _recoverToHome() {
    bool hasHome = false;
    Get.until((route) {
      if (route.settings.name == AppRoutes.home) {
        hasHome = true;
        return true;
      }
      return route.isFirst;
    });

    if (!hasHome) {
      Get.offAllNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The page you requested could not be found.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  AppButton.primary(
                    label: 'Return to Home',
                    onPressed: _recoverToHome,
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
