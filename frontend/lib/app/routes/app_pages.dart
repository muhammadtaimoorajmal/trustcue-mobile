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
    GetPage(
      name: AppRoutes.about,
      page: () => const AboutScreen(),
    ),
    unknownRoute,
  ];

  static final unknownRoute = GetPage(
    name: AppRoutes.notFound,
    page: () => const NotFoundScreen(),
  );
}
