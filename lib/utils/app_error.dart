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

/// Consulta de busca que o backend recusa (menos de 3 ou mais de 100 letras).
///
/// Não é [ConflictError]: num GET não se salva nada, e "tente de novo" seria um
/// convite a repetir a mesma consulta inválida.
const int kBuscaMin = 3;
const int kBuscaMax = 100;

final class BuscaInvalidaError extends AppError {
  const BuscaInvalidaError()
      : super(
          'busca_invalida',
          'Confira o que você digitou: a busca precisa de $kBuscaMin a $kBuscaMax letras.',
        );
}

/// Texto livre do momento que o servidor recusa por tamanho.
///
/// Não é [ConflictError]: no `/rec` nada é salvo, e "não deu para salvar agora"
/// descreve uma ação que não existe naquela tela. Repetir a MESMA chamada falha
/// igual, então este erro nunca ganha botão de tentar de novo (a saída é a
/// pessoa encurtar o texto). Vive aqui porque `PUT /preferencias` recusa pelo
/// mesmo código.
final class MomentoLongoError extends AppError {
  const MomentoLongoError()
      : super('momento_too_long', 'Seu momento ficou longo demais. Encurte um pouco.');
}

/// Momento fora do tipo que o contrato aceita (bug de serialização do app):
/// repetir com o mesmo texto falharia igual.
final class MomentoInvalidoError extends AppError {
  const MomentoInvalidoError()
      : super('invalid_momento', 'Não consegui usar esse momento. Escreva com outras palavras.');
}

/// Sinal de gosto que não deu para registrar.
///
/// Separado do acervo de propósito: a ação é outra e a pessoa lê a frase certa.
final class FeedbackIndisponivelError extends AppError {
  const FeedbackIndisponivelError()
      : super('feedback_indisponivel', 'Não deu para registrar seu gosto. Atualize o app.');
}

/// Título que não dá para abrir porque o tipo veio fora do contrato.
///
/// Não é [ConflictError]: não há o que salvar, e "tente de novo" repetiria a
/// falha para sempre. Na leitura, atualizar o app resolve.
final class TituloIndisponivelError extends AppError {
  const TituloIndisponivelError()
      : super('titulo_indisponivel', 'Não foi possível abrir este título. Atualize o app.');
}

/// Ação do acervo que o servidor recusa ou que o app nem tenta, e que falharia
/// igual se repetida. Três origens:
///
/// - tipo desconhecido (inclusive uma linha anterior à migração 008, que vem
///   com `tipo` nulo — nada a ver com a versão instalada);
/// - estado desconhecido, numa chamada programática;
/// - um `400` (qualquer código) ou um `409` do servidor, em marcar ou remover
///   (`AcervoRepositoryImpl._doAcervo`).
///
/// Por isso a mensagem não diz "abrir", não manda atualizar o app e não
/// convida a tentar de novo: sem ação possível, o texto só precisa não mentir.
final class AcervoIndisponivelError extends AppError {
  const AcervoIndisponivelError()
      : super('acervo_indisponivel', 'Não dá para mexer neste título no acervo.');
}

final class RateLimitError extends AppError {
  const RateLimitError() : super('rec_limit', 'Você chegou no limite de hoje. Volte amanhã.');
}

/// The TMDB is throttling the server (`tmdb_rate_limited`, a 429 of seconds).
///
/// Not [RateLimitError]: that one is the daily cap on recommendations, and
/// "volte amanhã" would send her away for a wait of a few seconds.
final class CatalogoOcupadoError extends AppError {
  const CatalogoOcupadoError()
      : super(
          'tmdb_rate_limited',
          'Muita gente buscando agora. Espere um instante e tente de novo.',
        );
}

/// The catalogue (TMDB) is down or our server cannot reach it: `502
/// tmdb_error`, or `503 tmdb_unconfigured` when the server has no key.
///
/// Not [ServerError]: "o servidor escorregou" reads as our app being broken,
/// and the screens offer a retry because this one usually passes on its own.
/// Carries the raw code, so a log tells the two causes apart.
final class CatalogoIndisponivelError extends AppError {
  const CatalogoIndisponivelError([String codigo = 'tmdb_error'])
      : super(
          codigo,
          'O catálogo de filmes e séries está fora do ar agora. Tente de novo em instantes.',
        );
}

final class ServerError extends AppError {
  const ServerError() : super('server', 'O servidor deu uma escorregada. Tente em instantes.');
}

/// The device's own storage (`shared_preferences`) failed to read or write.
/// Nothing went to the server, so [ServerError] would point the logs the
/// wrong way. Today no screen shows it: a failed local mark only means the
/// genre chips show once more.
final class ArmazenamentoLocalError extends AppError {
  const ArmazenamentoLocalError()
      : super('armazenamento_local', 'Não deu para guardar isso no aparelho. Tente de novo.');
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

// --- Google sign-in --------------------------------------------------------
//
// Two sources answer here: `GoogleSignInException.code` (the SDK, on Android;
// passed as a string so this file does not import the plugin) and the codes the
// Firebase popup returns on web. Both end in the same sentence on screen.

/// She closed the account picker (or the browser popup).
final class GoogleCanceladoError extends AppError {
  const GoogleCanceladoError() : super('canceled', 'Entrada com o Google cancelada.');
}

/// That Google account already has a password account with the same e-mail:
/// signing in with Google would create a second identity for one person.
final class ContaDeOutroMetodoError extends AppError {
  const ContaDeOutroMetodoError()
      : super(
          'account-exists-with-different-credential',
          'Esse e-mail já tem conta com senha. Entre com a sua senha.',
        );
}

/// Google sign-in does not work in this environment (an embedded browser, for
/// instance): pointing her at the form is the honest answer.
final class GoogleIndisponivelError extends AppError {
  const GoogleIndisponivelError()
      : super(
          'operation-not-supported-in-this-environment',
          'Entrar com o Google não está disponível aqui. Use e-mail e senha.',
        );
}

final class JanelaBloqueadaError extends AppError {
  const JanelaBloqueadaError()
      : super(
          'popup-blocked',
          'O navegador bloqueou a janela do Google. Libere as janelas pop-up e tente de novo.',
        );
}

/// Anything else in the Google flow: bad configuration, interruption, no token.
final class GoogleFalhouError extends AppError {
  const GoogleFalhouError() : super('google', 'Não deu para entrar com o Google. Tente de novo.');
}

/// Translates the code of a Google sign-in failure (SDK enum name or Firebase
/// popup code, both arrive as a string).
AppError appErrorFromGoogle(String? codigo) => switch (codigo) {
      'canceled' ||
      'popup-closed-by-user' ||
      'cancelled-popup-request' =>
        const GoogleCanceladoError(),
      'account-exists-with-different-credential' => const ContaDeOutroMetodoError(),
      'operation-not-supported-in-this-environment' => const GoogleIndisponivelError(),
      // Configuration on our side, not hers: the Google provider is off in the
      // console, this domain is not authorised, or the client id is wrong (the
      // SDK's providerConfigurationError). "Try again" would be a lie.
      'operation-not-allowed' ||
      'unauthorized-domain' ||
      'providerConfigurationError' ||
      'clientConfigurationError' =>
        const GoogleIndisponivelError(),
      'popup-blocked' => const JanelaBloqueadaError(),
      _ => const GoogleFalhouError(),
    };

/// Translates the `{"error": "<codigo>"}` that the backend returns.
///
/// The `*_unconfigured` codes (`auth_unconfigured`, `rec_unconfigured`) are 503
/// from a server missing its own configuration. They fall through to
/// [ServerError] on purpose: telling the user to sign in again would loop her
/// against a problem that is not hers. `tmdb_unconfigured` is the exception: to
/// her it is the catalogue being out, the same as `tmdb_error`.
AppError appErrorFromCodigo(String? codigo) => switch (codigo) {
      'unauthorized' => const UnauthorizedError(),
      'not_found' => const NotFoundError(),
      'invalid_estado' ||
      'invalid_tmdb_id' ||
      'invalid_body' ||
      'invalid_tipo' ||
      'invalid_generos' =>
        const ConflictError(),
      // Momento: recusado no `/rec` (que só lê) e no `PUT /preferencias`. A
      // frase não fala em salvar nem convida a repetir o mesmo texto.
      'momento_too_long' => const MomentoLongoError(),
      'invalid_momento' => const MomentoInvalidoError(),
      // Corpo de feedback fora do contrato só acontece por bug de serialização
      // do app: repetir a mesma chamada falharia igual.
      'invalid_sinal' || 'invalid_peso' || 'invalid_origem' => const FeedbackIndisponivelError(),
      'query_too_short' || 'query_too_long' => const BuscaInvalidaError(),
      'rec_limit' => const RateLimitError(),
      'tmdb_rate_limited' => const CatalogoOcupadoError(),
      'tmdb_error' => const CatalogoIndisponivelError(),
      'tmdb_unconfigured' => const CatalogoIndisponivelError('tmdb_unconfigured'),
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
      // The web popup reports its own codes through FirebaseAuthException: send
      // them to the Google table so both paths read the same.
      'popup-closed-by-user' ||
      'cancelled-popup-request' ||
      'account-exists-with-different-credential' ||
      'operation-not-supported-in-this-environment' ||
      'operation-not-allowed' ||
      'unauthorized-domain' ||
      'popup-blocked' =>
        appErrorFromGoogle(codigo),
      _ => const ServerError(),
    };
