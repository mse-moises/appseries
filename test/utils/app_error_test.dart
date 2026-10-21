import 'package:appseries/utils/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appErrorFromFirebase', () {
    test('credencial, senha errada e e-mail inexistente dão a mesma frase', () {
      for (final String codigo in <String>[
        'invalid-credential',
        'wrong-password',
        'user-not-found',
        'invalid-login-credentials',
      ]) {
        final AppError error = appErrorFromFirebase(codigo);
        expect(error, isA<CredenciaisInvalidasError>(), reason: codigo);
        expect(error.mensagem, 'E-mail ou senha incorretos. Confira e tente de novo.');
      }
    });

    test('cadastro: e-mail em uso', () {
      final error = appErrorFromFirebase('email-already-in-use');
      expect(error, isA<EmailJaEmUsoError>());
      expect(error.mensagem, 'Esse e-mail já tem conta. Tente entrar.');
    });

    test('cadastro: senha fraca', () {
      final error = appErrorFromFirebase('weak-password');
      expect(error, isA<SenhaFracaError>());
      expect(error.codigo, 'weak-password');
    });

    test('e-mail malformado', () {
      expect(appErrorFromFirebase('invalid-email'), isA<EmailInvalidoError>());
    });

    test('muitas tentativas', () {
      expect(appErrorFromFirebase('too-many-requests'), isA<MuitasTentativasError>());
    });

    test('conta desativada', () {
      expect(appErrorFromFirebase('user-disabled'), isA<ContaDesativadaError>());
    });

    test('queda de rede do Firebase é problema de rede, não de senha', () {
      expect(appErrorFromFirebase('network-request-failed'), isA<NetworkError>());
    });

    test('código desconhecido e código ausente caem em erro de servidor', () {
      expect(appErrorFromFirebase('internal-error'), isA<ServerError>());
      expect(appErrorFromFirebase('qualquer-coisa-nova'), isA<ServerError>());
      expect(appErrorFromFirebase(null), isA<ServerError>());
    });
  });

  group('appErrorFromGoogle', () {
    test('fechar o seletor ou o popup é cancelamento, não falha do sistema', () {
      for (final String codigo in <String>[
        'canceled',
        'popup-closed-by-user',
        'cancelled-popup-request',
      ]) {
        final AppError error = appErrorFromGoogle(codigo);
        expect(error, isA<GoogleCanceladoError>(), reason: codigo);
        expect(error.mensagem, 'Entrada com o Google cancelada.');
      }
    });

    test('conta que já existe por senha pede a senha', () {
      final AppError error = appErrorFromGoogle('account-exists-with-different-credential');

      expect(error, isA<ContaDeOutroMetodoError>());
      expect(error.mensagem, contains('senha'));
    });

    test('ambiente sem suporte aponta para o formulário', () {
      final AppError error = appErrorFromGoogle('operation-not-supported-in-this-environment');

      expect(error, isA<GoogleIndisponivelError>());
      expect(error.mensagem, contains('e-mail e senha'));
    });

    test('janela bloqueada explica o pop-up', () {
      expect(appErrorFromGoogle('popup-blocked'), isA<JanelaBloqueadaError>());
    });

    test('erro de configuração nossa não manda "tente de novo"', () {
      for (final String codigo in <String>[
        'operation-not-allowed',
        'unauthorized-domain',
        'providerConfigurationError',
        'clientConfigurationError',
      ]) {
        final AppError error = appErrorFromGoogle(codigo);
        expect(error, isA<GoogleIndisponivelError>(), reason: codigo);
        expect(error.mensagem, isNot(contains('Tente de novo')), reason: codigo);
      }
    });

    test('configuração, interrupção e queda sem código têm frase própria', () {
      for (final String? codigo in <String?>[
        'interrupted',
        'uiUnavailable',
        'unknownError',
        null,
      ]) {
        expect(appErrorFromGoogle(codigo), isA<GoogleFalhouError>(), reason: '$codigo');
      }
    });

    test('os códigos do popup chegam pelo FirebaseAuthException e leem igual', () {
      expect(appErrorFromFirebase('popup-closed-by-user'), isA<GoogleCanceladoError>());
      expect(
        appErrorFromFirebase('account-exists-with-different-credential'),
        isA<ContaDeOutroMetodoError>(),
      );
      expect(
        appErrorFromFirebase('operation-not-supported-in-this-environment'),
        isA<GoogleIndisponivelError>(),
      );
      expect(appErrorFromFirebase('popup-blocked'), isA<JanelaBloqueadaError>());
      expect(appErrorFromFirebase('unauthorized-domain'), isA<GoogleIndisponivelError>());
      expect(appErrorFromFirebase('operation-not-allowed'), isA<GoogleIndisponivelError>());
    });
  });

  group('appErrorFromCodigo (backend)', () {
    test('unauthorized e not_found', () {
      expect(appErrorFromCodigo('unauthorized'), isA<UnauthorizedError>());
      expect(appErrorFromCodigo('not_found'), isA<NotFoundError>());
    });

    test('os códigos de corpo inválido viram conflito', () {
      const List<String> codigos = <String>[
        'invalid_estado',
        'invalid_tmdb_id',
        'invalid_body',
        'invalid_tipo',
        'invalid_generos',
        'invalid_momento',
        'momento_too_long',
        'invalid_sinal',
        'invalid_peso',
        'invalid_origem',
      ];
      for (final String codigo in codigos) {
        expect(appErrorFromCodigo(codigo), isA<ConflictError>(), reason: codigo);
      }
    });

    test('consulta inválida tem mensagem própria: não se"salva" numa busca', () {
      for (final String codigo in <String>['query_too_short', 'query_too_long']) {
        final AppError error = appErrorFromCodigo(codigo);
        expect(error, isA<BuscaInvalidaError>(), reason: codigo);
        expect(error.mensagem, contains('3 a 100'), reason: codigo);
        expect(error.mensagem, isNot(contains('salvar')), reason: codigo);
      }
    });

    test('teto de recomendação', () {
      expect(appErrorFromCodigo('rec_limit'), isA<RateLimitError>());
    });

    test('servidor sem configuração própria não é culpa da sessão da usuária', () {
      for (final String codigo in <String>['auth_unconfigured', 'tmdb_unconfigured']) {
        final AppError error = appErrorFromCodigo(codigo);
        expect(error, isA<ServerError>(), reason: codigo);
        expect(error.mensagem, isNot(contains('sessão')));
      }
    });

    test('desconhecido e ausente caem em erro de servidor', () {
      expect(appErrorFromCodigo('surgiu_do_nada'), isA<ServerError>());
      expect(appErrorFromCodigo(null), isA<ServerError>());
    });
  });

  test('nenhuma frase mostra termo técnico para a usuária', () {
    const List<AppError> erros = <AppError>[
      NetworkError(),
      TempoEsgotadoError(),
      UnauthorizedError(),
      NotFoundError(),
      ConflictError(),
      RateLimitError(),
      ServerError(),
      CredenciaisInvalidasError(),
      EmailJaEmUsoError(),
      SenhaFracaError(),
      EmailInvalidoError(),
      MuitasTentativasError(),
      ContaDesativadaError(),
      GoogleCanceladoError(),
      ContaDeOutroMetodoError(),
      GoogleIndisponivelError(),
      JanelaBloqueadaError(),
      GoogleFalhouError(),
    ];

    for (final AppError error in erros) {
      final String frase = error.mensagem.toLowerCase();
      for (final String termo in <String>['firebase', 'token', 'error', 'erro 4', '401', 'null']) {
        expect(frase, isNot(contains(termo)), reason: '$frase contém $termo');
      }
    }
  });
}
