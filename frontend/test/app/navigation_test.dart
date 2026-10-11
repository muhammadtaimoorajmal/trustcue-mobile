import '../support/fake_onboarding_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/app/trustcue_app.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
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

  Future<void> increment(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  }

  testWidgets('Normal startup opens Home and increments', (tester) async {
    await start(tester);
    expect(stack.names, [AppRoutes.home]);
    expect(find.text('TrustCue'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    await increment(tester);
  }, timeout: timeout);

  for (final frameworkBack in [false, true]) {
    testWidgets(
      'About returns with ${frameworkBack ? 'framework' : 'app-bar'} back and retains controller',
      (tester) async {
        await start(tester);
        await increment(tester);
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
        expect(find.text('1'), findsOneWidget);
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
      expect(find.text('0'), findsOneWidget);
      await increment(tester);
    }, timeout: timeout);
  }

  testWidgets('Recovery removes About and fallback and retains original Home', (
    tester,
  ) async {
    await start(tester);
    await increment(tester);
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
    expect(find.text('1'), findsOneWidget);
    expect(Get.key.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  }, timeout: timeout);

  testWidgets(
    'Home removal disposes controller and repeated recovery registers a fresh Home',
    (tester) async {
      await start(tester);
      await increment(tester);
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
      expect(find.text('0'), findsOneWidget);
      await increment(tester);
      expect(Get.key.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
    timeout: timeout,
  );

  for (final entry in {
    '/about?source=synthetic': AppRoutes.about,
    '/?source=synthetic': AppRoutes.home,
    '/about/': AppRoutes.notFound,
    '/about/unknown?source=synthetic': AppRoutes.notFound,
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
