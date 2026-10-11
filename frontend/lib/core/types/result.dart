import '../errors/analysis_failure.dart';

/// Explicit, typed success or failure outcome.
///
/// Prevents unhandled exceptions, raw nulls, or loosely typed maps from being
/// passed across feature and architectural boundaries.
abstract class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(AnalysisFailure failure) = Failure<T>;

  bool get isSuccess;
  bool get isFailure;

  T? get valueOrNull;
  AnalysisFailure? get failureOrNull;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AnalysisFailure failure) onFailure,
  });
}

class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  T get valueOrNull => value;

  @override
  AnalysisFailure? get failureOrNull => null;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AnalysisFailure failure) onFailure,
  }) => onSuccess(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Success<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Result.success($value)';
}

class Failure<T> extends Result<T> {
  final AnalysisFailure failure;

  const Failure(this.failure);

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  T? get valueOrNull => null;

  @override
  AnalysisFailure get failureOrNull => failure;

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AnalysisFailure failure) onFailure,
  }) => onFailure(failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure<T> && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Result.failure($failure)';
}
