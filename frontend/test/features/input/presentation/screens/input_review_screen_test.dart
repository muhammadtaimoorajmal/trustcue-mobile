import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/review_input.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_review_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_review_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    Get.reset();
  });

  Widget buildTestApp({
    ReviewInput? reviewInput,
    ThemeMode themeMode = ThemeMode.light,
    double textScaleFactor = 1.0,
  }) {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: AppRoutes.inputReview,
      getPages: [
        GetPage(
          name: AppRoutes.home,
          page: () => const Scaffold(body: Text('Home Dashboard')),
        ),
        GetPage(
          name: AppRoutes.inputReview,
          page: () => const InputReviewScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut<InputReviewController>(
              () => InputReviewController(reviewInput: reviewInput),
            );
          }),
        ),
        GetPage(
          name: AppRoutes.guidance,
          page: () => const Scaffold(body: Text('Safe-Use Guidance')),
        ),
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        );
      },
    );
  }

  testWidgets('Renders missing input state when opened without review input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestApp(reviewInput: null));
    await tester.pumpAndSettle();

    expect(find.text('No text to review'), findsOneWidget);
    expect(
      find.text(
        'There is no active message or OCR text ready for review. Prepare a message or select a screenshot first.',
      ),
      findsOneWidget,
    );
    expect(find.text('Back to Home'), findsOneWidget);

    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home Dashboard'), findsOneWidget);
  });

  testWidgets(
    'Renders complete review interface with prepared text and boundary banner',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final snapshot = TextSnapshot(
        id: 'snap-msg-1',
        text: 'Suspicious email from account-security@fakebank.com asking for action.',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 11, 10, 0),
      );
      final input = ReviewInput(snapshot: snapshot, sourceRevision: 'rev-1');

      await tester.pumpWidget(buildTestApp(reviewInput: input));
      await tester.pumpAndSettle();

      // Privacy boundary notice
      expect(
        find.text(
          'Reviewing text does not analyze it or authorize uploading it.',
        ),
        findsOneWidget,
      );

      // Source guidance
      expect(
        find.text(
          'Check the message and remove details you do not want included.',
        ),
        findsOneWidget,
      );

      // Text editor with loaded content
      expect(find.byType(AppTextField), findsOneWidget);
      expect(
        find.text(
          'Suspicious email from account-security@fakebank.com asking for action.',
        ),
        findsWidgets,
      );

      // Character counter
      expect(find.textContaining('10,000 characters'), findsOneWidget);

      // Sensitive detail suggestions section
      expect(find.text('Possible sensitive details'), findsOneWidget);
      expect(find.text('[EMAIL]'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Action buttons
      expect(find.text('Confirm reviewed text'), findsOneWidget);
      expect(find.text('Review safe-use guidance'), findsOneWidget);
    },
  );

  testWidgets('Candidate selection updates preview and confirmation banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final snapshot = TextSnapshot(
      id: 'snap-msg-2',
      text: 'Send info to admin@trusted.org right now.',
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 11, 10, 0),
    );
    final input = ReviewInput(snapshot: snapshot, sourceRevision: 'rev-1');

    await tester.pumpWidget(buildTestApp(reviewInput: input));
    await tester.pumpAndSettle();

    // Checkbox should be unselected initially
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);
    expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

    // Tap checkbox to select email candidate
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);
    expect(find.text('Send info to [EMAIL] right now.'), findsOneWidget);

    // Tap confirm reviewed text
    await tester.tap(find.text('Confirm reviewed text'));
    await tester.pumpAndSettle();

    // Confirmation banner is shown
    expect(
      find.text(
        'Reviewed text is ready on this device. It has not been analyzed or sent anywhere.',
      ),
      findsOneWidget,
    );

    // Confirm button is now disabled
    final confirmButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Confirm reviewed text'),
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('Screenshot source shows comparison fallback when file missing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final snapshot = TextSnapshot(
      id: 'snap-ocr-1',
      text: 'Extracted invoice header',
      source: InputSource.screenshot,
      createdAt: DateTime.utc(2026, 10, 11, 10, 0),
    );
    final input = ReviewInput(
      snapshot: snapshot,
      sourceRevision: 'rev-1',
      imagePath: '/non/existent/path.png',
    );

    await tester.pumpWidget(buildTestApp(reviewInput: input));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Check the extracted text against your screenshot. Words or numbers may have been misread.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Screenshot comparison is unavailable; you can still review and edit the text.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Renders properly in dark mode with 200% text scaling without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final snapshot = TextSnapshot(
        id: 'snap-msg-3',
        text: 'Review message under large accessibility font.',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 11, 10, 0),
      );
      final input = ReviewInput(snapshot: snapshot, sourceRevision: 'rev-1');

      await tester.pumpWidget(
        buildTestApp(
          reviewInput: input,
          themeMode: ThemeMode.dark,
          textScaleFactor: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review text'), findsOneWidget);
      expect(find.text('Confirm reviewed text'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
