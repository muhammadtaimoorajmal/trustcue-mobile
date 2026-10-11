import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/input/data/services/default_text_recognition_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_failure.dart';

void main() {
  group('DefaultTextRecognitionService platform & file checks', () {
    test(
      'returns recognitionUnavailable on non-mobile desktop platforms',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          final service = DefaultTextRecognitionService();

          final result = await service.processImage(
            filePath: 'non_existent_path.png',
            imageRevision: 'img-1',
            operationToken: 'ocr-1',
          );

          expect(result.isFailure, isTrue);
          final failure = OcrFailure.fromAnalysisFailure(result.failureOrNull!);
          expect(failure.code, equals(OcrFailureCode.recognitionUnavailable));

          await service.dispose();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    test('returns invalidOrMissingFile when file does not exist on mobile platform', () async {
      final service = DefaultTextRecognitionService();

      final result = await service.processImage(
        filePath: 'non_existent_path.png',
        imageRevision: 'img-1',
        operationToken: 'ocr-1',
      );

      expect(result.isFailure, isTrue);
      final failure = OcrFailure.fromAnalysisFailure(result.failureOrNull!);
      expect(failure.code, equals(OcrFailureCode.invalidOrMissingFile));

      await service.dispose();
    });

    test('cancelOperation registers cancelled tokens', () async {
      final service = DefaultTextRecognitionService();
      await service.cancelOperation('token-123');
      // Cancelling inactive token should not throw
      await service.cancelOperation('token-999');
      await service.dispose();
    });

    test(
      'dispose marks service disposed and safe for repeated calls',
      () async {
        final service = DefaultTextRecognitionService();
        await service.dispose();
        await service.dispose(); // safe repeated disposal

        final result = await service.processImage(
          filePath: 'path.png',
          imageRevision: 'img-1',
          operationToken: 'token-1',
        );
        expect(result.isFailure, isTrue);
      },
    );
  });
}
