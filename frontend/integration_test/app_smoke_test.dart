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
import 'package:trustcue_mobile/features/input/data/services/default_qr_decoder_service.dart';
import 'package:trustcue_mobile/features/input/data/services/default_text_recognition_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_link_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';
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

  testWidgets(
    'Module 19 text review and sensitive data redaction integration test',
    (WidgetTester tester) async {
      // Launch the application using main entry point
      app.main();
      await tester.pumpAndSettle();

      // Navigate to /input/text from Home
      final enterMessageFinder = find.widgetWithText(
        AppButton,
        'Enter message',
      );
      if (enterMessageFinder.evaluate().isNotEmpty) {
        await tester.ensureVisible(enterMessageFinder);
        await tester.pumpAndSettle();
        await tester.tap(enterMessageFinder);
        await tester.pumpAndSettle();
      } else {
        Get.toNamed(AppRoutes.inputText);
        await tester.pumpAndSettle();
      }

      expect(Get.currentRoute, AppRoutes.inputText);

      // Enter message containing an email address
      final inputController = Get.find<InputTextController>();
      inputController.textEditingController.text = 'Urgent invoice alert: contact billing@suspicious-bank.com immediately.';
      await tester.pumpAndSettle();

      // Prepare text
      final prepareButton = find.widgetWithText(AppButton, 'Prepare text');
      await tester.ensureVisible(prepareButton);
      await tester.pumpAndSettle();
      await tester.tap(prepareButton);
      await tester.pumpAndSettle();

      expect(find.text('Review text'), findsOneWidget);

      // Navigate to review
      final reviewButton = find.widgetWithText(AppButton, 'Review text');
      await tester.ensureVisible(reviewButton);
      await tester.pumpAndSettle();
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputReview);
      expect(
        find.text(
          'Reviewing text does not analyze it or authorize uploading it.',
        ),
        findsOneWidget,
      );

      // Verify candidate detection
      expect(find.text('Possible sensitive details'), findsOneWidget);
      expect(find.text('[EMAIL]'), findsOneWidget);

      // Select candidate checkbox for redaction
      final checkboxFinder = find.byType(Checkbox);
      await tester.ensureVisible(checkboxFinder);
      await tester.pumpAndSettle();
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Verify preview is updated with placeholder
      expect(
        find.text('Urgent invoice alert: contact [EMAIL] immediately.'),
        findsOneWidget,
      );

      // Confirm reviewed text
      final confirmButton = find.widgetWithText(
        AppButton,
        'Confirm reviewed text',
      );
      await tester.ensureVisible(confirmButton);
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Verify confirmation banner on review screen
      expect(
        find.text(
          'Reviewed text is ready on this device. It has not been analyzed or sent anywhere.',
        ),
        findsOneWidget,
      );

      // Navigate back to input/text
      final backFinder = find.byType(IconButton).first;
      await tester.tap(backFinder);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputText);
      expect(find.text('Reviewed text confirmed on device.'), findsOneWidget);
      expect(inputController.reviewedResult.value, isNotNull);
      expect(
        inputController.reviewedResult.value!.snapshot.text,
        'Urgent invoice alert: contact [EMAIL] immediately.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('Module 20 link inspection and QR code decoding integration test', (
    WidgetTester tester,
  ) async {
    // 1. Launch the application
    app.main();
    await tester.pumpAndSettle();

    // 2. Navigate to /input/link from Home
    final linkOptionFinder = find.widgetWithText(
      AppButton,
      'Inspect link or QR',
    );
    if (linkOptionFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(linkOptionFinder);
      await tester.pumpAndSettle();
      await tester.tap(linkOptionFinder);
      await tester.pumpAndSettle();
    } else {
      Get.toNamed(AppRoutes.inputLink);
      await tester.pumpAndSettle();
    }

    expect(Get.currentRoute, AppRoutes.inputLink);
    expect(find.text('Link or QR code'), findsOneWidget);

    // 3. Test web link inspection
    final linkController = Get.find<InputLinkController>();
    linkController.urlTextController.text =
        'https://example.com/verify?account=12345';
    await tester.pumpAndSettle();

    final inspectButton = find.widgetWithText(AppButton, 'Inspect link');
    await tester.ensureVisible(inspectButton);
    await tester.pumpAndSettle();
    await tester.tap(inspectButton);
    await tester.pumpAndSettle();

    expect(find.text('Destination Review'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(linkController.canOpenExternally, isTrue);

    // 4. Test real device QR decoding via DefaultQrDecoderService
    final byteData = await rootBundle.load('assets/fixtures/qr_test_card.png');
    final tempDir = await getTemporaryDirectory();
    final fixtureFile = File(
      '${tempDir.path}/qr_integration_fixture_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await fixtureFile.writeAsBytes(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      flush: true,
    );

    final qrDecoder = DefaultQrDecoderService();
    final qrResult = await qrDecoder.decode(fixtureFile.path);

    expect(qrResult.payloads.isNotEmpty, isTrue);
    final payload = qrResult.payloads.first;
    expect(payload.rawValue, contains('trustcue-test'));
    expect(payload.linkInspection, isNotNull);
    expect(payload.linkInspection!.host, 'example.com');

    // 5. Clean up temporary fixture
    if (await fixtureFile.exists()) {
      await fixtureFile.delete();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
