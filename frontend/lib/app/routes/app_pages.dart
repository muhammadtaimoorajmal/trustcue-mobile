import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/home/presentation/bindings/home_binding.dart';
import 'package:trustcue_mobile/features/home/presentation/screens/home_screen.dart';

import 'package:trustcue_mobile/features/about/presentation/screens/about_screen.dart';
import 'package:trustcue_mobile/features/not_found/presentation/screens/not_found_screen.dart';

abstract class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(title: 'TrustCue'),
      binding: HomeBinding(),
    ),
    GetPage(name: AppRoutes.about, page: () => const AboutScreen()),
    unknownRoute,
  ];

  static final unknownRoute = GetPage(
    name: AppRoutes.notFound,
    page: () => const NotFoundScreen(),
  );

  /// Exact paths only: queries do not select a different destination, while
  /// trailing slashes and unsupported descendants are not aliases.
  static Route<dynamic> resolve(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '');
    var destination = unknownRoute;
    if (uri != null &&
        !uri.hasScheme &&
        !uri.hasAuthority &&
        !uri.hasFragment) {
      for (final page in pages) {
        if (page.name == uri.path) {
          destination = page;
          break;
        }
      }
    }
    return GetPageRoute<dynamic>(
      settings: RouteSettings(
        name: destination.name,
        arguments: settings.arguments,
      ),
      page: destination.page,
      binding: destination.binding,
      transitionDuration: Get.defaultTransitionDuration,
    );
  }

  static List<Route<dynamic>> initialRoutes(String name) => [
    resolve(RouteSettings(name: name)),
  ];
}
