import 'package:trustcue_mobile/core/types/result.dart';

import '../models/ocr_result.dart';

/// Abstract contract governing on-device text recognition.
///
/// Implementations isolate platform channel plugins and native ML Kit classes,
/// ensuring the domain and presentation layers remain clean and testable with
/// deterministic fakes.
abstract class TextRecognitionService {
  /// Extracts text from the image at [filePath].
  ///
  /// [imageRevision] is an opaque identifier for the source image.
  /// [operationToken] identifies the specific extraction attempt to prevent
  /// superseded or cancelled operations from returning late results.
  /// [timeout] defines an optional duration limit for the operation.
  Future<Result<OcrResult>> processImage({
    required String filePath,
    required String imageRevision,
    required String operationToken,
    Duration? timeout,
  });

  /// Signals cancellation for an active [operationToken].
  Future<void> cancelOperation(String operationToken);

  /// Releases native recognizer resources when no longer required.
  Future<void> dispose();
}
