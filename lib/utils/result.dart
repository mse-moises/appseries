import 'app_error.dart';

/// Result of a repository call: either the value or a typed [AppError].
///
/// Repositories never throw on a *expected* failure — they return
/// `Result.error(...)` so the ViewModel can switch on it:
///
/// ```dart
/// switch (result) {
///   case Ok<HealthStatus>(:final value): mostra(value);
///   case Error<HealthStatus>(:final error): mostraErro(error.mensagem);
/// }
/// ```
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>._;

  const factory Result.error(AppError error) = Error<T>._;

  bool get isOk => this is Ok<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Error<T>() => null,
      };

  AppError? get errorOrNull => switch (this) {
        Error<T>(:final error) => error,
        Ok<T>() => null,
      };
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);

  final T value;

  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class Error<T> extends Result<T> {
  const Error._(this.error);

  final AppError error;

  @override
  String toString() => 'Result<$T>.error($error)';
}
