import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/trustcue_app.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';
import 'package:trustcue_mobile/features/onboarding/presentation/controllers/onboarding_controller.dart';

import '../../support/fake_onboarding_preferences.dart';

void main() {
  const timeout = Timeout(Duration(seconds: 20));
  setUp(() => Get.reset());
  tearDown(() => Get.reset());

  Future<void> start(
    WidgetTester tester,
    FakeOnboardingPreferences store,
  ) async {
    await tester.pumpWidget(TrustCueApp(preferences: store));
    await tester.pumpAndSettle();
  }

  Future<void> acknowledge(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
  }

  Future<void> pressContinue(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Continue to TrustCue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to TrustCue'));
  }

  for (final value in <Object?>[null, 0, -1, '1', true, 1.5, 1, 2]) {
    testWidgets(
      'Startup validates completion value $value (${value.runtimeType})',
      (tester) async {
        final store = FakeOnboardingPreferences(value: value);
        await start(tester, store);
        final complete = value is int && value >= 1;
        expect(
          Get.currentRoute,
          complete ? AppRoutes.home : AppRoutes.onboarding,
        );
        expect(Get.isRegistered<HomeController>(), complete);
        expect(Get.key.currentState!.canPop(), isFalse);
        expect(store.reads, 1);
        expect(store.writes, 0);
      },
      timeout: timeout,
    );
  }

  testWidgets('Loading has no Home flash and failed read offers retry', (
    tester,
  ) async {
    final gate = Completer<void>();
    final store = FakeOnboardingPreferences()
      ..readGate = gate
      ..failRead = true;
    await tester.pumpWidget(TrustCueApp(preferences: store));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(Get.isRegistered<HomeController>(), isFalse);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('couldn’t read'), findsOneWidget);
    store.failRead = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.onboarding);
    expect(store.reads, 2);
  }, timeout: timeout);

  testWidgets(
    'Unchecked cannot save; repeated requests save once before replacement and fresh startup skips',
    (tester) async {
      final store = FakeOnboardingPreferences()..saveGate = Completer<void>();
      await start(tester, store);
      final controller = Get.find<OnboardingController>();
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );
      await controller.complete();
      expect(store.writes, 0);
      await acknowledge(tester);
      await pressContinue(tester);
      final duplicate = controller.complete();
      await tester.pump();
      expect(store.writes, 1);
      expect(Get.currentRoute, AppRoutes.onboarding);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      store.saveGate!.complete();
      await duplicate;
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.home);
      expect(Get.key.currentState!.canPop(), isFalse);
      expect(store.value, 1);
      expect(controller.isClosed, isTrue);
      expect(find.text('Understand the signals.'), findsOneWidget);
      // New root and GetX lifecycle with the same saved data, not a process restart.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      Get.reset();
      await start(tester, store);
      expect(Get.currentRoute, AppRoutes.home);
      expect(find.text('Understand the signals.'), findsOneWidget);
      expect(store.writes, 1);
      expect(store.reads, 2);
    },
    timeout: timeout,
  );

  testWidgets('Save failure stays usable and retry succeeds', (tester) async {
    final store = FakeOnboardingPreferences()..failSave = true;
    await start(tester, store);
    await acknowledge(tester);
    await pressContinue(tester);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.onboarding);
    expect(store.value, isNull);
    expect(find.textContaining('couldn’t save'), findsOneWidget);
    expect(Get.find<OnboardingController>().saving.value, isFalse);
    store.failSave = false;
    await pressContinue(tester);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.home);
    expect(store.writes, 2);
  }, timeout: timeout);

  testWidgets(
    'About review has no acknowledgment, writes, duplicates, or home controller loss',
    (tester) async {
      final store = FakeOnboardingPreferences(value: 1);
      await start(tester, store);
      final home = Get.find<HomeController>();
      await tester.tap(find.byTooltip('About TrustCue'));
      await tester.pumpAndSettle();
      final action = tester
          .widget<AppButton>(find.byType(AppButton))
          .onPressed!;
      await tester.ensureVisible(find.text('Review safe-use guidance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review safe-use guidance'));
      action();
      action();
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.guidance);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Continue to TrustCue'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.about);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.home);
      expect(Get.key.currentState!.canPop(), isFalse);
      expect(Get.find<HomeController>(), same(home));
      expect(find.text('Understand the signals.'), findsOneWidget);
      expect(store.value, 1);
      expect(store.writes, 0);
    },
    timeout: timeout,
  );

  testWidgets(
    'Stalled read becomes retryable and late completion does not navigate',
    (tester) async {
      final gate = Completer<void>();
      final store = FakeOnboardingPreferences(value: 1)..readGate = gate;
      await tester.pumpWidget(TrustCueApp(preferences: store));
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.startup);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.home);
    },
    timeout: timeout,
  );

  testWidgets('Stalled save exits loading without claiming completion', (
    tester,
  ) async {
    final gate = Completer<void>();
    final store = FakeOnboardingPreferences()..saveGate = gate;
    await start(tester, store);
    await acknowledge(tester);
    await pressContinue(tester);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.onboarding);
    expect(find.textContaining('couldn’t save'), findsOneWidget);
    expect(Get.find<OnboardingController>().saving.value, isFalse);
    // A timeout cannot cancel platform I/O; late completion must not navigate.
    gate.complete();
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.onboarding);
    await pressContinue(tester);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.home);
  }, timeout: timeout);

  for (final brightness in Brightness.values) {
    testWidgets('Narrow 200% onboarding is operable in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      await start(tester, FakeOnboardingPreferences());
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        brightness,
      );
      await acknowledge(tester);
      await pressContinue(tester);
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.home);
      expect(tester.takeException(), isNull);
    }, timeout: timeout);
  }
}
