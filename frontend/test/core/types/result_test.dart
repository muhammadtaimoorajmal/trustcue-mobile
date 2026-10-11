import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/core/types/result.dart';

void main() {
  group('Result and AnalysisFailure tests', () {
    test('Success result holds value and folds correctly', () {
      const result = Result<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);

      final folded = result.fold(
        onSuccess: (val) => 'val: $val',
        onFailure: (err) => 'err: ${err.code}',
      );
      expect(folded, 'val: 42');
      expect(result, const Result<int>.success(42));
      expect(result.hashCode, const Result<int>.success(42).hashCode);
      expect(result.toString(), 'Result.success(42)');
    });

    test('Failure result holds failure and folds correctly', () {
      const failure = AnalysisFailure.invalidInput('Text cannot be empty');
      const result = Result<int>.failure(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);

      final folded = result.fold(
        onSuccess: (val) => 'val: $val',
        onFailure: (err) => err.code.name,
      );
      expect(folded, 'invalidInput');
      expect(result, const Result<int>.failure(failure));
      expect(result.hashCode, const Result<int>.failure(failure).hashCode);
      expect(result.toString(), contains('AnalysisFailure(invalidInput)'));
    });

    test('AnalysisFailure covers all expected failure codes', () {
      const codes = AnalysisFailureCode.values;
      expect(codes, contains(AnalysisFailureCode.invalidInput));
      expect(codes, contains(AnalysisFailureCode.unsupportedInput));
      expect(codes, contains(AnalysisFailureCode.unavailable));
      expect(codes, contains(AnalysisFailureCode.timeout));
      expect(codes, contains(AnalysisFailureCode.cancelled));
      expect(codes, contains(AnalysisFailureCode.malformedData));

      const f1 = AnalysisFailure.invalidInput('Invalid');
      expect(f1.code, AnalysisFailureCode.invalidInput);

      const f2 = AnalysisFailure.unsupportedInput('Unsupported');
      expect(f2.code, AnalysisFailureCode.unsupportedInput);

      const f3 = AnalysisFailure.unavailable('Unavailable');
      expect(f3.code, AnalysisFailureCode.unavailable);

      const f4 = AnalysisFailure.timeout('Timeout');
      expect(f4.code, AnalysisFailureCode.timeout);

      const f5 = AnalysisFailure.cancelled('Cancelled');
      expect(f5.code, AnalysisFailureCode.cancelled);

      const f6 = AnalysisFailure.malformedData('Malformed', 'schema mismatch');
      expect(f6.code, AnalysisFailureCode.malformedData);
      expect(f6.safeDetails, 'schema mismatch');
    });

    test(
      'AnalysisFailure string representation is safe and redacts user text',
      () {
        const sensitiveText = 'Account password is secret123';
        const failure = AnalysisFailure(
          code: AnalysisFailureCode.invalidInput,
          message: 'Input exceeds maximum allowed length.',
          safeDetails: 'Length check failed',
        );

        final str = failure.toString();
        expect(str, contains('AnalysisFailure(invalidInput)'));
        expect(str, contains('Input exceeds maximum allowed length.'));
        expect(str, contains('Length check failed'));
        expect(str, isNot(contains(sensitiveText)));
      },
    );

    test('AnalysisFailure equality and hashCode', () {
      const a = AnalysisFailure.timeout('Timed out', 'network');
      const b = AnalysisFailure.timeout('Timed out', 'network');
      const c = AnalysisFailure.timeout('Timed out', 'storage');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
