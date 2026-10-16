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

  group('appErrorFromCodigo (backend)', () {
    test('unauthorized e not_found', () {
      expect(appErrorFromCodigo('unauthorized'), isA<UnauthorizedError>());
      expect(appErrorFromCodigo('not_found'), isA<NotFoundError>());
    });

    test('os códigos de corpo inválido viram conflito', () {
      for (final String codigo in <String>['invalid_estado', 'invalid_tmdb_id', 'invalid_body']) {
        expect(appErrorFromCodigo(codigo), isA<ConflictError>(), reason: codigo);
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
    ];

    for (final AppError error in erros) {
      final String frase = error.mensagem.toLowerCase();
      for (final String termo in <String>['firebase', 'token', 'error', 'erro 4', '401', 'null']) {
        expect(frase, isNot(contains(termo)), reason: '$frase contém $termo');
      }
    }
  });
}
