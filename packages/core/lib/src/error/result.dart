import 'failure.dart';

/// Minimal Either: use cases return `Result<T>` instead of throwing.
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onSuccess) => switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Error<T>(:final failure) => onFailure(failure),
      };

  bool get isSuccess => this is Success<T>;
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Error<T> extends Result<T> {
  const Error(this.failure);
  final Failure failure;
}
