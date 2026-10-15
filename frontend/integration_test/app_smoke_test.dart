import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
import 'package:trustcue_mobile/features/incoming_share/data/services/default_incoming_share_adapter.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/models/incoming_share_payload.dart';
import 'package:trustcue_mobile/features/incoming_share/presentation/controllers/incoming_share_coordinator.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';
import 'package:trustcue_mobile/features/reports/presentation/widgets/history_report_card.dart';

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
    await tester.pump(const Duration(milliseconds: 500));
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

  testWidgets(
    'Module 21 Android incoming share platform channel and lifecycle integration test',
    (WidgetTester tester) async {
      // 0. Ensure application is launched
      app.main();
      await tester.pumpAndSettle();

      // 1. Verify default native adapter calls succeed on real Android device
      final adapter = DefaultIncomingShareAdapter();
      final initial = await adapter.getInitialShare();
      // Cold start with no external share should be null
      expect(initial, isNull);

      // Test native consumeShare acknowledging dummy event ID
      final consumed = await adapter.consumeShare(
        'integration-test-event-uuid',
      );
      expect(consumed, isTrue);

      // Test native cleanStagedFile
      final tempDir = await getTemporaryDirectory();
      final stagingDir = Directory('${tempDir.path}/trustcue_incoming_shares');
      if (!stagingDir.existsSync()) {
        stagingDir.createSync(recursive: true);
      }
      final stagedTestFile = File('${stagingDir.path}/test_stage_cleanup.tmp');
      await stagedTestFile.writeAsString('temporary test payload');
      expect(stagedTestFile.existsSync(), isTrue);

      final cleaned = await adapter.cleanStagedFile(stagedTestFile.path);
      expect(cleaned, isTrue);
      expect(stagedTestFile.existsSync(), isFalse);

      // 2. Test Coordinator receiving and presenting shared text in app
      if (Get.currentRoute != AppRoutes.home) {
        Get.offNamed(AppRoutes.home);
        await tester.pumpAndSettle();
      }

      final coordinator = Get.find<IncomingShareCoordinator>();
      coordinator.pendingShare.value = IncomingSharePayload.text(
        eventId: 'integration-share-text',
        text: 'Suspicious shared message to inspect',
      );
      coordinator.presentPendingShare();
      await tester.pumpAndSettle();

      expect(find.text('Shared message received'), findsOneWidget);
      expect(find.text('Suspicious shared message to inspect'), findsOneWidget);
      expect(find.text('Use as message'), findsOneWidget);

      // 3. User taps "Use as message"
      await tester.tap(find.text('Use as message'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputText);
      final textController = Get.find<InputTextController>();
      expect(textController.text.value, 'Suspicious shared message to inspect');

      // Return to home
      Get.offNamed(AppRoutes.home);
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'Module 26 & 31 Real-device local analysis, evidence viewer, guest account, and KeyStore smoke test',
    (WidgetTester tester) async {
      // 0. Ensure application is launched
      app.main();
      await tester.pumpAndSettle();

      // 1. Hardware KeyStore smoke test on real device
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(resetOnError: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
      const testKey = 'trustcue_device_test_key';
      const testValue = 'device_keystore_secret_test_value';
      await secureStorage.write(key: testKey, value: testValue);
      final readVal = await secureStorage.read(key: testKey);
      expect(readVal, equals(testValue));
      await secureStorage.delete(key: testKey);
      final postDeleteVal = await secureStorage.read(key: testKey);
      expect(postDeleteVal, isNull);

      // 2. Guest/unconfigured account screen check
      Get.toNamed(AppRoutes.account);
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.account);

      final unconfiguredHeader = find.text('Cloud Service Not Configured');
      final guestHeader = find.text('Guest Mode');
      expect(
        unconfiguredHeader.evaluate().isNotEmpty ||
            guestHeader.evaluate().isNotEmpty,
        isTrue,
      );

      if (unconfiguredHeader.evaluate().isNotEmpty) {
        expect(
          find.textContaining('All local scam analysis, text extraction'),
          findsOneWidget,
        );
        final returnHomeBtn = find.widgetWithText(AppButton, 'Return to Home');
        await tester.ensureVisible(returnHomeBtn);
        await tester.pumpAndSettle();
        await tester.tap(returnHomeBtn);
        await tester.pumpAndSettle();
      } else {
        expect(find.text('Optional Account Access'), findsOneWidget);
        final backFinder = find.byType(BackButton);
        await tester.tap(backFinder);
        await tester.pumpAndSettle();
      }
      expect(Get.currentRoute, AppRoutes.home);

      // 3. Local analysis & evidence viewer test with sensitive redaction
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

      final inputController = Get.find<InputTextController>();
      inputController.textEditingController.text = 'Your account will be suspended within 24 hours. Call +1-555-0199 immediately to verify.';
      await tester.pumpAndSettle();

      final prepareButton = find.widgetWithText(AppButton, 'Prepare text');
      await tester.ensureVisible(prepareButton);
      await tester.pumpAndSettle();
      await tester.tap(prepareButton);
      await tester.pumpAndSettle();

      final reviewButton = find.widgetWithText(AppButton, 'Review text');
      await tester.ensureVisible(reviewButton);
      await tester.pumpAndSettle();
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputReview);

      // Verify phone candidate was detected and redact it
      expect(find.text('[PHONE]'), findsOneWidget);
      final checkboxFinder = find.byType(Checkbox).first;
      await tester.ensureVisible(checkboxFinder);
      await tester.pumpAndSettle();
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Confirm reviewed text
      final confirmButton = find.widgetWithText(
        AppButton,
        'Confirm reviewed text',
      );
      await tester.ensureVisible(confirmButton);
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Tap "Analyze on this device"
      final analyzeButton = find.widgetWithText(
        AppButton,
        'Analyze on this device',
      );
      await tester.ensureVisible(analyzeButton);
      await tester.pumpAndSettle();
      await tester.tap(analyzeButton);
      await tester.pumpAndSettle();

      // 4. Verify /analysis/results
      expect(Get.currentRoute, AppRoutes.analysisResults);
      expect(find.text('Local on-device analysis'), findsWidgets);
      expect(find.text('Evidence trail'), findsOneWidget);

      // 5. Open AnalyzedTextEvidenceViewer
      final viewEvidenceBtn = find
          .widgetWithText(AppButton, 'View in analyzed text')
          .first;
      await tester.ensureVisible(viewEvidenceBtn);
      await tester.pumpAndSettle();
      await tester.tap(viewEvidenceBtn);
      await tester.pumpAndSettle();

      expect(find.text('Evidence in analyzed text'), findsOneWidget);
      expect(find.textContaining('[PHONE]'), findsWidgets);

      // Close the evidence viewer modal
      final closeBtn = find.byTooltip('Close evidence view');
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
      expect(find.text('Evidence in analyzed text'), findsNothing);

      // 6. Return to review and verify reviewed text preserved
      final returnToReviewBtn = find.widgetWithText(
        AppButton,
        'Return to review and edit text',
      );
      await tester.ensureVisible(returnToReviewBtn);
      await tester.pumpAndSettle();
      await tester.tap(returnToReviewBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.inputReview);
      expect(find.textContaining('[PHONE]'), findsWidgets);

      // Re-run local analysis to test Module 37 persistence and history
      await tester.ensureVisible(analyzeButton);
      await tester.pumpAndSettle();
      await tester.tap(analyzeButton);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.analysisResults);

      // 7. Module 37: Save analyzed report to local SQLite storage
      final saveReportBtn = find.widgetWithText(
        AppButton,
        'Save on this device',
      );
      await tester.ensureVisible(saveReportBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveReportBtn);
      await tester.pumpAndSettle();

      expect(find.text('Saved on this device'), findsOneWidget);
      final viewInHistoryBtn = find.widgetWithText(
        AppButton,
        'View in History',
      );
      expect(viewInHistoryBtn, findsOneWidget);

      // 8. Navigate to History via results button
      await tester.tap(viewInHistoryBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.history);
      expect(find.text('Saved Reports'), findsOneWidget);
      expect(find.text('[On-device heuristic]'), findsWidgets);
      expect(find.text('Indicators detected'), findsWidgets);
      expect(find.textContaining('suspended within 24 hours'), findsOneWidget);

      // 9. Open details and verify exact evidence viewer grounding
      final reportCardFinder = find.byType(HistoryReportCard).first;
      await tester.tap(reportCardFinder);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.historyDetail);
      expect(find.text('Saved Report Details'), findsOneWidget);
      expect(find.text('Analyzed text snapshot'), findsOneWidget);
      expect(find.textContaining('[PHONE]'), findsWidgets);
      final excerptFinder = find.text('Exact supporting excerpt(s):');
      await tester.ensureVisible(excerptFinder.first);
      await tester.pumpAndSettle();
      expect(excerptFinder, findsWidgets);

      // 10. Return to History
      final detailBackBtn = find.byType(BackButton);
      await tester.tap(detailBackBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.history);

      // 11. Search query filtering
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'suspended');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.textContaining('suspended within 24 hours'), findsOneWidget);

      // Search non-matching keyword
      await tester.enterText(searchField, 'xyzunknownterm999');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('No matching reports found'), findsOneWidget);
      expect(find.textContaining('suspended within 24 hours'), findsNothing);

      // Clear search
      final clearSearchBtn = find.byTooltip('Clear search');
      if (clearSearchBtn.evaluate().isNotEmpty) {
        await tester.tap(clearSearchBtn);
      } else {
        await tester.enterText(searchField, '');
      }
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.textContaining('suspended within 24 hours'), findsOneWidget);

      // 12. Transactional deletion: Cancel deletion preserves report
      final deleteBtn = find.byTooltip('Delete report from device').first;
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Delete saved report?'), findsOneWidget);
      expect(
        find.textContaining('This removes the saved report from this device.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep report'));
      await tester.pumpAndSettle();

      expect(find.text('Delete saved report?'), findsNothing);
      expect(find.textContaining('suspended within 24 hours'), findsOneWidget);

      // 13. Transactional deletion: Confirm deletion removes synthetic report
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();
      expect(find.text('Delete saved report?'), findsOneWidget);
      await tester.tap(find.text('Delete from device'));
      await tester.pumpAndSettle();

      expect(find.text('Delete saved report?'), findsNothing);
      expect(find.textContaining('suspended within 24 hours'), findsNothing);

      // 14. Navigate to Home and verify Saved Reports AppBar entry
      Get.offAllNamed(AppRoutes.home);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.home);
      final historyAppBarBtn = find.byTooltip('Saved Reports');
      expect(historyAppBarBtn, findsOneWidget);
      await tester.tap(historyAppBarBtn);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.history);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.home);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
