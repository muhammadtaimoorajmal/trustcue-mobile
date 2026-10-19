import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';
import 'package:trustcue_mobile/features/reports/data/database/app_database.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_preferences.dart';
import 'package:trustcue_mobile/features/reports/data/services/retention_service.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    required this.preferences,
    this.requestedRoute,
  });
  final OnboardingPreferences preferences;
  final String? requestedRoute;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _loading = true;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _pruneExpiredReportsOnStartup() {
    try {
      final repo = Get.isRegistered<LocalReportRepository>()
          ? Get.find<LocalReportRepository>()
          : AppDatabase.getInstance();
      final prefs = Get.isRegistered<RetentionPreferences>()
          ? Get.find<RetentionPreferences>()
          : LocalRetentionPreferences();
      final service = RetentionService(preferences: prefs, repository: repo);
      unawaited(service.pruneExpiredReports());
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted || _reading) return;
    _reading = true;
    setState(() => _loading = true);
    try {
      final value = await widget.preferences.readVersion().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;

      _pruneExpiredReportsOnStartup();

      // Explicit internal destinations still use the exact resolver. Onboarding
      // is an introduction, not an authorization boundary.
      final destination =
          (widget.requestedRoute == AppRoutes.startup
              ? null
              : widget.requestedRoute) ??
          (OnboardingPreferences.isComplete(value)
              ? AppRoutes.home
              : AppRoutes.onboarding);
      Get.offNamed(destination);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _reading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('TrustCue')),
      body: AppPageBody(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: _loading
                  ? [
                      Semantics(
                        label: 'TrustCue logo',
                        child: Image.asset(
                          'assets/branding/logo.png',
                          width: 72,
                          height: 72,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(
                        semanticsLabel: 'Loading introduction preference',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Getting TrustCue ready…',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ]
                  : [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'We couldn’t read your introduction preference. Please try again.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton.primary(label: 'Retry', onPressed: _load),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
