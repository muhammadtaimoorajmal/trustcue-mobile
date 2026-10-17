import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';

/// Explicit confirmation dialog when attempting to load an educational practice example
/// while the user already has an active, non-empty draft in the text review flow.
class DraftReplacementDialog extends StatelessWidget {
  const DraftReplacementDialog({super.key});

  /// Displays the confirmation dialog and returns true if the user approved replacement.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DraftReplacementDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        'education_draft_replace_title'.tr,
        style: theme.textTheme.titleLarge,
      ),
      content: Text(
        'education_draft_replace_desc'.tr,
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('education_keep_draft_btn'.tr),
        ),
        AppButton.primary(
          label: 'education_replace_btn'.tr,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
