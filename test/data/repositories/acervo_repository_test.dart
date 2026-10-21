import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/repositories/acervo_repository_impl.dart';
import 'package:appseries/data/services/rest_client.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dublê do RestClient: nenhum teste desta camada toca a rede.
class _FakeRestClient implements RestClient {
  _FakeRestClient({this.itens, this.error});

  final List<AcervoItem>? itens;
  final Object? error;

  @override
  Future<List<AcervoItem>> acervo() async {
    if (error != null) throw error!;
    return itens!;
  }

  @override
  Future<HealthStatus> health() => throw UnimplementedError();
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
