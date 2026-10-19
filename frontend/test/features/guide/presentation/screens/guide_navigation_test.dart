import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/about/presentation/screens/about_screen.dart';
import 'package:trustcue_mobile/features/home/presentation/bindings/home_binding.dart';
import 'package:trustcue_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:trustcue_mobile/features/localization/presentation/translations/app_translations.dart';

void main() {
  tearDown(() {
    Get.reset();
  });

  group('Guide Navigation Entry Point Tests', () {
    testWidgets(
      'Home screen popup menu contains User Guide option and navigates to /guide',
      (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            theme: AppTheme.lightTheme,
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            initialRoute: AppRoutes.home,
            getPages: [
              GetPage(
                name: AppRoutes.home,
                page: () => const HomeScreen(title: 'TrustCue'),
                binding: HomeBinding(),
              ),
              GetPage(
                name: AppRoutes.guide,
                page: () => const Scaffold(body: Text('User Guide Reached')),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Open the overflow popup menu
        final popupMenuButton = find.byType(PopupMenuButton<String>);
        expect(popupMenuButton, findsOneWidget);
        await tester.tap(popupMenuButton);
        await tester.pumpAndSettle();

        // Find 'User Guide' menu item
        final guideMenuItem = find.text('User Guide');
        expect(guideMenuItem, findsOneWidget);

        // Tap 'User Guide'
        await tester.tap(guideMenuItem);
        await tester.pumpAndSettle();

        expect(find.text('User Guide Reached'), findsOneWidget);
      },
    );

    testWidgets(
      'About screen has User Guide & Safe Practice button and navigates to /guide',
      (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            theme: AppTheme.lightTheme,
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            initialRoute: AppRoutes.about,
            getPages: [
              GetPage(name: AppRoutes.about, page: () => const AboutScreen()),
              GetPage(
                name: AppRoutes.guide,
                page: () => const Scaffold(body: Text('User Guide Reached')),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final guideButton = find.text('User Guide & Safe Practice');
        expect(guideButton, findsOneWidget);

        await tester.tap(guideButton);
        await tester.pumpAndSettle();

        expect(find.text('User Guide Reached'), findsOneWidget);
      },
    );
  });
}
