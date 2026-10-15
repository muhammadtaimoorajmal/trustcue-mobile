import 'package:trustcue_mobile/core/errors/analysis_failure.dart';

/// Distinct categories of failures during on-device text recognition.
enum OcrFailureCode {
  noReadableTextFound,
  invalidOrMissingFile,
  outputExceedsLimits,
  recognitionUnavailable,
  timeout,
  userCancelled,
  internalError,
}

/// Immutable, privacy-safe failure descriptor for on-device OCR.
///
/// Designed never to expose raw image filesystem paths, native exception stack traces,
/// or sensitive extracted text content in user-facing messages.
class OcrFailure {
  final OcrFailureCode code;
  final String message;
  final String recoverySuggestion;

  const OcrFailure({
    required this.code,
    required this.message,
    required this.recoverySuggestion,
  });

  /// No legible text detected by the recognizer.
  ///
  /// Note: This is an observation of image clarity or language, NOT a safety verdict.
  const OcrFailure.noReadableTextFound()
    : code = OcrFailureCode.noReadableTextFound,
      message = 'No readable text was found in this image.',
      recoverySuggestion =
          'This does not mean the message is safe. The image may be blurry, low contrast, or contain unsupported scripts such as Urdu or Arabic. You can retry, select another screenshot, or enter the text manually.';

  /// The specified image file does not exist or is unreadable by the OS.
  const OcrFailure.invalidOrMissingFile()
    : code = OcrFailureCode.invalidOrMissingFile,
      message = 'The selected image file is missing or unreadable.',
      recoverySuggestion =
          'Please select another screenshot or replace the image.';

  /// Output exceeds the supported 10,000 code-point or 40,000 UTF-8 byte boundary.
  const OcrFailure.outputExceedsLimits()
    : code = OcrFailureCode.outputExceedsLimits,
      message =
          'The extracted text exceeds the supported limit (10,000 characters).',
      recoverySuggestion =
          'Please choose a screenshot containing less text, or crop to the suspicious message.';

  /// Native recognition channels are not supported on this platform (e.g. desktop/web).
  const OcrFailure.recognitionUnavailable()
    : code = OcrFailureCode.recognitionUnavailable,
      message = 'On-device text recognition is not available on this platform or device.',
      recoverySuggestion =
          'You can switch to Message text to enter the message manually.';

  /// Recognition exceeded the specified timeout boundary.
  const OcrFailure.timeout()
    : code = OcrFailureCode.timeout,
      message = 'Text extraction timed out.',
      recoverySuggestion = 'Please try again or select a clearer screenshot.';

  /// User explicitly cancelled the ongoing extraction request.
  const OcrFailure.userCancelled()
    : code = OcrFailureCode.userCancelled,
      message = 'Text extraction was cancelled.',
      recoverySuggestion = 'You can tap "Extract text" whenever you are ready.';

  /// Unexpected native exception or operational failure.
  const OcrFailure.internalError()
    : code = OcrFailureCode.internalError,
      message = 'An error occurred during on-device text recognition.',
      recoverySuggestion =
          'Please try again, select a clearer screenshot, or enter the text manually.';

  /// Converts this [OcrFailure] to a standardized [AnalysisFailure].
  AnalysisFailure toAnalysisFailure() {
    switch (code) {
      case OcrFailureCode.noReadableTextFound:
      case OcrFailureCode.invalidOrMissingFile:
        return AnalysisFailure.invalidInput(message, code.name);
      case OcrFailureCode.outputExceedsLimits:
        return AnalysisFailure.unsupportedInput(message, code.name);
      case OcrFailureCode.recognitionUnavailable:
      case OcrFailureCode.internalError:
        return AnalysisFailure.unavailable(message, code.name);
      case OcrFailureCode.timeout:
        return AnalysisFailure.timeout(message, code.name);
      case OcrFailureCode.userCancelled:
        return AnalysisFailure.cancelled(message, code.name);
    }
  }

  /// Maps an [AnalysisFailure] back to an [OcrFailure] if it contains a known code name.
  factory OcrFailure.fromAnalysisFailure(AnalysisFailure failure) {
    for (final c in OcrFailureCode.values) {
      if (c.name == failure.safeDetails) {
        switch (c) {
          case OcrFailureCode.noReadableTextFound:
            return const OcrFailure.noReadableTextFound();
          case OcrFailureCode.invalidOrMissingFile:
            return const OcrFailure.invalidOrMissingFile();
          case OcrFailureCode.outputExceedsLimits:
            return const OcrFailure.outputExceedsLimits();
          case OcrFailureCode.recognitionUnavailable:
            return const OcrFailure.recognitionUnavailable();
          case OcrFailureCode.timeout:
            return const OcrFailure.timeout();
          case OcrFailureCode.userCancelled:
            return const OcrFailure.userCancelled();
          case OcrFailureCode.internalError:
            return const OcrFailure.internalError();
        }
      }
    }

    switch (failure.code) {
      case AnalysisFailureCode.timeout:
        return const OcrFailure.timeout();
      case AnalysisFailureCode.cancelled:
        return const OcrFailure.userCancelled();
      case AnalysisFailureCode.unavailable:
      case AnalysisFailureCode.rateLimited:
      case AnalysisFailureCode.unauthorized:
      case AnalysisFailureCode.consentRequired:
      case AnalysisFailureCode.providerError:
        return const OcrFailure.recognitionUnavailable();
      case AnalysisFailureCode.unsupportedInput:
        return const OcrFailure.outputExceedsLimits();
      case AnalysisFailureCode.invalidInput:
      case AnalysisFailureCode.malformedData:
        return const OcrFailure.noReadableTextFound();
    }
  }

  @override
  String toString() => 'OcrFailure(code: ${code.name}, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrFailure &&
          other.code == code &&
          other.message == message &&
          other.recoverySuggestion == recoverySuggestion);

  @override
  int get hashCode => Object.hash(code, message, recoverySuggestion);
}
