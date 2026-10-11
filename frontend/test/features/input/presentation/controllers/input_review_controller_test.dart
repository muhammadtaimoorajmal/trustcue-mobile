import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/review_input.dart';
import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_type.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_review_controller.dart';

void main() {
  group('InputReviewController Tests', () {
    late InputReviewController controller;
    var generatedIdCount = 0;
    final fixedClock = DateTime.utc(2026, 10, 11, 14, 30);

    setUp(() {
      generatedIdCount = 0;
    });

    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    test('Initial state when no review input argument is provided', () {
      controller = InputReviewController(
        idGenerator: () => 'reviewed-id-${++generatedIdCount}',
        clock: () => fixedClock,
      );
      controller.onInit();

      expect(controller.hasValidInput, isFalse);
      expect(controller.reviewInput, isNull);
      expect(controller.initialText, isEmpty);
      expect(controller.isScreenshotSource, isFalse);
      expect(controller.isComparisonImageAvailable, isFalse);
      expect(controller.candidates, isEmpty);
      expect(controller.isConfirmed.value, isFalse);
    });

    test('Initializes correctly with valid ReviewInput from typed text', () {
      final initialSnapshot = TextSnapshot(
        id: 'orig-snap-1',
        text: 'Hello from test user: contact@example.com',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 11, 12, 0),
      );
      final reviewInput = ReviewInput(
        snapshot: initialSnapshot,
        sourceRevision: 'rev-1',
      );

      controller = InputReviewController(
        reviewInput: reviewInput,
        idGenerator: () => 'reviewed-id-${++generatedIdCount}',
        clock: () => fixedClock,
      );
      controller.onInit();

      expect(controller.hasValidInput, isTrue);
      expect(controller.isScreenshotSource, isFalse);
      expect(controller.isComparisonImageAvailable, isFalse);
      expect(controller.textEditingController.text, initialSnapshot.text);
      expect(
        controller.codePointCount.value,
        initialSnapshot.text.runes.length,
      );
      expect(controller.hasDetected.value, isTrue);
      expect(controller.candidates.length, 1);
      expect(controller.candidates.first.type, SensitiveDataType.email);
      // Candidates are not selected by default
      expect(controller.selectedCandidateIds, isEmpty);
      expect(controller.previewText.value, initialSnapshot.text);
      expect(controller.isConfirmed.value, isFalse);
    });

    test(
      'Initializes correctly with screenshot ReviewInput and image path',
      () {
        final screenshotSnapshot = TextSnapshot(
          id: 'ocr-snap-1',
          text: 'Your code is 123456. Do not share.',
          source: InputSource.screenshot,
          createdAt: DateTime.utc(2026, 10, 11, 12, 0),
        );
        final reviewInput = ReviewInput(
          snapshot: screenshotSnapshot,
          sourceRevision: 'rev-1',
          imagePath: '/tmp/screenshot.png',
        );

        controller = InputReviewController(
          reviewInput: reviewInput,
          idGenerator: () => 'reviewed-id-${++generatedIdCount}',
          clock: () => fixedClock,
        );
        controller.onInit();

        expect(controller.isScreenshotSource, isTrue);
        // File does not actually exist at /tmp/screenshot.png
        expect(controller.isComparisonImageAvailable, isFalse);
        expect(controller.candidates.length, 1);
        expect(
          controller.candidates.first.type,
          SensitiveDataType.verificationCode,
        );
      },
    );

    test(
      'Text edits invalidate candidates, selections, and confirmed state',
      () {
        final initialSnapshot = TextSnapshot(
          id: 'orig-snap-2',
          text: 'Call +1 202 555 0199',
          source: InputSource.messageText,
          createdAt: DateTime.utc(2026, 10, 11, 12, 0),
        );
        controller = InputReviewController(
          reviewInput: ReviewInput(
            snapshot: initialSnapshot,
            sourceRevision: 'rev-1',
          ),
          idGenerator: () => 'reviewed-id-${++generatedIdCount}',
          clock: () => fixedClock,
        );
        controller.onInit();

        expect(controller.candidates.length, 1);
        controller.toggleCandidate(controller.candidates.first.id);
        expect(controller.selectedCandidateIds.length, 1);
        expect(controller.previewText.value, 'Call [PHONE]');

        // Edit the text
        controller.textEditingController.text = 'Call +1 202 555 0199 modified';

        // Prior detection & selections are cleared
        expect(controller.candidates, isEmpty);
        expect(controller.selectedCandidateIds, isEmpty);
        expect(controller.hasDetected.value, isFalse);
        expect(controller.previewText.value, 'Call +1 202 555 0199 modified');
        expect(controller.isConfirmed.value, isFalse);
      },
    );

    test('checkSensitiveDetails detects sensitive data in updated text', () {
      final initialSnapshot = TextSnapshot(
        id: 'orig-snap-3',
        text: 'Clean text here',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 11, 12, 0),
      );
      controller = InputReviewController(
        reviewInput: ReviewInput(
          snapshot: initialSnapshot,
          sourceRevision: 'rev-1',
        ),
        idGenerator: () => 'reviewed-id-${++generatedIdCount}',
        clock: () => fixedClock,
      );
      controller.onInit();

      expect(controller.candidates, isEmpty);

      // Add sensitive content
      controller.textEditingController.text =
          'Clean text and contact me at info@test.com';
      controller.checkSensitiveDetails();

      expect(controller.hasDetected.value, isTrue);
      expect(controller.candidates.length, 1);
      expect(controller.candidates.first.type, SensitiveDataType.email);
    });

    test('Toggling, selecting all, and clearing selections updates preview in real time', () {
      final initialSnapshot = TextSnapshot(
        id: 'orig-snap-4',
        text: 'Email: test@test.com, code: 987654',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 11, 12, 0),
      );
      controller = InputReviewController(
        reviewInput: ReviewInput(
          snapshot: initialSnapshot,
          sourceRevision: 'rev-1',
        ),
        idGenerator: () => 'reviewed-id-${++generatedIdCount}',
        clock: () => fixedClock,
      );
      controller.onInit();

      expect(controller.candidates.length, 2);

      // Select all
      controller.selectAllCandidates();
      expect(controller.selectedCandidateIds.length, 2);
      expect(
        controller.previewText.value,
        'Email: [EMAIL], code: [VERIFICATION CODE]',
      );

      // Clear all
      controller.clearCandidateSelections();
      expect(controller.selectedCandidateIds, isEmpty);
      expect(controller.previewText.value, initialSnapshot.text);

      // Select one
      final emailCandidate = controller.candidates.firstWhere(
        (c) => c.type == SensitiveDataType.email,
      );
      controller.toggleCandidate(emailCandidate.id);
      expect(controller.selectedCandidateIds.length, 1);
      expect(controller.previewText.value, 'Email: [EMAIL], code: 987654');
    });

    test(
      'confirmReviewedText generates an immutable snapshot with provenance',
      () {
        final initialSnapshot = TextSnapshot(
          id: 'orig-snap-5',
          text:
              'Your code is 54321. Call +1 (555) 234-5678 if this was not you.',
          source: InputSource.screenshot,
          createdAt: DateTime.utc(2026, 10, 11, 10, 0),
        );
        controller = InputReviewController(
          reviewInput: ReviewInput(
            snapshot: initialSnapshot,
            sourceRevision: 'rev-2',
          ),
          idGenerator: () => 'reviewed-id-${++generatedIdCount}',
          clock: () => fixedClock,
        );
        controller.onInit();

        // Select phone candidate only
        final phoneCand = controller.candidates.firstWhere(
          (c) => c.type == SensitiveDataType.phone,
        );
        controller.toggleCandidate(phoneCand.id);

        controller.confirmReviewedText();

        expect(controller.isConfirmed.value, isTrue);
        expect(controller.confirmedResult.value, isNotNull);

        final result = controller.confirmedResult.value!;
        expect(result.snapshot.id, 'reviewed-id-1');
        expect(result.snapshot.createdAt, fixedClock);
        expect(result.snapshot.source, InputSource.screenshot);
        expect(
          result.snapshot.text,
          'Your code is 54321. Call [PHONE] if this was not you.',
        );
        expect(result.sourceSnapshotId, 'orig-snap-5');
        expect(result.sourceRevision, 'rev-2');
        expect(result.totalRedactions, 1);
        expect(result.redactionCounts[SensitiveDataType.phone], 1);
        expect(
          result.redactionCounts.containsKey(
            SensitiveDataType.verificationCode,
          ),
          isFalse,
        );
      },
    );

    test('Validation failure blocks confirmation and sets error', () {
      final initialSnapshot = TextSnapshot(
        id: 'orig-snap-6',
        text: 'Some text',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 11, 10, 0),
      );
      controller = InputReviewController(
        reviewInput: ReviewInput(
          snapshot: initialSnapshot,
          sourceRevision: 'rev-1',
        ),
        idGenerator: () => 'reviewed-id-${++generatedIdCount}',
        clock: () => fixedClock,
      );
      controller.onInit();

      // Clear text completely
      controller.textEditingController.text = '   ';
      controller.confirmReviewedText();

      expect(controller.isConfirmed.value, isFalse);
      expect(controller.confirmedResult.value, isNull);
      expect(controller.validationError.value, isNotNull);
    });

    test('Clean back navigation when no edits or selections made', () async {
      final initialSnapshot = TextSnapshot(
        id: 'orig-snap-7',
        text: 'No modifications here',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 11, 10, 0),
      );
      controller = InputReviewController(
        reviewInput: ReviewInput(
          snapshot: initialSnapshot,
          sourceRevision: 'rev-1',
        ),
        idGenerator: () => 'reviewed-id-${++generatedIdCount}',
        clock: () => fixedClock,
      );
      controller.onInit();

      final canPop = await controller.handleBackNavigation();
      expect(canPop, isTrue);
    });
  });
}
