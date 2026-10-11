import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

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

  Future<void> _load() async {
    if (!mounted || _reading) return;
    _reading = true;
    setState(() => _loading = true);
    try {
      final value = await widget.preferences.readVersion().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TrustCue')),
    body: AppPageBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _loading
            ? const [
                CircularProgressIndicator(
                  semanticsLabel: 'Loading introduction preference',
                ),
                SizedBox(height: 16),
                Text('Getting TrustCue ready…'),
              ]
            : [
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'We couldn’t read your introduction preference. Please try again.',
                  ),
                ),
                const SizedBox(height: 16),
                AppButton.primary(label: 'Retry', onPressed: _load),
              ],
      ),
    ),
  );
}
