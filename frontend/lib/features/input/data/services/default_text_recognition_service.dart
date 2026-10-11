import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/text_recognition_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_failure.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';

/// Production implementation of [TextRecognitionService] using Google ML Kit's
/// on-device Latin text recognition.
///
/// Notice: The `google_mlkit_text_recognition` Flutter plugin bridge is community-maintained
/// by flutter-ml.dev and is not officially sponsored or maintained by Google.
/// It wraps Google's on-device ML Kit C++/Java libraries using platform channels.
class DefaultTextRecognitionService implements TextRecognitionService {
  DefaultTextRecognitionService({
    TextRecognizer Function()? recognizerFactory,
    String Function()? idGenerator,
  }) : _recognizerFactory =
           recognizerFactory ??
           (() => TextRecognizer(script: TextRecognitionScript.latin)),
       _idGenerator = idGenerator ?? _defaultIdGenerator;

  final TextRecognizer Function() _recognizerFactory;
  final String Function() _idGenerator;

  TextRecognizer? _recognizer;
  String? _activeOperationToken;
  bool _isNativeRunning = false;
  bool _isDisposed = false;
  final Set<String> _cancelledTokens = <String>{};

  /// Returns true if a native recognition operation is currently active on the native thread.
  bool get isNativeRunning => _isNativeRunning;

  @override
  Future<Result<OcrResult>> processImage({
    required String filePath,
    required String imageRevision,
    required String operationToken,
    Duration? timeout,
  }) async {
    if (_isDisposed) {
      return Result.failure(
        const OcrFailure.internalError().toAnalysisFailure(),
      );
    }

    // 1. Platform validation: only Android and iOS are supported by on-device ML Kit
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return Result.failure(
        const OcrFailure.recognitionUnavailable().toAnalysisFailure(),
      );
    }

    // 2. File validation
    final file = File(filePath);
    if (!file.existsSync()) {
      return Result.failure(
        const OcrFailure.invalidOrMissingFile().toAnalysisFailure(),
      );
    }

    // 3. Concurrency check: prevent overlapping native calls on the recognizer
    if (_isNativeRunning) {
      return Result.failure(
        const OcrFailure.internalError().toAnalysisFailure(),
      );
    }

    _activeOperationToken = operationToken;
    _cancelledTokens.remove(operationToken);
    _isNativeRunning = true;
    _recognizer ??= _recognizerFactory();

    final effectiveTimeout = timeout ?? const Duration(seconds: 30);
    final inputImage = InputImage.fromFilePath(filePath);

    final nativeCompleter = Completer<RecognizedText>();
    _recognizer!
        .processImage(inputImage)
        .then((result) {
          if (!nativeCompleter.isCompleted) {
            nativeCompleter.complete(result);
          }
        })
        .catchError((Object error, StackTrace stack) {
          if (!nativeCompleter.isCompleted) {
            nativeCompleter.completeError(error, stack);
          }
        })
        .whenComplete(() {
          _isNativeRunning = false;
          if (_isDisposed) {
            _recognizer?.close();
            _recognizer = null;
          }
        });

    try {
      final recognized = await nativeCompleter.future.timeout(effectiveTimeout);

      // Check if this operation was cancelled, timed out, or superseded while running
      if (_isDisposed ||
          _cancelledTokens.contains(operationToken) ||
          _activeOperationToken != operationToken) {
        return Result.failure(
          const OcrFailure.userCancelled().toAnalysisFailure(),
        );
      }

      final rawText = recognized.text;
      if (rawText.trim().isEmpty) {
        return Result.failure(
          const OcrFailure.noReadableTextFound().toAnalysisFailure(),
        );
      }

      // Normalize line endings
      final normalizedText = MessageTextValidator.normalizeLineEndings(rawText);

      // Enforce the 10,000 code-point and 40,000 UTF-8 byte bounds
      final codePoints = MessageTextValidator.countCodePoints(normalizedText);
      final utf8Bytes = MessageTextValidator.countUtf8Bytes(normalizedText);

      if (codePoints > MessageTextValidator.maxCodePoints ||
          utf8Bytes > MessageTextValidator.maxUtf8Bytes) {
        return Result.failure(
          const OcrFailure.outputExceedsLimits().toAnalysisFailure(),
        );
      }

      final snapshot = TextSnapshot(
        id: 'snap-${_idGenerator()}',
        source: InputSource.screenshot,
        text: normalizedText,
        createdAt: DateTime.now().toUtc(),
      );

      final ocrResult = OcrResult(
        snapshot: snapshot,
        imageRevision: imageRevision,
        script: 'latin',
        extractionTimestamp: DateTime.now().toUtc(),
      );

      return Result.success(ocrResult);
    } on TimeoutException {
      _cancelledTokens.add(operationToken);
      return Result.failure(const OcrFailure.timeout().toAnalysisFailure());
    } catch (_) {
      if (_cancelledTokens.contains(operationToken) ||
          _activeOperationToken != operationToken) {
        return Result.failure(
          const OcrFailure.userCancelled().toAnalysisFailure(),
        );
      }
      return Result.failure(
        const OcrFailure.internalError().toAnalysisFailure(),
      );
    }
  }

  @override
  Future<void> cancelOperation(String operationToken) async {
    _cancelledTokens.add(operationToken);
    if (_activeOperationToken == operationToken) {
      _activeOperationToken = null;
    }
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _activeOperationToken = null;
    if (!_isNativeRunning) {
      await _recognizer?.close();
      _recognizer = null;
    }
  }

  static String _defaultIdGenerator() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = math.Random().nextInt(1000000).toString().padLeft(6, '0');
    return '$now-$random';
  }
}
