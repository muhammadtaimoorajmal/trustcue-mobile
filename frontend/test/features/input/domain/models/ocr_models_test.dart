import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_failure.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('OcrResult', () {
    test(
      'creates immutable result with unreviewed text and default limitations',
      () {
        final now = DateTime.now().toUtc();
        final snapshot = TextSnapshot(
          id: 'snap-123',
          source: InputSource.screenshot,
          text: 'Suspicious bank alert: Click here immediately.',
          createdAt: now,
        );

        final result = OcrResult(
          snapshot: snapshot,
          imageRevision: 'img-456',
          script: 'latin',
          extractionTimestamp: now,
        );

        expect(result.snapshot.id, 'snap-123');
        expect(result.snapshot.source, InputSource.screenshot);
        expect(
          result.snapshot.text,
          'Suspicious bank alert: Click here immediately.',
        );
        expect(result.imageRevision, 'img-456');
        expect(result.script, 'latin');
        expect(result.extractionTimestamp, now);
        expect(result.limitations.length, 4);
        expect(
          result.limitations,
          contains('Latin-script text only (including English).'),
        );
        expect(
          result.limitations,
          contains('Urdu and Arabic text in images are not supported yet.'),
        );
        expect(
          result.limitations,
          contains(
            'Extracted text is unreviewed and may miss or misread words.',
          ),
        );

        // Limitations list is unmodifiable
        expect(
          () => result.limitations.add('tampered'),
          throwsUnsupportedError,
        );
      },
    );

    test('value equality and hashCode', () {
      final now = DateTime.utc(2026, 10, 11, 12, 0);
      final snapshot1 = TextSnapshot(
        id: 'snap-1',
        source: InputSource.screenshot,
        text: 'Sample',
        createdAt: now,
      );
      final snapshot2 = TextSnapshot(
        id: 'snap-1',
        source: InputSource.screenshot,
        text: 'Sample',
        createdAt: now,
      );

      final r1 = OcrResult(
        snapshot: snapshot1,
        imageRevision: 'img-1',
        extractionTimestamp: now,
      );
      final r2 = OcrResult(
        snapshot: snapshot2,
        imageRevision: 'img-1',
        extractionTimestamp: now,
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });
  });

  group('OcrFailure', () {
    test('standard failure codes provide privacy-preserving messages', () {
      const failures = [
        OcrFailure.noReadableTextFound(),
        OcrFailure.invalidOrMissingFile(),
        OcrFailure.outputExceedsLimits(),
        OcrFailure.recognitionUnavailable(),
        OcrFailure.timeout(),
        OcrFailure.userCancelled(),
        OcrFailure.internalError(),
      ];

      for (final f in failures) {
        expect(f.message.isNotEmpty, isTrue);
        expect(f.recoverySuggestion.isNotEmpty, isTrue);
        // None of the standard messages leak absolute paths or stack traces
        expect(f.message.contains('/'), isFalse);
        expect(f.message.contains(r'\'), isFalse);
        expect(f.recoverySuggestion.contains('/'), isFalse);
        expect(f.recoverySuggestion.contains(r'\'), isFalse);
      }
    });

    test('maps to and from AnalysisFailure with full fidelity', () {
      const failures = [
        OcrFailure.noReadableTextFound(),
        OcrFailure.invalidOrMissingFile(),
        OcrFailure.outputExceedsLimits(),
        OcrFailure.recognitionUnavailable(),
        OcrFailure.timeout(),
        OcrFailure.userCancelled(),
        OcrFailure.internalError(),
      ];

      for (final f in failures) {
        final analysisFailure = f.toAnalysisFailure();
        final reconstructed = OcrFailure.fromAnalysisFailure(analysisFailure);
        expect(reconstructed.code, equals(f.code));
        expect(reconstructed.message, equals(f.message));
        expect(reconstructed.recoverySuggestion, equals(f.recoverySuggestion));
      }
    });

    test(
      'OcrFailure.fromAnalysisFailure fallback mapping for unknown categories',
      () {
        const timeoutAf = AnalysisFailure.timeout('Timed out');
        expect(
          OcrFailure.fromAnalysisFailure(timeoutAf).code,
          OcrFailureCode.timeout,
        );

        const cancelAf = AnalysisFailure.cancelled('Cancelled');
        expect(
          OcrFailure.fromAnalysisFailure(cancelAf).code,
          OcrFailureCode.userCancelled,
        );

        const unavailAf = AnalysisFailure.unavailable('Unavailable');
        expect(
          OcrFailure.fromAnalysisFailure(unavailAf).code,
          OcrFailureCode.recognitionUnavailable,
        );
      },
    );
  });
}
