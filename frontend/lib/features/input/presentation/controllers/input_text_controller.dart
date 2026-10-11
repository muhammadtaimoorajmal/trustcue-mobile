import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';

/// Presentation controller managing message-text entry, character limits,
/// validation states, and local snapshot preparation.
class InputTextController extends GetxController {
  InputTextController({
    String Function()? idGenerator,
    DateTime Function()? clock,
    TextEditingController? textEditingController,
    FocusNode? focusNode,
  }) : _idGenerator = idGenerator ?? _defaultIdGenerator,
       _clock = clock ?? DateTime.now,
       textEditingController = textEditingController ?? TextEditingController(),
       focusNode = focusNode ?? FocusNode();

  final String Function() _idGenerator;
  final DateTime Function() _clock;

  final TextEditingController textEditingController;
  final FocusNode focusNode;

  final RxString text = ''.obs;
  final RxInt codePointCount = 0.obs;
  final Rxn<MessageTextValidationError> validationError =
      Rxn<MessageTextValidationError>();
  final Rxn<TextSnapshot> preparedSnapshot = Rxn<TextSnapshot>();
  final RxBool showPreparedConfirmation = false.obs;
  final RxBool isNavigatingAway = false.obs;

  @override
  void onInit() {
    super.onInit();
    textEditingController.addListener(_handleTextChanged);
    _syncText(textEditingController.text);
  }

  @override
  void onClose() {
    textEditingController.removeListener(_handleTextChanged);
    textEditingController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  void _handleTextChanged() {
    _syncText(textEditingController.text);
  }

  void _syncText(String newText) {
    text.value = newText;
    codePointCount.value = MessageTextValidator.countCodePoints(newText);
    // Any change in text invalidates existing preparation, confirmation, and error.
    preparedSnapshot.value = null;
    showPreparedConfirmation.value = false;
    validationError.value = null;
  }

  /// Whether non-empty text exists in the draft.
  bool get hasDraft => text.value.isNotEmpty;

  /// Whether the "Prepare text" action is disabled.
  ///
  /// Disabled if draft is empty, or if an existing snapshot matches current normalized text.
  bool get isPreparationDisabled {
    if (text.value.isEmpty) return true;
    if (preparedSnapshot.value != null &&
        preparedSnapshot.value!.text ==
            MessageTextValidator.normalizeLineEndings(text.value)) {
      return true;
    }
    return false;
  }

  /// Whether the "Clear text" action is disabled.
  bool get isClearDisabled => text.value.isEmpty;

  /// Formatted character count string.
  String get characterCountText =>
      MessageTextValidator.formatCharacterCount(codePointCount.value);

  /// Validates the current draft and prepares an in-memory [TextSnapshot].
  ///
  /// Returns `true` if preparation succeeded, or `false` if validation failed.
  bool prepareText() {
    final result = MessageTextValidator.validate(text.value);
    if (result.isInvalid) {
      validationError.value = result.error;
      preparedSnapshot.value = null;
      showPreparedConfirmation.value = false;
      return false;
    }

    validationError.value = null;
    final snapshot = TextSnapshot(
      id: _idGenerator(),
      source: InputSource.messageText,
      text: result.normalizedText!,
      createdAt: _clock(),
    );

    preparedSnapshot.value = snapshot;
    showPreparedConfirmation.value = true;
    focusNode.unfocus();
    return true;
  }

  /// Clears the current draft and resets all transient input state.
  void clearText() {
    textEditingController.clear();
    _syncText('');
  }

  /// Prompts the user before clearing a non-empty draft.
  Future<bool> requestClearText(BuildContext context) async {
    if (text.value.isEmpty) return false;
    final shouldClear = await confirmClear(context);
    if (shouldClear) {
      clearText();
      return true;
    }
    return false;
  }

  /// Shows confirmation dialog for clearing message text.
  Future<bool> confirmClear(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear message?'),
        content: const Text(
          'This will remove the current message text from this screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows confirmation dialog when leaving with unsaved draft.
  Future<bool> confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard message?'),
        content: const Text(
          'You have unsaved message text. If you leave now, your draft will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static String _defaultIdGenerator() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = math.Random().nextInt(1000000).toString().padLeft(6, '0');
    return 'txt-$now-$random';
  }
}
