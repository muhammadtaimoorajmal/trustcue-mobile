import 'package:flutter/material.dart';

/// User choice for deleting reports.
enum DeleteReportChoice { cancel, deviceOnly, deviceAndCloud }

/// Modal dialog requesting explicit confirmation prior to deleting a locally saved report.
///
/// Principles:
/// - Explicit user confirmation required.
/// - Clear copy stating data is permanently removed from device storage.
/// - When cloud sync is active, distinguishes device-only deletion from cloud tombstone deletion.
/// - Never performs unintended or silent deletions.
class DeleteConfirmationDialog extends StatelessWidget {
  final bool isSyncEnabled;

  const DeleteConfirmationDialog({super.key, this.isSyncEnabled = false});

  /// Displays the confirmation dialog and returns the chosen [DeleteReportChoice].
  static Future<DeleteReportChoice> show(
    BuildContext context, {
    bool isSyncEnabled = false,
  }) async {
    final result = await showDialog<DeleteReportChoice>(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          DeleteConfirmationDialog(isSyncEnabled: isSyncEnabled),
    );
    return result ?? DeleteReportChoice.cancel;
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
      content: SingleChildScrollView(
        child: Text(
          isSyncEnabled
              ? 'This report is backed up to your cloud account.\n\n'
                    '• Delete from device only: Removes local text and findings while preserving the cloud backup summary.\n'
                    '• Delete from device & cloud: Permanently removes the report from this device and wipes the cloud backup.'
              : 'This removes the saved report from this device.\n\n'
                    'Reviewed text and associated indicator findings will be permanently deleted from local storage.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: isSyncEnabled
          ? [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(DeleteReportChoice.cancel),
                child: const Text('Keep report'),
              ),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(DeleteReportChoice.deviceOnly),
                child: const Text('Device only'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () =>
                    Navigator.of(context)
                        .pop(DeleteReportChoice.deviceAndCloud),
                child: const Text('Device & Cloud'),
              ),
            ]
          : [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(DeleteReportChoice.cancel),
                child: const Text('Keep report'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () =>
                    Navigator.of(context).pop(DeleteReportChoice.deviceOnly),
                child: const Text('Delete from device'),
              ),
            ],
    );
  }
}
