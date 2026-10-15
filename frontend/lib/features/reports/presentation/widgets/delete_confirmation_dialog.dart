import 'package:flutter/material.dart';

/// Modal dialog requesting explicit confirmation prior to deleting a locally saved report.
///
/// Principles:
/// - Explicit user confirmation required.
/// - Clear copy stating data is permanently removed from device storage.
/// - Never performs unintended or silent deletions.
class DeleteConfirmationDialog extends StatelessWidget {
  const DeleteConfirmationDialog({super.key});

  /// Displays the confirmation dialog and returns `true` if deletion was confirmed.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const DeleteConfirmationDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 24),
          const SizedBox(width: 8),
          const Expanded(child: Text('Delete saved report?')),
        ],
      ),
      content: Text(
        'This removes the saved report from this device.\n\n'
        'Reviewed text and associated indicator findings will be permanently deleted from local storage.',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep report'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete from device'),
        ),
      ],
    );
  }
}
