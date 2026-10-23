import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/titulos_response.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/titulo_repository_impl.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adapter_falso.dart';
import '../../support/fake_rest_client.dart';

TmdbItem _item(int id, {TipoMidia tipo = TipoMidia.movie}) => TmdbItem(
      id: id,
      tipo: tipo,
      titulo: 'Título $id',
      ano: '2025',
      posterPath: '/p.jpg',
    );

DioException _erroHttp(int statusCode, Object corpo) => DioException.badResponse(
      statusCode: statusCode,
      requestOptions: RequestOptions(path: '/api/v1/em-alta'),
      response: Response<Object>(
        requestOptions: RequestOptions(path: '/api/v1/em-alta'),
        statusCode: statusCode,
        data: corpo,
      ),
    );

void main() {
  group('busca e detalhe', () {
    test('busca devolve os itens e repassa a consulta', () async {
      final FakeRestClient api = FakeRestClient()
        ..respostaBusca = TitulosResponse(resultados: <TmdbItem>[_item(4)]);
      final repo = TituloRepositoryImpl(api);

      final result = await repo.buscar('game');

      expect(result.valueOrNull, hasLength(1));
      expect(result.errorOrNull, isNull);
      expect(api.qRecebida, 'game', reason: 'a query é o que o backend valida (3..100)');
    });

    test('busca com falha de rede vira NetworkError', () async {
      final repo = TituloRepositoryImpl(FakeRestClient(
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/v1/busca'),
          reason: 'sem rede',
        ),
      ));

      final result = await repo.buscar('game');

      expect(result.errorOrNull, isA<NetworkError>());
    });

    test('detalhe manda tipo na query e id no caminho', () async {
      final FakeRestClient api = FakeRestClient()
        ..respostaTitulo = const TituloDetalhe(id: 1399, tipo: TipoMidia.tv, titulo: 'GoT');
      final repo = TituloRepositoryImpl(api);

      final result = await repo.titulo(TipoMidia.tv, 1399);

      expect(result.valueOrNull?.titulo, 'GoT');
      expect(api.tipoRecebido, 'tv', reason: 'o backend recusa tipo ausente (400 invalid_tipo)');
      expect(api.idRecebido, 1399);
    });

    test('detalhe de título que não existe vira NotFoundError', () async {
      final repo = TituloRepositoryImpl(FakeRestClient(
        error: _erroHttp(404, <String, String>{'error': 'not_found'}),
      ));

      final result = await repo.titulo(TipoMidia.movie, 1);

      expect(result.errorOrNull, isA<NotFoundError>());
    });

    test('tipo desconhecido recusa antes da rede em vez de virar 400', () async {
      final FakeRestClient api = FakeRestClient();
      final repo = TituloRepositoryImpl(api);

      final result = await repo.titulo(TipoMidia.desconhecido, 1399);

      expect(result.errorOrNull, isA<TituloIndisponivelError>());
      expect(api.chamadas, isEmpty, reason: 'não vale gastar requisição que o servidor recusa');
    });
  });

  group('TituloRepositoryImpl', () {
    test('devolve Ok com os itens do em alta', () async {
      final repo = TituloRepositoryImpl(FakeRestClient()
        ..respostaEmAlta = TitulosResponse(resultados: <TmdbItem>[_item(1), _item(2, tipo: TipoMidia.tv)]));

      final result = await repo.emAlta();

      expect(result.valueOrNull?.map((TmdbItem t) => t.id), <int>[1, 2]);
    });

    test('lista vazia é Ok com lista vazia, não é erro', () async {
      final repo = TituloRepositoryImpl(FakeRestClient()
        ..respostaPopulares = const TitulosResponse(resultados: <TmdbItem>[]));

      final result = await repo.populares();

      expect(result.valueOrNull, isEmpty);
      expect(result.errorOrNull, isNull);
    });

    test('502 tmdb_error vira catálogo fora do ar, não erro de servidor', () async {
      final repo = TituloRepositoryImpl(
        FakeRestClient(error: _erroHttp(502, <String, String>{'error': 'tmdb_error'})),
      );

      final result = await repo.emAlta();

      expect(result.errorOrNull, isA<CatalogoIndisponivelError>());
      expect(result.errorOrNull?.mensagem, const CatalogoIndisponivelError().mensagem);
    });

    test('502 sem corpo continua sendo erro de servidor', () async {
      final repo = TituloRepositoryImpl(FakeRestClient(error: _erroHttp(502, '')));

      final result = await repo.emAlta();

      expect(result.errorOrNull, isA<ServerError>());
    });

    test('429 do TMDB na busca vira CatalogoOcupadoError, não erro de servidor', () async {
      final repo = TituloRepositoryImpl(
        FakeRestClient(error: _erroHttp(429, <String, String>{'error': 'tmdb_rate_limited'})),
      );

      final result = await repo.buscar('pokemon');

      expect(result.errorOrNull, isA<CatalogoOcupadoError>());
    });

    test('código do corpo vence o status HTTP', () async {
      final repo = TituloRepositoryImpl(
        FakeRestClient(error: _erroHttp(400, <String, String>{'error': 'query_too_short'})),
      );

      final result = await repo.buscar('a');

      expect(result.errorOrNull, isA<BuscaInvalidaError>());
      expect(result.errorOrNull?.mensagem, const BuscaInvalidaError().mensagem);
    });

    test('401 sem corpo de erro vira UnauthorizedError (sessão expirada)', () async {
      final repo = TituloRepositoryImpl(FakeRestClient(error: _erroHttp(401, <String, String>{})));

      final result = await repo.emAlta();

      expect(result.errorOrNull, isA<UnauthorizedError>());
      expect(result.errorOrNull?.mensagem, const UnauthorizedError().mensagem);
    });

    test('queda de conexão vira NetworkError', () async {
      final repo = TituloRepositoryImpl(FakeRestClient(
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/v1/populares'),
          reason: 'sem rede',
        ),
      ));

      final result = await repo.populares();

      expect(result.errorOrNull, isA<NetworkError>());
    });

    test('resposta em formato inesperado não escapa como exceção crua', () async {
      final repo = TituloRepositoryImpl(FakeRestClient(error: StateError('json quebrado')));

      final result = await repo.emAlta();

      expect(result.errorOrNull, isA<ServerError>());
    });

    test('corpo de erro real do Dio é decodificado (não só a exceção feita à mão)', () async {
      // o DioException dos outros testes já nasce com `data` Map; aqui o corpo
      // passa pelo pipeline real do Dio
      final AdapterFalso a = AdapterFalso('{"error":"query_too_short"}', status: 400);

      final result = await TituloRepositoryImpl(clienteFalso(a)).buscar('a');

      expect(result.errorOrNull, isA<BuscaInvalidaError>());
    });

    test('código do corpo vence um status que tem mapa próprio (401)', () async {
      // 401 sozinho viraria UnauthorizedError; com código no corpo, o código manda
      final AdapterFalso a = AdapterFalso('{"error":"query_too_short"}', status: 401);

      final result = await TituloRepositoryImpl(clienteFalso(a)).buscar('a');

      expect(result.errorOrNull, isA<BuscaInvalidaError>());
    });

    test('corpo que não é JSON não sequestra o mapa por status', () async {
      final AdapterFalso a = AdapterFalso('<html>502</html>', status: 502);

      final result = await TituloRepositoryImpl(clienteFalso(a)).emAlta();

      expect(result.errorOrNull, isA<ServerError>());
    });

    test('JSON fora de forma vira ServerError no caminho real de decodificação', () async {
      // não é exceção do dublê: é o fromJson estourando de verdade
      final AdapterFalso a = AdapterFalso('{"resultados":"não é lista"}');

      final result = await TituloRepositoryImpl(clienteFalso(a)).emAlta();

      expect(result.errorOrNull, isA<ServerError>());
    });
  });
}
