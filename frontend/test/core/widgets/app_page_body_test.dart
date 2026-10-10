import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_page_body.dart';

void main() {
  Widget buildTestApp({
    required Widget child,
    EdgeInsets padding = EdgeInsets.zero,
    EdgeInsets viewInsets = EdgeInsets.zero,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          padding: padding,
          viewInsets: viewInsets,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: AppPageBody(child: child)),
      ),
    );
  }

  group('AppPageBody Layout Tests', () {
    testWidgets('Narrow phone viewport applies small padding', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildTestApp(child: const Text('Narrow Content')),
      );

      final paddingWidget = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        paddingWidget.padding.resolve(TextDirection.ltr).left,
        AppSpacing.pagePaddingSmall,
      );

      // Cleanup
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Wider viewport applies large padding and bounds width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(buildTestApp(child: const Text('Wide Content')));

      final paddingWidget = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        paddingWidget.padding.resolve(TextDirection.ltr).left,
        AppSpacing.pagePaddingLarge,
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.byKey(const Key('app_page_body_constrained_box')),
      );
      expect(constrainedBox.constraints.maxWidth, AppSpacing.maxContentWidth);

      // Cleanup
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
      'Short landscape viewport with enlarged text scrolls without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(800, 360);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          buildTestApp(
            textScale: 2.0,
            child: Column(
              children: List.generate(20, (index) => Text('Item $index')),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull); // No overflow exceptions

        // Verify scrollable
        await tester.drag(find.text('Item 1'), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Cleanup
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets('Respects SafeArea insets', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildTestApp(
          padding: const EdgeInsets.only(top: 50, bottom: 20),
          child: const Text('Safe Area Content'),
        ),
      );

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.top, isTrue);
      expect(safeArea.bottom, isTrue);

      // Cleanup
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Keyboard insets allow scrolling to bottom content', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildTestApp(
          viewInsets: const EdgeInsets.only(bottom: 300), // Simulated keyboard
          child: Column(
            children: [
              const SizedBox(height: 600), // Fill space
              const TextField(key: Key('bottom_input')),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to bottom input
      await tester.ensureVisible(find.byKey(const Key('bottom_input')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bottom_input')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Cleanup
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
