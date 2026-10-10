import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_pages.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';

class TrustCueApp extends StatelessWidget {
  const TrustCueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TrustCue',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.home,
      getPages: AppPages.pages,
      unknownRoute: AppPages.unknownRoute,
    );
  }
}
