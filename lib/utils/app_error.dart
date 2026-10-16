/// Typed error that the app shows to the user.
///
/// Every case carries:
/// - [codigo]: the raw code the source answered with (for logs/tests);
/// - [mensagem]: a ready-to-show sentence, **without technical terms**.
sealed class AppError {
  const AppError(this.codigo, this.mensagem);

  final String codigo;
  final String mensagem;

  @override
  String toString() => 'AppError($codigo): $mensagem';
}

final class NetworkError extends AppError {
  const NetworkError()
      : super('network', 'Sem conexão com a internet. Confira sua rede e tente de novo.');
}

/// The provider took the request and never answered.
///
/// Without it the screen waits for good: the button stays disabled and, with the
/// reentrancy guard, no later tap goes out either.
final class TempoEsgotadoError extends AppError {
  const TempoEsgotadoError()
      : super('timeout', 'Demorou demais para responder. Tente de novo.');
}

final class UnauthorizedError extends AppError {
  const UnauthorizedError() : super('unauthorized', 'Sua sessão expirou. Entre de novo.');
}

final class NotFoundError extends AppError {
  const NotFoundError() : super('not_found', 'Não encontramos o que você procurou.');
}

final class ConflictError extends AppError {
  const ConflictError() : super('conflict', 'Não deu para salvar agora. Tente de novo.');
}

final class RateLimitError extends AppError {
  const RateLimitError() : super('rec_limit', 'Você chegou no limite de hoje. Volte amanhã.');
}

final class ServerError extends AppError {
  const ServerError() : super('server', 'O servidor deu uma escorregada. Tente em instantes.');
}

// --- account errors (Firebase Auth) ----------------------------------------
//
// The login screen has to tell "wrong password" from "no network": one is the
// user's problem, the other is not. These carry the raw
// `FirebaseAuthException.code`. Firebase answers `invalid-credential` for a
// wrong password **and** for an unknown e-mail on purpose, so one sentence
// keeps the screen from telling which accounts exist.

final class CredenciaisInvalidasError extends AppError {
  const CredenciaisInvalidasError()
      : super('invalid-credential', 'E-mail ou senha incorretos. Confira e tente de novo.');
}

final class EmailJaEmUsoError extends AppError {
  const EmailJaEmUsoError()
      : super('email-already-in-use', 'Esse e-mail já tem conta. Tente entrar.');
}

final class SenhaFracaError extends AppError {
  const SenhaFracaError()
      : super('weak-password', 'A senha precisa ter pelo menos 6 caracteres.');
}

final class EmailInvalidoError extends AppError {
  const EmailInvalidoError() : super('invalid-email', 'Confira o e-mail digitado.');
}

final class MuitasTentativasError extends AppError {
  const MuitasTentativasError()
      : super('too-many-requests', 'Muitas tentativas seguidas. Espere um pouco.');
}

final class ContaDesativadaError extends AppError {
  const ContaDesativadaError() : super('user-disabled', 'Essa conta está desativada.');
}

/// Translates the `{"error": "<codigo>"}` that the backend returns.
///
/// The `*_unconfigured` codes (`auth_unconfigured`, `rec_unconfigured`,
/// `tmdb_unconfigured`) are 503 from a server missing its own configuration.
/// They fall through to [ServerError] on purpose: telling the user to sign in
/// again would loop her against a problem that is not hers.
AppError appErrorFromCodigo(String? codigo) => switch (codigo) {
      'unauthorized' => const UnauthorizedError(),
      'not_found' => const NotFoundError(),
      'invalid_estado' || 'invalid_tmdb_id' || 'invalid_body' => const ConflictError(),
      'rec_limit' => const RateLimitError(),
      _ => const ServerError(),
    };

/// Translates the `code` of a Firebase Auth failure.
///
/// Firebase answers a generic `invalid-credential` for a wrong password **and**
/// for an unknown e-mail, which is exactly the behaviour we want on screen.
AppError appErrorFromFirebase(String? codigo) => switch (codigo) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-login-credentials' =>
        const CredenciaisInvalidasError(),
      'email-already-in-use' => const EmailJaEmUsoError(),
      'weak-password' => const SenhaFracaError(),
      'invalid-email' => const EmailInvalidoError(),
      'too-many-requests' => const MuitasTentativasError(),
      'user-disabled' => const ContaDesativadaError(),
      'network-request-failed' => const NetworkError(),
      _ => const ServerError(),
    };
