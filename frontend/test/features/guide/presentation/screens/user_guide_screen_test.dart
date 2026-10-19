import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/guide/presentation/bindings/user_guide_binding.dart';
import 'package:trustcue_mobile/features/guide/presentation/screens/user_guide_screen.dart';
import 'package:trustcue_mobile/features/localization/presentation/translations/app_translations.dart';

void main() {
  tearDown(() {
    Get.reset();
  });

  Widget buildTestApp({Locale locale = const Locale('en', 'US')}) {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      translations: AppTranslations(),
      locale: locale,
      initialRoute: AppRoutes.guide,
      getPages: [
        GetPage(
          name: AppRoutes.guide,
          page: () => const UserGuideScreen(),
          binding: UserGuideBinding(),
        ),
        GetPage(
          name: AppRoutes.inputReview,
          page: () => const Scaffold(body: Text('Review Screen Reached')),
        ),
      ],
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('UserGuideScreen Widget Tests', () {
    testWidgets(
      'renders header, quick start banner, and practice cards in English',
      (tester) async {
        configureViewport(tester);
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Header
        expect(find.text('User Guide'), findsWidgets);
        expect(
          find.text(
            'Step-by-step guidance on how to safely inspect messages, review evidence, and use TrustCue offline.',
          ),
          findsOneWidget,
        );

        // Quick Start Banner
        expect(find.text('Quick Start: 3 Simple Steps'), findsOneWidget);
        expect(find.text('Enter or extract text'), findsOneWidget);
        expect(find.text('Review & redact'), findsOneWidget);
        expect(find.text('Inspect evidence & verify'), findsOneWidget);

        // Safe Guided Practice Section
        expect(find.text('Safe Guided Practice'), findsOneWidget);
        expect(find.text('Urgent Account Suspension Threat'), findsOneWidget);
        expect(find.text('Benign Family Message'), findsOneWidget);

        // 6 Topics Heading
        expect(find.text('Comprehensive Reference Topics'), findsOneWidget);
        expect(find.text('1. Choosing the Right Input'), findsOneWidget);
      },
    );

    testWidgets('expands and collapses topic accordion cards', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Initially section text inside Topic 1 is not rendered
      expect(find.text('Pasting Message Text'), findsNothing);

      // Tap on Topic 1 to expand
      final topicHeader = find.text('1. Choosing the Right Input');
      await tester.ensureVisible(topicHeader);
      await tester.tap(topicHeader);
      await tester.pumpAndSettle();

      // Now section details are visible
      expect(find.text('Pasting Message Text'), findsOneWidget);
      expect(find.text('Selecting a Screenshot'), findsOneWidget);
      expect(find.text('Inspecting a Link'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(topicHeader);
      await tester.pumpAndSettle();

      expect(find.text('Pasting Message Text'), findsNothing);
    });

    testWidgets('tapping Start Practice Check navigates to review', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final startButtons = find.text('Start Practice Check');
      expect(startButtons, findsWidgets);

      // Tap the first practice button (Urgent Account Suspension Threat)
      await tester.ensureVisible(startButtons.first);
      await tester.tap(startButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Review Screen Reached'), findsOneWidget);
    });

    testWidgets('renders correctly in Urdu with proper RTL labels', (
      tester,
    ) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestApp(locale: const Locale('ur', 'PK')));
      await tester.pumpAndSettle();

      expect(find.text('صارف گائیڈ'), findsWidgets);
      expect(find.text('فوری آغاز: 3 آسان مراحل'), findsOneWidget);
      expect(find.text('محفوظ اور عملی رہنمائی'), findsOneWidget);
      expect(find.text('فوری اکاؤنٹ معطلی کی دھمکی'), findsOneWidget);
      expect(find.text('عام گھریلو پیغام'), findsOneWidget);
      expect(find.text('تفصیلی حوالہ جاتی موضوعات'), findsOneWidget);
      expect(find.text('1. درست ان پٹ کا انتخاب'), findsOneWidget);
    });
  });
}
