import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_pages.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';

class TrustCueApp extends StatelessWidget {
  const TrustCueApp({
    super.key,
    this.initialRoute = AppRoutes.home,
    this.navigatorObservers = const [],
  });

  final String initialRoute;
  final List<NavigatorObserver> navigatorObservers;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TrustCue',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: initialRoute,
      // Supplying getPages would override these factories in GetX 4.7.3.
      onGenerateRoute: AppPages.resolve,
      onGenerateInitialRoutes: AppPages.initialRoutes,
      navigatorObservers: navigatorObservers,
    );
  }
}
