import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/titulos_response.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/titulo_repository_impl.dart';
import 'package:appseries/data/services/rest_client.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dublê do RestClient: nenhum teste desta camada toca a rede.
class _FakeRestClient implements RestClient {
  _FakeRestClient({this.respostaEmAlta, this.respostaPopulares, this.error});

  final TitulosResponse? respostaEmAlta;
  final TitulosResponse? respostaPopulares;
  final Object? error;

  @override
  Future<TitulosResponse> emAlta() async {
    if (error != null) throw error!;
    return respostaEmAlta!;
  }

  @override
  Future<TitulosResponse> populares() async {
    if (error != null) throw error!;
    return respostaPopulares!;
  }

  @override
  Future<List<AcervoItem>> acervo() => throw UnimplementedError();

}

TmdbItem _item(int id, {String tipo = 'movie', String? posterPath = '/p.jpg'}) => TmdbItem(
      id: id,
      tipo: tipo == 'movie' ? TipoMidia.movie : TipoMidia.tv,
      titulo: 'Título $id',
      ano: '2025',
      posterPath: posterPath,
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
  group('TituloRepositoryImpl', () {
    test('devolve Ok com os itens do em alta', () async {
      final repo = TituloRepositoryImpl(
        _FakeRestClient(
          respostaEmAlta: TitulosResponse(resultados: <TmdbItem>[_item(1), _item(2)]),
          respostaPopulares: const TitulosResponse(resultados: <TmdbItem>[]),
        ),
      );

      final result = await repo.emAlta();

      expect(result, isA<Ok<List<TmdbItem>>>());
      expect(result.valueOrNull, hasLength(2));
      expect(result.valueOrNull?.first.titulo, 'Título 1');
    });

    test('lista vazia é Ok com lista vazia, não é erro', () async {
      final repo = TituloRepositoryImpl(
        _FakeRestClient(
          respostaEmAlta: const TitulosResponse(resultados: <TmdbItem>[]),
          respostaPopulares: const TitulosResponse(resultados: <TmdbItem>[]),
        ),
      );

      final result = await repo.populares();

      expect(result, isA<Ok<List<TmdbItem>>>());
      expect(result.valueOrNull, isEmpty);
    });

    test('traduz 502 do backend em ServerError', () async {
      final repo = TituloRepositoryImpl(
        _FakeRestClient(error: _erroHttp(502, <String, String>{'error': 'tmdb_unavailable'})),
      );

      final result = await repo.emAlta();

      expect(result.errorOrNull, isA<ServerError>());
    });

    test('queda de conexão vira NetworkError', () async {
      final repo = TituloRepositoryImpl(
        _FakeRestClient(
          error: DioException.connectionError(
            requestOptions: RequestOptions(path: '/api/v1/populares'),
            reason: 'sem rede',
          ),
        ),
      );

      final result = await repo.populares();

      expect(result.errorOrNull, isA<NetworkError>());
    });

    test('resposta em formato inesperado não escapa como exceção crua', () async {
      final repo = TituloRepositoryImpl(
        _FakeRestClient(error: const FormatException('corpo inesperado')),
      );

      final result = await repo.emAlta();

      expect(result.errorOrNull, isA<ServerError>());
      expect(result.valueOrNull, isNull);
    });
  });
}
