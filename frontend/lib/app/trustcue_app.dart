import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_pages.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/contracts/incoming_share_adapter.dart';
import 'package:trustcue_mobile/features/incoming_share/presentation/controllers/incoming_share_coordinator.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

class TrustCueApp extends StatefulWidget {
  const TrustCueApp({
    super.key,
    this.initialRoute,
    this.preferences,
    this.navigatorObservers = const [],
    this.incomingShareAdapter,
    this.incomingShareCoordinator,
    this.authRepository,
  });

  final String? initialRoute;
  final OnboardingPreferences? preferences;
  final List<NavigatorObserver> navigatorObservers;
  final IncomingShareAdapter? incomingShareAdapter;
  final IncomingShareCoordinator? incomingShareCoordinator;
  final AuthRepository? authRepository;

  @override
  State<TrustCueApp> createState() => _TrustCueAppState();
}

class _TrustCueAppState extends State<TrustCueApp> {
  late final AppPages _pages = AppPages(
    widget.preferences ?? LocalOnboardingPreferences(),
    requestedRoute: widget.initialRoute,
  );

  @override
  void initState() {
    super.initState();
    final prefs = widget.preferences ?? LocalOnboardingPreferences();
    if (!Get.isRegistered<IncomingShareCoordinator>()) {
      Get.put<IncomingShareCoordinator>(
        widget.incomingShareCoordinator ??
            IncomingShareCoordinator(
              adapter: widget.incomingShareAdapter,
              preferences: prefs,
            ),
        permanent: true,
      );
    }
    AuthBinding.ensureInitialized(authRepository: widget.authRepository);
  }

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
