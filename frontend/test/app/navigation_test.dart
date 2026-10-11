import '../support/fake_onboarding_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/app/trustcue_app.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';

// Observe the real Navigator rather than inferring its stack from visible text.
class StackObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  List<String?> get names =>
      routes.map((route) => route.settings.name).toList();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = routes.indexOf(oldRoute!);
    if (newRoute == null) {
      routes.removeAt(index);
    } else {
      routes[index] = newRoute;
    }
  }
}

void main() {
  const timeout = Timeout(Duration(seconds: 20));
  late StackObserver stack;

  setUp(() {
    Get.reset();
    stack = StackObserver();
  });
  tearDown(() => Get.reset());

  Future<void> start(
    WidgetTester tester, {
    String route = AppRoutes.home,
  }) async {
    await tester.pumpWidget(
      TrustCueApp(
        preferences: FakeOnboardingPreferences(value: 1),
        initialRoute: route,
        navigatorObservers: [stack],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Normal startup opens Home dashboard', (tester) async {
    await start(tester);
    expect(stack.names, [AppRoutes.home]);
    expect(find.text('TrustCue'), findsOneWidget);
    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(Get.isRegistered<HomeController>(), isTrue);
  }, timeout: timeout);

  for (final frameworkBack in [false, true]) {
    testWidgets(
      'About returns with ${frameworkBack ? 'framework' : 'app-bar'} back and retains controller',
      (tester) async {
        await start(tester);
        final controller = Get.find<HomeController>();
        await tester.tap(find.byTooltip('About TrustCue'));
        await tester.pumpAndSettle();
        expect(find.text('About TrustCue'), findsOneWidget);
        expect(stack.names, [AppRoutes.home, AppRoutes.about]);
        if (frameworkBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();
        expect(stack.names, [AppRoutes.home]);
        expect(Get.find<HomeController>(), same(controller));
        expect(controller.isClosed, isFalse);
        expect(find.text('Understand the signals.'), findsOneWidget);
      },
      timeout: timeout,
    );
  }

  testWidgets('Repeated production About actions push only once', (
    tester,
  ) async {
    await start(tester);
    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.info_outline),
    );
    // A pushed route blocks pointer hits. Exercise the actual action repeatedly
    // before pumping, separately from the real UI-tap tests above.
    button.onPressed!();
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(stack.names, [AppRoutes.home, AppRoutes.about]);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(stack.names, [AppRoutes.home]);
    await tester.tap(find.byTooltip('About TrustCue'));
    await tester.pumpAndSettle();
    expect(stack.names, [AppRoutes.home, AppRoutes.about]);
  }, timeout: timeout);

  for (final path in [
    '/does-not-exist',
    '/about/does-not-exist',
    '/not-found',
  ]) {
    testWidgets('Named $path reaches fallback and returns a result after pop', (
      tester,
    ) async {
      await start(tester);
      // Attach the expectation immediately, but await it only after popping.
      final returned = expectLater(
        Get.toNamed<Object?>(path),
        completion('returned'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page unavailable'), findsOneWidget);
      expect(stack.names, [AppRoutes.home, AppRoutes.notFound]);
      Get.back(result: 'returned');
      await tester.pumpAndSettle();
      await returned;
      expect(stack.names, [AppRoutes.home]);
      expect(tester.takeException(), isNull);
    }, timeout: timeout);
  }

  for (final path in ['/does-not-exist', '/about/does-not-exist']) {
    testWidgets('Initial $path reaches fallback without a retained Home', (
      tester,
    ) async {
      await start(tester, route: path);
      expect(find.text('Page unavailable'), findsOneWidget);
      expect(stack.names, [AppRoutes.notFound]);
      expect(Get.isRegistered<HomeController>(), isFalse);
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();
      expect(stack.names, [AppRoutes.home]);
      expect(find.text('Understand the signals.'), findsOneWidget);
      expect(Get.isRegistered<HomeController>(), isTrue);
    }, timeout: timeout);
  }

  testWidgets('Recovery removes About and fallback and retains original Home', (
    tester,
  ) async {
    await start(tester);
    final homeRoute = stack.routes.single;
    final controller = Get.find<HomeController>();
    await tester.tap(find.byTooltip('About TrustCue'));
    await tester.pumpAndSettle();
    final returned = expectLater(
      Get.toNamed('/unsupported'),
      completion(isNull),
    );
    await tester.pumpAndSettle();
    expect(stack.names, [AppRoutes.home, AppRoutes.about, AppRoutes.notFound]);
    final recovery = tester
        .widget<AppButton>(find.byType(AppButton))
        .onPressed!;
    await tester.tap(find.text('Return to Home'));
    recovery();
    recovery();
    await tester.pumpAndSettle();
    await returned;
    expect(stack.routes, [homeRoute]);
    expect(Get.find<HomeController>(), same(controller));
    expect(controller.isClosed, isFalse);
    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(Get.key.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  }, timeout: timeout);

  testWidgets(
    'Home removal disposes controller and repeated recovery registers a fresh Home',
    (tester) async {
      await start(tester);
      final oldController = Get.find<HomeController>();
      final returned = expectLater(
        Get.offAllNamed('/unsupported'),
        completion(isNull),
      );
      await tester.pumpAndSettle();
      expect(stack.names, [AppRoutes.notFound]);
      expect(find.text('Page unavailable'), findsOneWidget);
      expect(Get.isRegistered<HomeController>(), isFalse);
      expect(oldController.isClosed, isTrue);
      final recovery = tester
          .widget<AppButton>(find.byType(AppButton))
          .onPressed!;
      await tester.tap(find.text('Return to Home'));
      recovery();
      recovery();
      await tester.pumpAndSettle();
      await returned;
      expect(stack.names, [AppRoutes.home]);
      expect(Get.find<HomeController>(), isNot(same(oldController)));
      expect(find.text('Understand the signals.'), findsOneWidget);
      expect(Get.isRegistered<HomeController>(), isTrue);
      expect(Get.key.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
    timeout: timeout,
  );

  // Input preparation screens navigation tests
  for (final option in [
    (
      title: 'Message text',
      route: AppRoutes.inputText,
      buttonLabel: 'Enter message',
      noticeText: 'Text preparation is available. Scam analysis is not available in this build yet.',
    ),
    (
      title: 'Screenshot',
      route: AppRoutes.inputScreenshot,
      buttonLabel: 'Choose screenshot',
      noticeText: 'Image preview is available. Text extraction and scam analysis are not available yet.',
    ),
    (
      title: 'Link or QR code',
      route: AppRoutes.inputLink,
      buttonLabel: 'View input options',
      noticeText: 'Coming soon',
    ),
  ]) {
    testWidgets(
      'Input option ${option.title} opens ${option.route} and returns with back',
      (tester) async {
        await start(tester);
        final controller = Get.find<HomeController>();
        await tester.ensureVisible(find.text(option.title));
        await tester.pumpAndSettle();

        // Find the card containing this option and tap its button
        final cardFinder = find.ancestor(
          of: find.text(option.title),
          matching: find.byType(AppCard),
        );
        final buttonFinder = find.descendant(
          of: cardFinder,
          matching: find.text(option.buttonLabel),
        );
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(Get.currentRoute, option.route);
        expect(stack.names, [AppRoutes.home, option.route]);
        expect(find.text(option.title), findsWidgets);
        expect(find.text(option.noticeText), findsOneWidget);
        expect(find.text('Safety reminder'), findsOneWidget);

        // Navigate to guidance from input preparation screen
        await tester.ensureVisible(find.text('Review safe-use guidance'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Review safe-use guidance'));
        await tester.pumpAndSettle();
        expect(Get.currentRoute, AppRoutes.guidance);
        expect(stack.names, [AppRoutes.home, option.route, AppRoutes.guidance]);

        // Pop back to input preparation screen
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(Get.currentRoute, option.route);
        expect(stack.names, [AppRoutes.home, option.route]);

        // Pop back to Home
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(Get.currentRoute, AppRoutes.home);
        expect(stack.names, [AppRoutes.home]);
        expect(Get.find<HomeController>(), same(controller));
        expect(find.text('Understand the signals.'), findsOneWidget);
      },
      timeout: timeout,
    );
  }

  testWidgets(
    'Input screen with no previous route returns deterministically to Home',
    (tester) async {
      await start(tester, route: AppRoutes.inputText);
      expect(Get.currentRoute, AppRoutes.inputText);
      expect(stack.names, [AppRoutes.inputText]);

      // Tap back button when no previous page exists
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.home);
      expect(stack.names, [AppRoutes.home]);
      expect(find.text('Understand the signals.'), findsOneWidget);
    },
    timeout: timeout,
  );

  testWidgets('Rapid repeated input action taps push only once', (
    tester,
  ) async {
    await start(tester);
    final cardFinder = find.ancestor(
      of: find.text('Message text'),
      matching: find.byType(AppCard),
    );
    final buttonFinder = find.descendant(
      of: cardFinder,
      matching: find.byType(AppButton),
    );
    final button = tester.widget<AppButton>(buttonFinder);
    button.onPressed!();
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(stack.names, [AppRoutes.home, AppRoutes.inputText]);
  }, timeout: timeout);

  for (final entry in {
    '/about?source=synthetic': AppRoutes.about,
    '/?source=synthetic': AppRoutes.home,
    '/input/text?source=synthetic': AppRoutes.inputText,
    '/input/screenshot?source=synthetic': AppRoutes.inputScreenshot,
    '/input/link?source=synthetic': AppRoutes.inputLink,
    '/about/': AppRoutes.notFound,
    '/about/unknown?source=synthetic': AppRoutes.notFound,
    '/input/text/': AppRoutes.notFound,
    '/input/text/extra': AppRoutes.notFound,
    '/input/screenshot/': AppRoutes.notFound,
    '/input/link/': AppRoutes.notFound,
    'https://example.invalid/about': AppRoutes.notFound,
    '/about#section': AppRoutes.notFound,
  }.entries) {
    testWidgets('Route policy for ${entry.key}', (tester) async {
      await start(tester, route: entry.key);
      expect(stack.names, [entry.value]);
      expect(Get.currentRoute, entry.value);
      expect(tester.takeException(), isNull);
    }, timeout: timeout);
  }
}
