import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_text_controller.dart';

void main() {
  group('InputTextController Tests', () {
    late InputTextController controller;
    var generatedIdCount = 0;
    final fixedClock = DateTime.utc(2026, 10, 11, 12, 0);

    setUp(() {
      generatedIdCount = 0;
      controller = InputTextController(
        idGenerator: () => 'snapshot-id-${++generatedIdCount}',
        clock: () => fixedClock,
      );
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    test('Initial state is empty and disabled for preparation and clear', () {
      expect(controller.text.value, isEmpty);
      expect(controller.codePointCount.value, 0);
      expect(controller.validationError.value, isNull);
      expect(controller.preparedSnapshot.value, isNull);
      expect(controller.showPreparedConfirmation.value, isFalse);
      expect(controller.hasDraft, isFalse);
      expect(controller.isPreparationDisabled, isTrue);
      expect(controller.isClearDisabled, isTrue);
      expect(controller.characterCountText, '0 / 10,000 characters');
    });

    test('Typing text updates text, counter, and action availability', () {
      controller.textEditingController.text = 'Urgent bank alert';

      expect(controller.text.value, 'Urgent bank alert');
      expect(controller.codePointCount.value, 17);
      expect(controller.hasDraft, isTrue);
      expect(controller.isPreparationDisabled, isFalse);
      expect(controller.isClearDisabled, isFalse);
      expect(controller.characterCountText, '17 / 10,000 characters');
    });

    test(
      'prepareText on invalid input sets error and does not prepare snapshot',
      () {
        controller.textEditingController.text = '   \t  ';
        final success = controller.prepareText();

        expect(success, isFalse);
        expect(controller.validationError.value, isNotNull);
        expect(
          controller.validationError.value?.reason,
          MessageTextValidationReason.onlyWhitespace,
        );
        expect(controller.preparedSnapshot.value, isNull);
        expect(controller.showPreparedConfirmation.value, isFalse);
      },
    );

    test('prepareText on valid input creates snapshot with normalized text and UTC time', () {
      controller.textEditingController.text =
          "Hello!\r\nPlease click here: http://fake.link\r\n";
      final success = controller.prepareText();

      expect(success, isTrue);
      expect(controller.validationError.value, isNull);
      expect(controller.showPreparedConfirmation.value, isTrue);

      final snapshot = controller.preparedSnapshot.value;
      expect(snapshot, isNotNull);
      expect(snapshot!.id, 'snapshot-id-1');
      expect(snapshot.source, InputSource.messageText);
      expect(snapshot.text, "Hello!\nPlease click here: http://fake.link\n");
      expect(snapshot.createdAt, equals(fixedClock));

      // After preparing, preparation button is disabled since text is unchanged.
      expect(controller.isPreparationDisabled, isTrue);
    });

    test(
      'Editing text after preparation invalidates snapshot and confirmation',
      () {
        controller.textEditingController.text = 'Legitimate notification';
        controller.prepareText();

        expect(controller.preparedSnapshot.value, isNotNull);
        expect(controller.showPreparedConfirmation.value, isTrue);
        expect(controller.isPreparationDisabled, isTrue);

        // User makes an edit
        controller.textEditingController.text =
            'Legitimate notification edited';

        expect(controller.preparedSnapshot.value, isNull);
        expect(controller.showPreparedConfirmation.value, isFalse);
        expect(controller.isPreparationDisabled, isFalse);
      },
    );

    test('clearText resets controller state and text editor', () {
      controller.textEditingController.text = 'Some draft content';
      controller.prepareText();
      expect(controller.hasDraft, isTrue);

      controller.clearText();

      expect(controller.text.value, isEmpty);
      expect(controller.textEditingController.text, isEmpty);
      expect(controller.codePointCount.value, 0);
      expect(controller.preparedSnapshot.value, isNull);
      expect(controller.showPreparedConfirmation.value, isFalse);
      expect(controller.validationError.value, isNull);
      expect(controller.hasDraft, isFalse);
      expect(controller.isPreparationDisabled, isTrue);
      expect(controller.isClearDisabled, isTrue);
    });
  });
}
