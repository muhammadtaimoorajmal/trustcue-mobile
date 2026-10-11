import 'package:trustcue_mobile/core/errors/analysis_failure.dart';

import '../models/selected_image_descriptor.dart';

/// Categories of validation failure for screenshot image candidate files.
enum ImageValidationReason {
  emptyFile,
  fileTooLarge,
  unsupportedFormat,
  animatedImageUnsupported,
  dimensionTooLarge,
  pixelCountTooLarge,
  invalidDimensions,
  corruptOrUnreadable,
}

/// Immutable, privacy-safe error detailing why an image failed validation.
///
/// Guaranteed never to include local file paths or raw exception traces.
class ImageValidationError {
  final ImageValidationReason reason;
  final String message;

  const ImageValidationError({required this.reason, required this.message});

  /// Maps this validation error to a standardized [AnalysisFailure].
  AnalysisFailure toAnalysisFailure() {
    return AnalysisFailure.invalidInput(message, reason.name);
  }

  @override
  String toString() =>
      'ImageValidationError(reason: ${reason.name}, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageValidationError &&
          other.reason == reason &&
          other.message == message);

  @override
  int get hashCode => Object.hash(reason, message);
}

/// Result of evaluating an image candidate for screenshot preview.
class ImageValidationResult {
  final bool isValid;
  final ImageValidationError? error;
  final ImageFormat? format;
  final int? width;
  final int? height;
  final int? byteCount;

  const ImageValidationResult.valid({
    required ImageFormat this.format,
    required int this.width,
    required int this.height,
    required int this.byteCount,
  }) : isValid = true,
       error = null;

  const ImageValidationResult.invalid(ImageValidationError this.error)
    : isValid = false,
      format = null,
      width = null,
      height = null,
      byteCount = null;

  bool get isInvalid => !isValid;
}

/// Centralized product limits and policies for screenshot image intake.
class ImageValidationPolicy {
  const ImageValidationPolicy._();

  /// Maximum allowed byte size (10 MiB = 10,485,760 bytes).
  static const int maxByteCount = 10 * 1024 * 1024;

  /// Maximum allowed width or height in pixels.
  static const int maxDimension = 12000;

  /// Maximum allowed total pixel count (width * height).
  static const int maxPixelCount = 20000000;

  /// Formats byte count into human-readable size for guidance copy.
  static String formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}
