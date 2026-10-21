import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/titulos_response.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/titulo_repository_impl.dart';
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
  _FakeRestClient({this.respostaEmAlta, this.respostaPopulares, this.error});

  final TitulosResponse? respostaEmAlta;
  final TitulosResponse? respostaPopulares;
  final Object? error;

  TitulosResponse? respostaBusca;
  TituloDetalhe? respostaTitulo;
  String? qRecebida;
  String? tipoRecebido;
  int? idRecebido;

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

  @override
  Future<TitulosResponse> busca(String q) async {
    qRecebida = q;
    if (error != null) throw error!;
    return respostaBusca!;
  }

  @override
  Future<TituloDetalhe> titulo(int tmdbId, String tipo) async {
    idRecebido = tmdbId;
    tipoRecebido = tipo;
    if (error != null) throw error!;
    return respostaTitulo!;
  }

  @override
  Future<AcervoItem> marcar(int tmdbId, MarcarAcervoRequest corpo) => throw UnimplementedError();

  @override
  Future<void> remover(int tmdbId, String tipo) => throw UnimplementedError();

  @override
  Future<Preferencias> preferencias() => throw UnimplementedError();

  @override
  Future<Preferencias> salvarPreferencias(Preferencias corpo) => throw UnimplementedError();
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
  group('busca e detalhe', () {
    test('busca devolve os itens e repassa a consulta', () async {
      final _FakeRestClient api = _FakeRestClient()
        ..respostaBusca = TitulosResponse(resultados: <TmdbItem>[_item(4)]);
      final repo = TituloRepositoryImpl(api);

      final result = await repo.buscar('game');

      expect(result.valueOrNull, hasLength(1));
      expect(result.errorOrNull, isNull);
    });

    test('busca com falha de rede vira NetworkError', () async {
      final repo = TituloRepositoryImpl(_FakeRestClient(
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/v1/busca'),
          reason: 'sem rede',
        ),
      ));

      final result = await repo.buscar('game');

      expect(result.errorOrNull, isA<NetworkError>());
    });

    test('detalhe manda tipo na query e id no caminho', () async {
      final _FakeRestClient api = _FakeRestClient()
        ..respostaTitulo = const TituloDetalhe(id: 1399, tipo: TipoMidia.tv, titulo: 'GoT');
      final repo = TituloRepositoryImpl(api);

      final result = await repo.titulo(TipoMidia.tv, 1399);

      expect(result.valueOrNull?.titulo, 'GoT');
      expect(api.tipoRecebido, 'tv', reason: 'o backend recusa tipo ausente (400 invalid_tipo)');
      expect(api.idRecebido, 1399);
    });

    test('detalhe de título que não existe vira NotFoundError', () async {
      final repo = TituloRepositoryImpl(_FakeRestClient(
        error: _erroHttp(404, <String, String>{'error': 'not_found'}),
      ));

      final result = await repo.titulo(TipoMidia.movie, 1);

      expect(result.errorOrNull, isA<NotFoundError>());
    });
  });

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
        _FakeRestClient(error: _erroHttp(502, <String, String>{'error': 'tmdb_error'})),
      );

      final result = await repo.emAlta();

      expect(result.errorOrNull, isA<ServerError>());
      expect(result.errorOrNull?.mensagem, const ServerError().mensagem);
    });

    test('401 sem corpo de erro vira UnauthorizedError (sessão expirada)', () async {
      final repo = TituloRepositoryImpl(
        _FakeRestClient(error: _erroHttp(401, <String, String>{})),
      );

      final result = await repo.emAlta();

      expect(result.errorOrNull, isA<UnauthorizedError>());
      expect(result.errorOrNull?.mensagem, const UnauthorizedError().mensagem);
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
      expect(result.errorOrNull?.mensagem, const ServerError().mensagem);
      expect(result.valueOrNull, isNull);
    });
  });
}
