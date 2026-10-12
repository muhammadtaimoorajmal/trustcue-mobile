import 'dart:io';

import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_spacing.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_card.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/models/incoming_share_payload.dart';
import 'package:trustcue_mobile/features/incoming_share/presentation/controllers/incoming_share_coordinator.dart';

/// Modal dialog presenting received Android Sharesheet content to the user.
class IncomingShareDialog extends StatefulWidget {
  const IncomingShareDialog({
    super.key,
    required this.coordinator,
    required this.payload,
    this.imageBuilder,
  });

  final IncomingShareCoordinator coordinator;
  final IncomingSharePayload payload;
  final Widget Function(BuildContext context, String path)? imageBuilder;

  @override
  State<IncomingShareDialog> createState() => _IncomingShareDialogState();
}

class _IncomingShareDialogState extends State<IncomingShareDialog> {
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = widget.payload;

    return PopScope(
      canPop: !_isProcessing,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePaddingSmall),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme, payload),
                const SizedBox(height: AppSpacing.pagePaddingSmall),
                if (_errorMessage != null) ...[
                  _buildErrorBanner(theme, _errorMessage!),
                  const SizedBox(height: AppSpacing.pagePaddingSmall),
                ],
                _buildContent(theme, payload),
                const SizedBox(height: AppSpacing.pagePaddingSmall),
                _buildActions(theme, payload),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, IncomingSharePayload payload) {
    final String title;
    final IconData icon;

    if (payload.isUnsupported) {
      title = 'Unable to receive share';
      icon = Icons.error_outline;
    } else if (payload.type == IncomingShareType.mixed) {
      title = 'Shared content received';
      icon = Icons.share;
    } else if (payload.type == IncomingShareType.image) {
      title = 'Shared image received';
      icon = Icons.image_outlined;
    } else {
      title = 'Shared message received';
      icon = Icons.chat_bubble_outline;
    }

    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, IncomingSharePayload payload) {
    if (payload.isUnsupported) {
      return Text(
        payload.errorMessage ?? 'This shared content could not be processed. Please try sharing a standard text message or one PNG/JPEG image.',
        style: theme.textTheme.bodyMedium,
      );
    }

    switch (payload.type) {
      case IncomingShareType.text:
        return _buildTextSection(theme, payload.text ?? '');
      case IncomingShareType.image:
        return _buildImageSection(theme, payload.stagedImagePath ?? '');
      case IncomingShareType.mixed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Both an image and text were received with this share. Choose which item you want to examine in TrustCue:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            if (payload.hasImage) ...[
              _buildImageSection(theme, payload.stagedImagePath!),
              const SizedBox(height: AppSpacing.pagePaddingSmall),
            ],
            if (payload.hasText) ...[_buildTextSection(theme, payload.text!)],
          ],
        );
      case IncomingShareType.unsupported:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextSection(ThemeData theme, String text) {
    final isUrl = widget.coordinator.isSingleWebAddress(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${text.length} character(s) received · Non-clickable preview',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        if (isUrl) ...[
          const SizedBox(height: 4),
          Text(
            'This content is formatted as a single web address.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageSection(ThemeData theme, String imagePath) {
    final file = File(imagePath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (file.existsSync())
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.imageBuilder != null
                ? widget.imageBuilder!(context, imagePath)
                : Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Text('Unable to preview shared image.'),
                    ),
                  ),
          )
        else
          const Text('Shared image file not found.'),
        const SizedBox(height: 6),
        Text(
          'A temporary copy was created in TrustCue\'s app storage. Your original gallery photo was not modified.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }

  Widget _buildActions(ThemeData theme, IncomingSharePayload payload) {
    if (payload.isUnsupported) {
      return AppButton.primary(
        label: 'Dismiss',
        isLoading: _isProcessing,
        onPressed: _handleDismiss,
      );
    }

    if (payload.type == IncomingShareType.text) {
      final isUrl = widget.coordinator.isSingleWebAddress(payload.text ?? '');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.primary(
            label: 'Use as message',
            isLoading: _isProcessing,
            onPressed: () => _handleUseAsMessage(payload.text ?? ''),
          ),
          if (isUrl) ...[
            const SizedBox(height: AppSpacing.pagePaddingSmall),
            AppButton.secondary(
              label: 'Inspect as link',
              isLoading: _isProcessing,
              onPressed: () => _handleUseAsLink(payload.text ?? ''),
            ),
          ],
          const SizedBox(height: AppSpacing.pagePaddingSmall),
          AppButton.secondary(
            label: 'Dismiss',
            isLoading: _isProcessing,
            onPressed: _handleDismiss,
          ),
        ],
      );
    }

    if (payload.type == IncomingShareType.image) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.primary(
            label: 'Use as screenshot',
            isLoading: _isProcessing,
            onPressed: () =>
                _handleUseAsScreenshot(payload.stagedImagePath ?? ''),
          ),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
          AppButton.secondary(
            label: 'Use as QR image',
            isLoading: _isProcessing,
            onPressed: () => _handleUseAsQrImage(payload.stagedImagePath ?? ''),
          ),
          const SizedBox(height: AppSpacing.pagePaddingSmall),
          AppButton.secondary(
            label: 'Dismiss',
            isLoading: _isProcessing,
            onPressed: _handleDismiss,
          ),
        ],
      );
    }

    // Mixed payload actions:
    final isUrl = widget.coordinator.isSingleWebAddress(payload.text ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose an option:',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        AppButton.primary(
          label: 'Use image as screenshot',
          isLoading: _isProcessing,
          onPressed: () =>
              _handleUseAsScreenshot(payload.stagedImagePath ?? ''),
        ),
        const SizedBox(height: 8),
        AppButton.secondary(
          label: 'Use image as QR',
          isLoading: _isProcessing,
          onPressed: () => _handleUseAsQrImage(payload.stagedImagePath ?? ''),
        ),
        const SizedBox(height: 8),
        AppButton.secondary(
          label: 'Use text as message',
          isLoading: _isProcessing,
          onPressed: () => _handleUseAsMessage(payload.text ?? ''),
        ),
        if (isUrl) ...[
          const SizedBox(height: 8),
          AppButton.secondary(
            label: 'Inspect text as link',
            isLoading: _isProcessing,
            onPressed: () => _handleUseAsLink(payload.text ?? ''),
          ),
        ],
        const SizedBox(height: 8),
        AppButton.secondary(
          label: 'Dismiss',
          isLoading: _isProcessing,
          onPressed: _handleDismiss,
        ),
      ],
    );
  }

  Future<void> _handleDismiss() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await widget.coordinator.dismissPendingShare();
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleUseAsMessage(String text) async {
    if (_isProcessing) return;
    final conflict = widget.coordinator.checkMessageDraftConflict();
    if (conflict != null) {
      final replace = await _promptConflictReplacement(conflict);
      if (!replace) {
        await _handleDismiss();
        return;
      }
    }

    setState(() => _isProcessing = true);
    try {
      await widget.coordinator.applySharedMessage(text);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleUseAsLink(String url) async {
    if (_isProcessing) return;
    final conflict = widget.coordinator.checkLinkDraftConflict();
    if (conflict != null) {
      final replace = await _promptConflictReplacement(conflict);
      if (!replace) {
        await _handleDismiss();
        return;
      }
    }

    setState(() => _isProcessing = true);
    try {
      await widget.coordinator.applySharedLink(url);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleUseAsScreenshot(String stagedPath) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final imported = await widget.coordinator.importStagedImage(stagedPath);
      if (imported == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'The shared image could not be verified or imported. It may exceed size/dimension bounds.';
        });
        return;
      }

      final conflict = widget.coordinator.checkScreenshotDraftConflict(
        imported,
      );
      if (conflict != null) {
        final replace = await _promptConflictReplacement(conflict);
        if (!replace) {
          await _handleDismiss();
          return;
        }
      }

      await widget.coordinator.applySharedScreenshot(imported);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleUseAsQrImage(String stagedPath) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final imported = await widget.coordinator.importStagedImage(stagedPath);
      if (imported == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'The shared image could not be verified or imported. It may exceed size/dimension bounds.';
        });
        return;
      }

      final conflict = widget.coordinator.checkQrImageDraftConflict(imported);
      if (conflict != null) {
        final replace = await _promptConflictReplacement(conflict);
        if (!replace) {
          await _handleDismiss();
          return;
        }
      }

      await widget.coordinator.applySharedQrImage(imported);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _promptConflictReplacement(DraftConflict conflict) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace existing draft?'),
        content: Text(
          'TrustCue already has a ${conflict.existingDescription}. Would you like to keep your existing draft or replace it with the shared content?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep current draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace with shared content'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
