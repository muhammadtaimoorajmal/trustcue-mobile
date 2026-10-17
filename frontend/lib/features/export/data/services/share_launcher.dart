import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Normalized result of an external share action.
enum ShareStatus {
  /// The user successfully selected a sharing target or completed the share.
  success,

  /// The user dismissed the share sheet without selecting a target.
  dismissed,

  /// The sharing interface is not available on this platform/environment.
  unavailable,
}

/// Abstract contract for invoking platform share dialogs.
abstract class ShareLauncher {
  /// Opens the native platform share sheet for the given [file].
  Future<ShareStatus> shareFile({
    required File file,
    required String mimeType,
    required String subject,
    required String text,
    Rect? sharePositionOrigin,
  });
}

/// Default implementation delegating to `share_plus`.
class DefaultShareLauncher implements ShareLauncher {
  @override
  Future<ShareStatus> shareFile({
    required File file,
    required String mimeType,
    required String subject,
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final xFile = XFile(file.path, mimeType: mimeType);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: subject,
          text: text,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      switch (result.status) {
        case ShareResultStatus.success:
          return ShareStatus.success;
        case ShareResultStatus.dismissed:
          return ShareStatus.dismissed;
        case ShareResultStatus.unavailable:
          return ShareStatus.unavailable;
      }
    } catch (_) {
      return ShareStatus.unavailable;
    }
  }
}
