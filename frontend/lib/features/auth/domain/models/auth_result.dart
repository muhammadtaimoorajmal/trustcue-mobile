import 'package:trustcue_mobile/features/auth/domain/models/auth_failure.dart';

/// Explicit, typed success or failure outcome for authentication operations.
abstract class AuthResult<T> {
  const AuthResult();

  const factory AuthResult.success(T value) = AuthSuccess<T>;
  const factory AuthResult.failure(AuthFailure failure) = AuthFailureOutcome<T>;

  bool get isSuccess;
  bool get isFailure;

  T? get valueOrNull;
  AuthFailure? get failureOrNull;

  R when<R>({
    required R Function(T value) success,
    required R Function(AuthFailure failure) failure,
  });

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AuthFailure failure) onFailure,
  });
}

class AuthSuccess<T> extends AuthResult<T> {
  const AuthSuccess(this.value);

  final T value;

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  T get valueOrNull => value;

  @override
  AuthFailure? get failureOrNull => null;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(AuthFailure failure) failure,
  }) => success(value);

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AuthFailure failure) onFailure,
  }) => onSuccess(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthSuccess<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AuthResult.success($value)';
}

class AuthFailureOutcome<T> extends AuthResult<T> {
  const AuthFailureOutcome(this.failure);

  final AuthFailure failure;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  T? get valueOrNull => null;

  @override
  AuthFailure get failureOrNull => failure;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(AuthFailure failure) failure,
  }) => failure(this.failure);

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AuthFailure failure) onFailure,
  }) => onFailure(failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthFailureOutcome<T> && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'AuthResult.failure($failure)';
}
