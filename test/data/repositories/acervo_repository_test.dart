import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/titulos_response.dart';
import 'package:appseries/data/repositories/acervo_repository_impl.dart';
import 'package:appseries/data/services/rest_client.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appseries/data/api_models/marcar_acervo_request.dart';
import 'package:appseries/data/api_models/preferencias.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';

/// Dublê do RestClient: nenhum teste desta camada toca a rede.
class _FakeRestClient implements RestClient {
  _FakeRestClient({this.itens, this.error});

  final List<AcervoItem>? itens;
  final Object? error;

  AcervoItem? respostaMarcar;
  int? idRecebido;
  MarcarAcervoRequest? corpoRecebido;
  String? removido;

  @override
  Future<List<AcervoItem>> acervo() async {
    if (error != null) throw error!;
    return itens!;
  }


  @override
  Future<TitulosResponse> emAlta() => throw UnimplementedError();

  @override
  Future<TitulosResponse> populares() => throw UnimplementedError();

  @override
  Future<TitulosResponse> busca(String q) => throw UnimplementedError();

  @override
  Future<TituloDetalhe> titulo(int tmdbId, String tipo) => throw UnimplementedError();

  @override
  Future<AcervoItem> marcar(int tmdbId, MarcarAcervoRequest corpo) async {
    idRecebido = tmdbId;
    corpoRecebido = corpo;
    if (error != null) throw error!;
    return respostaMarcar!;
  }

  @override
  Future<void> remover(int tmdbId, String tipo) async {
    if (error != null) throw error!;
    removido = '$tipo:$tmdbId';
  }

  @override
  Future<Preferencias> preferencias() => throw UnimplementedError();

  @override
  Future<Preferencias> salvarPreferencias(Preferencias corpo) => throw UnimplementedError();
}

AcervoItem _item({
  required int tmdbId,
  EstadoAcervo estado = EstadoAcervo.planToWatch,
  TipoMidia? tipo = TipoMidia.movie,
}) =>
    AcervoItem(tmdbId: tmdbId, estado: estado, tipo: tipo, titulo: 'Título $tmdbId');

DioException _erroHttp(int statusCode, Object corpo) => DioException.badResponse(
      statusCode: statusCode,
      requestOptions: RequestOptions(path: '/api/v1/acervo'),
      response: Response<Object>(
        requestOptions: RequestOptions(path: '/api/v1/acervo'),
        statusCode: statusCode,
        data: corpo,
      ),
    );

void main() {
  group('marcar e remover', () {
    test('marcar manda tipo e estado no corpo e devolve o item salvo', () async {
      final _FakeRestClient api = _FakeRestClient(itens: const <AcervoItem>[])
        ..respostaMarcar = const AcervoItem(
          tmdbId: 1399,
          estado: EstadoAcervo.watching,
          tipo: TipoMidia.tv,
          titulo: 'Game of Thrones',
        );
      final repo = AcervoRepositoryImpl(api);

      final result = await repo.marcar(TipoMidia.tv, 1399, EstadoAcervo.watching);

      expect(result.valueOrNull?.estado, EstadoAcervo.watching);
      expect(api.idRecebido, 1399);
      expect(api.corpoRecebido?.tipo, TipoMidia.tv,
          reason: 'sem tipo o backend responde 400 invalid_tipo');
      expect(api.corpoRecebido?.estado, EstadoAcervo.watching);
    });

    test('marcar com 401 vira UnauthorizedError', () async {
      final repo = AcervoRepositoryImpl(_FakeRestClient(
        error: DioException.badResponse(
          statusCode: 401,
          requestOptions: RequestOptions(path: '/api/v1/acervo/1'),
          response: Response<void>(
            requestOptions: RequestOptions(path: '/api/v1/acervo/1'),
            statusCode: 401,
          ),
        ),
      ));

      final result = await repo.marcar(TipoMidia.movie, 1, EstadoAcervo.watched);

      expect(result.errorOrNull, isA<UnauthorizedError>());
    });

    test('remover passa o tipo, para não apagar o outro título de mesmo id', () async {
      final _FakeRestClient api = _FakeRestClient(itens: const <AcervoItem>[]);
      final repo = AcervoRepositoryImpl(api);

      // série, não filme: com 'movie' chumbado no código o teste passaria à toa
      final result = await repo.remover(TipoMidia.tv, 550);

      expect(result.isOk, isTrue);
      expect(api.removido, 'tv:550');
    });

    test('remover título que não estava no acervo vira NotFoundError', () async {
      final repo = AcervoRepositoryImpl(_FakeRestClient(
        error: DioException.badResponse(
          statusCode: 404,
          requestOptions: RequestOptions(path: '/api/v1/acervo/550'),
          response: Response<void>(
            requestOptions: RequestOptions(path: '/api/v1/acervo/550'),
            statusCode: 404,
          ),
        ),
      ));

      final result = await repo.remover(TipoMidia.movie, 550);

      expect(result.errorOrNull, isA<NotFoundError>());
    });
  });

  group('AcervoRepositoryImpl', () {
    test('devolve Ok com os itens que o backend mandou', () async {
      final repo = AcervoRepositoryImpl(
        _FakeRestClient(itens: <AcervoItem>[
          _item(tmdbId: 1399, estado: EstadoAcervo.watching, tipo: TipoMidia.tv),
          _item(tmdbId: 550),
        ]),
      );

      final result = await repo.listar();

      expect(result, isA<Ok<List<AcervoItem>>>());
      expect(result.valueOrNull, hasLength(2));
      expect(result.valueOrNull?.first.estado, EstadoAcervo.watching);
    });

    test('acervo vazio é Ok com lista vazia, não é erro', () async {
      final repo = AcervoRepositoryImpl(_FakeRestClient(itens: <AcervoItem>[]));

      final result = await repo.listar();

      expect(result, isA<Ok<List<AcervoItem>>>());
      expect(result.valueOrNull, isEmpty);
    });

    test('traduz 401 do backend em UnauthorizedError', () async {
      final repo = AcervoRepositoryImpl(
        _FakeRestClient(error: _erroHttp(401, <String, String>{'error': 'unauthorized'})),
      );

      final result = await repo.listar();

      expect(result.errorOrNull, isA<UnauthorizedError>());
      expect(result.errorOrNull?.codigo, 'unauthorized');
    });

    test('resposta em formato inesperado não escapa como exceção crua', () async {
      final repo = AcervoRepositoryImpl(
        _FakeRestClient(error: const FormatException('corpo em formato inesperado')),
      );

      final result = await repo.listar();

      expect(result.errorOrNull, isA<ServerError>());
      expect(result.valueOrNull, isNull);
    });
  });
}
