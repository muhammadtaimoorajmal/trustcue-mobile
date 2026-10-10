import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';

void main() {
  Widget buildTestApp({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(body: child),
    );
  }

  group('AppButton Tests', () {
    testWidgets('Enabled button activation reaches caller', (tester) async {
      int pressCount = 0;
      await tester.pumpWidget(
        buildTestApp(
          child: AppButton.primary(
            label: 'Press Me',
            onPressed: () => pressCount++,
          ),
        ),
      );

      await tester.tap(find.text('Press Me'));
      await tester.pumpAndSettle();

      expect(pressCount, 1);
    });

    testWidgets('Disabled button does not invoke callback', (tester) async {
      int pressCount = 0;
      await tester.pumpWidget(
        buildTestApp(
          child: const AppButton.primary(label: 'Disabled', onPressed: null),
        ),
      );

      final button = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(button).enabled, isFalse);

      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();

      expect(pressCount, 0);
    });

    testWidgets('Loading button shows progress, prevents press, and restores', (
      tester,
    ) async {
      int pressCount = 0;

      Widget buildButton(bool loading) {
        return buildTestApp(
          child: AppButton.primary(
            label: 'Action',
            isLoading: loading,
            onPressed: () => pressCount++,
          ),
        );
      }

      // 1. Initial State (Loading = true)
      await tester.pumpWidget(buildButton(true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Action'));
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Advance bounded frame
      expect(pressCount, 0); // Tap ignored

      // 2. Updated State (Loading = false)
      await tester.pumpWidget(buildButton(false));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(pressCount, 1); // Tap processed
    });

    testWidgets('Meets touch target size', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildTestApp(
          child: AppButton.primary(label: 'Target', onPressed: () {}),
        ),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('AppTextField Tests', () {
    testWidgets('Text entry reaches controller and callback', (tester) async {
      final controller = TextEditingController();
      String callbackValue = '';

      await tester.pumpWidget(
        buildTestApp(
          child: AppTextField(
            label: 'Input',
            controller: controller,
            onChanged: (v) => callbackValue = v,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test Text');
      await tester.pumpAndSettle();

      expect(controller.text, 'Test Text');
      expect(callbackValue, 'Test Text');

      controller.dispose();
    });

    testWidgets('Helper and error text render correctly', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Column(
            children: [
              const AppTextField(
                label: 'Input1',
                helperText: 'Helper message',
              ),
              const AppTextField(
                label: 'Input2',
                errorText: 'Error message',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Helper message'), findsOneWidget);
      expect(find.text('Error message'), findsOneWidget);
    });
  });

  group('AppCard Tests', () {
    testWidgets('Renders child and adapts to dark theme', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          themeMode: ThemeMode.dark,
          child: const AppCard(child: Text('Card Content')),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);

      final cardWidget = tester.widget<Card>(find.byType(Card));
      expect(
        cardWidget.color,
        isNull,
      ); // Falls back to CardThemeData in AppTheme.darkTheme
    });
  });
  group('Accessibility and Scaling', () {
    testWidgets('Components handle 200% text scaling', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400); // Typical phone size
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        buildTestApp(
          child: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
              size: Size(360, 800),
            ),
            child: const SingleChildScrollView(
              child: Column(
                children: [
                  AppButton.primary(label: 'Long text that should wrap if needed'),
                  AppTextField(
                    label: 'Input',
                    helperText: 'A very long helper text to ensure it wraps correctly at 200% scaling on a narrow screen without throwing layout exceptions.',
                  ),
                  AppCard(child: Text('Card with large text')),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
