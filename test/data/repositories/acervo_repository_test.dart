import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/repositories/acervo_repository_impl.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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

      expect(result.errorOrNull, isA<ConflictError>());
      expect(api.chamadas, isEmpty);
    });

    test('tipo desconhecido recusa antes da rede', () async {
      final FakeRestClient api = FakeRestClient();
      final repo = AcervoRepositoryImpl(api);

      final result = await repo.marcar(TipoMidia.desconhecido, 1, EstadoAcervo.watched);

      expect(result.errorOrNull, isA<ConflictError>());
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
      final repo = AcervoRepositoryImpl(FakeRestClient(error: _erroHttp(401, <String, String>{})));

      final result = await repo.listar();

      expect(result.errorOrNull, isA<UnauthorizedError>());
    });

    test('resposta em formato inesperado não escapa como exceção crua', () async {
      final repo = AcervoRepositoryImpl(FakeRestClient(error: StateError('json quebrado')));

      final result = await repo.listar();

      expect(result.errorOrNull, isA<ServerError>());
    });
  });
}
