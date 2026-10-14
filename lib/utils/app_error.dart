/// Typed error that the app shows to the user.
///
/// Every case carries:
/// - [codigo]: the raw code the backend answered with (for logs/tests);
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
