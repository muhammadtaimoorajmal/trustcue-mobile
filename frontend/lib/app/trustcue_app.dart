import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_pages.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

class TrustCueApp extends StatefulWidget {
  const TrustCueApp({
    super.key,
    this.initialRoute,
    this.preferences,
    this.navigatorObservers = const [],
  });

  final String? initialRoute;
  final OnboardingPreferences? preferences;
  final List<NavigatorObserver> navigatorObservers;

  @override
  State<TrustCueApp> createState() => _TrustCueAppState();
}

class _TrustCueAppState extends State<TrustCueApp> {
  late final AppPages _pages = AppPages(
    widget.preferences ?? LocalOnboardingPreferences(),
    requestedRoute: widget.initialRoute,
  );

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TrustCue',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.startup,
      // Supplying getPages would override these factories in GetX 4.7.3.
      onGenerateRoute: _pages.resolve,
      onGenerateInitialRoutes: _pages.initialRoutes,
      navigatorObservers: widget.navigatorObservers,
    );
  }
}
