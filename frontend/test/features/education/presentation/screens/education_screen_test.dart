import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/category_educational_catalog.dart';
import 'package:trustcue_mobile/features/education/domain/models/educational_topic.dart';
import 'package:trustcue_mobile/features/education/presentation/controllers/education_controller.dart';
import 'package:trustcue_mobile/features/education/presentation/screens/education_screen.dart';
import 'package:trustcue_mobile/features/localization/presentation/translations/app_translations.dart';

void main() {
  tearDown(() {
    Get.reset();
  });

  Widget buildTestApp() {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      initialRoute: AppRoutes.education,
      getPages: [
        GetPage(
          name: AppRoutes.education,
          page: () => const EducationScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut<EducationController>(() => EducationController());
          }),
        ),
        GetPage(
          name: AppRoutes.educationTopic,
          page: () {
            final args = Get.arguments as Map<String, dynamic>?;
            final topic = args?['topic'] as EducationalTopic?;
            return Scaffold(
              appBar: AppBar(title: const Text('Topic Detail Mock')),
              body: Center(
                child: Text('Topic: ${topic?.categoryId ?? 'None'}'),
              ),
            );
          },
        ),
      ],
    );
  }

  group('EducationScreen UI Tests', () {
    testWidgets('renders all 10 educational categories offline', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Scam Education Center'), findsWidgets);
      expect(
        find.text(
          'Learn how scam patterns work, why they deserve attention, and how to verify independently.',
        ),
        findsOneWidget,
      );

      // Verify at least the top visible categories are rendered
      expect(find.text('Urgency or artificial pressure'), findsOneWidget);
      expect(find.text('Requests for credentials'), findsOneWidget);

      // Verify all 10 topics exist in catalog
      expect(CategoryEducationalCatalog.getAllTopics().length, equals(10));
    });

    testWidgets('search bar filters topic list and reset restores list', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Impersonation');
      await tester.pumpAndSettle();

      // Urgency should now be filtered out, Claimed identity or impersonation cues visible
      expect(
        find.text('Claimed identity or impersonation cues'),
        findsOneWidget,
      );
      expect(find.text('Urgency or artificial pressure'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // Urgency should be visible again
      expect(find.text('Urgency or artificial pressure'), findsOneWidget);
      expect(find.text('Requests for credentials'), findsOneWidget);
    });

    testWidgets('tapping a topic navigates to topic detail screen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final urgencyItem = find.text('Urgency or artificial pressure');
      expect(urgencyItem, findsOneWidget);

      await tester.tap(urgencyItem);
      await tester.pumpAndSettle();

      expect(find.text('Topic Detail Mock'), findsOneWidget);
      expect(find.text('Topic: urgency_or_pressure'), findsOneWidget);
    });
  });
}
