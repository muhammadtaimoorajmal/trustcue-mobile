import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/features/home/presentation/controllers/home_controller.dart';
import 'package:trustcue_mobile/features/input/data/services/default_text_recognition_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

import 'package:trustcue_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launch and smoke test', (WidgetTester tester) async {
    final preferences = SharedPreferencesAsync();
    const key = OnboardingPreferences.key;
    final previous = (await preferences.getAll(allowList: {key}))[key];
    addTearDown(() async {
      // Restore just this module's key, including an invalid existing type.
      switch (previous) {
        case null:
          await preferences.remove(key);
        case int value:
          await preferences.setInt(key, value);
        case bool value:
          await preferences.setBool(key, value);
        case double value:
          await preferences.setDouble(key, value);
        case String value:
          await preferences.setString(key, value);
        case List<String> value:
          await preferences.setStringList(key, value);
        default:
          throw StateError(
            'Unexpected preference type; do not clear other preferences.',
          );
      }
    });
    await preferences.setString(key, 'synthetic-invalid-version');
    expect(
      await LocalOnboardingPreferences().readVersion(),
      'synthetic-invalid-version',
    );
    await preferences.remove(key);
    // Launch the application using its main entry point
    app.main();

    // Wait for the app to settle
    await tester.pumpAndSettle();

    expect(find.text('Welcome to TrustCue'), findsOneWidget);
    expect(Get.isRegistered<HomeController>(), isFalse);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue to TrustCue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to TrustCue'));
    await tester.pumpAndSettle();
    expect(await LocalOnboardingPreferences().readVersion(), 1);
    expect(Get.key.currentState!.canPop(), isFalse);

    // Reconstruct startup with the real adapter. This is not a process restart.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    Get.reset();
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to TrustCue'), findsNothing);

    // Verify that the dashboard is visible
    expect(find.text('TrustCue'), findsOneWidget);
    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(find.text('Message text'), findsOneWidget);
    expect(find.text('Screenshot'), findsOneWidget);
    expect(find.text('Link or QR code'), findsOneWidget);

    final controller = Get.find<HomeController>();

    // Verify navigating to an input preparation screen and returning
    final enterMessageFinder = find.widgetWithText(AppButton, 'Enter message');
    await tester.ensureVisible(enterMessageFinder);
    await tester.pumpAndSettle();
    await tester.tap(enterMessageFinder);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.inputText);
    expect(find.text('Message text'), findsWidgets);
    expect(find.text('Safety reminder'), findsOneWidget);

    // Return to Home via back button
    final backFinder = find.byType(BackButton);
    expect(backFinder, findsOneWidget);
    await tester.tap(backFinder);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.home);
    expect(Get.find<HomeController>(), same(controller));
    expect(find.text('Understand the signals.'), findsOneWidget);

    // Verify Home -> About -> Home flow
    final aboutFinder = find.byTooltip('About TrustCue');
    expect(aboutFinder, findsOneWidget);
    await tester.tap(aboutFinder);
    await tester.pumpAndSettle();

    expect(
      find.text('Understand the signals. Verify before you act.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Review safe-use guidance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review safe-use guidance'));
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.guidance);
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(backFinder);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.about);
    expect(await LocalOnboardingPreferences().readVersion(), 1);
    await tester.tap(backFinder);
    await tester.pumpAndSettle();

    // Verify Home dashboard is preserved
    expect(find.text('TrustCue'), findsWidgets);
    expect(find.text('Understand the signals.'), findsOneWidget);

    await tester.tap(aboutFinder);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(Get.currentRoute, AppRoutes.home);
    expect(Get.find<HomeController>(), same(controller));
    expect(find.text('Understand the signals.'), findsOneWidget);

    await tester.tap(aboutFinder);
    await tester.pumpAndSettle();
    final returned = expectLater(
      Get.toNamed('/about/does-not-exist'),
      completion(isNull),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page unavailable'), findsOneWidget);
    await tester.tap(find.text('Return to Home'));
    await tester.pumpAndSettle();
    await returned;
    expect(Get.currentRoute, AppRoutes.home);
    expect(Get.key.currentState!.canPop(), isFalse);
    expect(Get.find<HomeController>(), same(controller));
    expect(find.text('Understand the signals.'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('Real native OCR integration test with synthetic fixture', (
    WidgetTester tester,
  ) async {
    // 1. Load the bundled asset fixture
    final byteData = await rootBundle.load('assets/fixtures/ocr_test_card.png');
    final bytes = byteData.buffer.asUint8List();

    // 2. Write to a temporary file on the device
    final tempDir = await getTemporaryDirectory();
    final fixtureFile = File('${tempDir.path}/real_device_ocr_fixture.png');
    await fixtureFile.writeAsBytes(bytes, flush: true);

    expect(await fixtureFile.exists(), isTrue);

    // 3. Create real native DefaultTextRecognitionService
    final ocrService = DefaultTextRecognitionService();

    // 4. Exercise real native OCR against the fixture
    final result = await ocrService.processImage(
      filePath: fixtureFile.path,
      imageRevision: 'real-fixture-1',
      operationToken: 'device-ocr-op',
      timeout: const Duration(seconds: 30),
    );

    // 5. Assert recognition outcome
    expect(
      result.isSuccess,
      isTrue,
      reason:
          'Native OCR should succeed on real device: ${result.failureOrNull?.message}',
    );
    final ocrResult = result.valueOrNull!;

    // 6. Assert stable expected words while allowing whitespace/formatting variance
    final text = ocrResult.snapshot.text.toLowerCase();
    expect(text, contains('trustcue'), reason: 'Recognized text: $text');
    expect(text, contains('ocr'), reason: 'Recognized text: $text');
    expect(text, contains('test'), reason: 'Recognized text: $text');
    expect(text, contains('verify'), reason: 'Recognized text: $text');
    expect(text, contains('act'), reason: 'Recognized text: $text');

    // 7. Verify source and snapshot invariants
    expect(ocrResult.snapshot.source, InputSource.screenshot);
    expect(ocrResult.script, 'latin');
    expect(ocrResult.limitations.isNotEmpty, isTrue);

    // 8. Clean up
    await ocrService.dispose();
    if (await fixtureFile.exists()) {
      await fixtureFile.delete();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
