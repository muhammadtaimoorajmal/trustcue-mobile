import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/home/presentation/bindings/home_binding.dart';
import 'package:trustcue_mobile/features/home/presentation/screens/home_screen.dart';

abstract class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(title: 'TrustCue'),
      binding: HomeBinding(),
    ),
  ];
}
