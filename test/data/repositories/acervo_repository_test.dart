import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/repositories/acervo_repository_impl.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adapter_falso.dart';
import '../../support/fake_rest_client.dart';

const AcervoItem _got = AcervoItem(
  tmdbId: 1399,
  estado: EstadoAcervo.watching,
  tipo: TipoMidia.tv,
  titulo: 'Game of Thrones',
);

DioException _erroHttp(int statusCode, Object corpo, {String path = '/api/v1/acervo/1'}) =>
    DioException.badResponse(
      statusCode: statusCode,
      requestOptions: RequestOptions(path: path),
      response: Response<Object>(
        requestOptions: RequestOptions(path: path),
        statusCode: statusCode,
        data: corpo,
      ),
    );

void main() {
  group('marcar e remover', () {
    // Pelo RestClient de verdade, com o status no fio: o dublê de RestClient não
    // tem status, e é o 201 que um app mal escrito trataria como falha.
    for (final (int status, String quando) in const <(int, String)>[
      (201, 'criou'),
      (200, 'atualizou'),
    ]) {
      test('marcar com $status ($quando) devolve o item gravado pelo servidor', () async {
        final AdapterFalso fio = AdapterFalso(
          '{"tmdbId":1399,"estado":"plan_to_watch","tipo":"tv","titulo":"Game of Thrones","ano":"2011"}',
          status: status,
        );
        final repo = AcervoRepositoryImpl(clienteFalso(fio));

        final result = await repo.marcar(TipoMidia.tv, 1399, EstadoAcervo.planToWatch);

        expect(result.errorOrNull, isNull);
        expect(result.valueOrNull?.estado, EstadoAcervo.planToWatch);
        expect(result.valueOrNull?.titulo, 'Game of Thrones');
        expect(fio.ultima.method, 'PUT');
        expect(fio.ultima.path, '/api/v1/acervo/1399');
        expect(fio.ultima.data, <String, dynamic>{'estado': 'plan_to_watch', 'tipo': 'tv'});
      });
    }

    test('400 invalid_estado é erro de tela, não sucesso', () async {
      final repo = AcervoRepositoryImpl(
        clienteFalso(AdapterFalso('{"error":"invalid_estado"}', status: 400)),
      );

      final result = await repo.marcar(TipoMidia.tv, 1399, EstadoAcervo.planToWatch);

      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, isA<AcervoIndisponivelError>());
      expect(result.errorOrNull?.mensagem, isNot(contains('Tente de novo')),
          reason: 'repetir a mesma gravação recusada falha igual');
    });

    // Erro determinístico: repetir a mesma gravação falha igual, então a frase
    // não pode convidar a tentar de novo. Vale com código conhecido, com código
    // que este app ainda não conhece e sem código.
    for (final (String corpo, String caso) in const <(String, String)>[
      ('{"error":"invalid_tipo"}', 'invalid_tipo'),
      ('{}', 'sem código'),
      ('{"error":"invalid_algo_novo"}', 'código desconhecido'),
    ]) {
      for (final String acao in const <String>['marcar', 'remover']) {
        test('400 $caso em $acao é recusa do acervo, sem "tente"', () async {
          final repo = AcervoRepositoryImpl(clienteFalso(AdapterFalso(corpo, status: 400)));

          final AppError? erro = acao == 'marcar'
              ? (await repo.marcar(TipoMidia.tv, 1399, EstadoAcervo.watched)).errorOrNull
              : (await repo.remover(TipoMidia.tv, 1399)).errorOrNull;

          expect(erro, isA<AcervoIndisponivelError>());
          expect(erro?.mensagem.toLowerCase(), isNot(contains('tent')));
        });
      }
    }

    test('500 em remover continua convidando a tentar de novo', () async {
      final repo = AcervoRepositoryImpl(clienteFalso(AdapterFalso('{}', status: 500)));

      final result = await repo.remover(TipoMidia.tv, 1399);

      expect(result.errorOrNull, isA<ServerError>(),
          reason: 'só o 400 é recusa definitiva; falha do servidor passa');
    });

    test('remover com 401 pede para entrar de novo', () async {
      final repo = AcervoRepositoryImpl(FakeRestClient(error: _erroHttp(401, <String, String>{})));

      final result = await repo.remover(TipoMidia.movie, 550);

      expect(result.errorOrNull, isA<UnauthorizedError>());
    });

    test('marcar manda tipo e estado no corpo e devolve o item salvo', () async {
      final FakeRestClient api = FakeRestClient()..respostaMarcar = _got;
      final repo = AcervoRepositoryImpl(api);

      final result = await repo.marcar(TipoMidia.tv, 1399, EstadoAcervo.watching);

      expect(result.valueOrNull?.estado, EstadoAcervo.watching);
      expect(api.idRecebido, 1399);
      expect(api.corpoRecebido?.tipo, TipoMidia.tv,
          reason: 'sem tipo o backend responde 400 invalid_tipo');
      expect(api.corpoRecebido?.estado, EstadoAcervo.watching);
    });

    test('estado desconhecido recusa antes da rede', () async {
      final FakeRestClient api = FakeRestClient();
      final repo = AcervoRepositoryImpl(api);

      final result = await repo.marcar(TipoMidia.movie, 1, EstadoAcervo.desconhecido);

      expect(result.errorOrNull, isA<AcervoIndisponivelError>());
      expect(api.chamadas, isEmpty);
    });

    test('tipo desconhecido recusa antes da rede', () async {
      final FakeRestClient api = FakeRestClient();
      final repo = AcervoRepositoryImpl(api);

      final result = await repo.marcar(TipoMidia.desconhecido, 1, EstadoAcervo.watched);

      expect(result.errorOrNull, isA<AcervoIndisponivelError>());
      expect(api.chamadas, isEmpty);
    });

    test('marcar com 401 vira UnauthorizedError', () async {
      final repo = AcervoRepositoryImpl(FakeRestClient(error: _erroHttp(401, <String, String>{})));

      final result = await repo.marcar(TipoMidia.movie, 1, EstadoAcervo.watched);

      expect(result.errorOrNull, isA<UnauthorizedError>());
    });

    test('remover passa o tipo, para não apagar o outro título de mesmo id', () async {
      final FakeRestClient api = FakeRestClient();
      final repo = AcervoRepositoryImpl(api);

      // série, não filme: com 'movie' chumbado no código o teste passaria à toa
      final result = await repo.remover(TipoMidia.tv, 550);

      expect(result.isOk, isTrue);
      expect(api.removido, 'tv:550');
    });

    test('remover com tipo desconhecido recusa antes da rede', () async {
      final FakeRestClient api = FakeRestClient();

      final result = await AcervoRepositoryImpl(api).remover(TipoMidia.desconhecido, 550);

      expect(result.errorOrNull, isA<AcervoIndisponivelError>());
      expect(api.chamadas, isEmpty,
          reason: 'DELETE sem tipo apaga as duas linhas daquele id');
    });

    test('remover título que não estava no acervo vira NotFoundError', () async {
      final repo = AcervoRepositoryImpl(FakeRestClient(
        error: _erroHttp(404, <String, String>{'error': 'not_found'}, path: '/api/v1/acervo/550'),
      ));

      final result = await repo.remover(TipoMidia.movie, 550);

      expect(result.errorOrNull, isA<NotFoundError>());
    });
  });

  group('AcervoRepositoryImpl', () {
    test('devolve Ok com os itens que o backend mandou', () async {
      final repo = AcervoRepositoryImpl(FakeRestClient()..respostaAcervo = const <AcervoItem>[_got]);

      final result = await repo.listar();

      expect(result.valueOrNull?.single.titulo, 'Game of Thrones');
    });

    test('acervo vazio é Ok com lista vazia, não é erro', () async {
      final repo = AcervoRepositoryImpl(FakeRestClient()
        ..respostaAcervo = const <AcervoItem>[]);

      final result = await repo.listar();

      expect(result.valueOrNull, isEmpty);
      expect(result.errorOrNull, isNull);
    });

    test('traduz 401 do backend em UnauthorizedError', () async {
      final repo = AcervoRepositoryImpl(
        FakeRestClient(error: _erroHttp(401, <String, String>{'error': 'unauthorized'})),
      );

      final result = await repo.listar();

      expect(result.errorOrNull, isA<UnauthorizedError>());
      expect(result.errorOrNull?.mensagem, const UnauthorizedError().mensagem);
    });

    test('resposta em formato inesperado não escapa como exceção crua', () async {
      final repo = AcervoRepositoryImpl(FakeRestClient(error: StateError('json quebrado')));

      final result = await repo.listar();

      expect(result.errorOrNull, isA<ServerError>());
    });
  });
}
