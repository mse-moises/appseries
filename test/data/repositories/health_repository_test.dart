import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/repositories/health_repository_impl.dart';
import 'package:appseries/data/services/rest_client.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dublê do RestClient: nenhum teste desta camada toca a rede.
class _FakeRestClient implements RestClient {
  _FakeRestClient({this.status, this.error});

  final HealthStatus? status;
  final Object? error;

  @override
  Future<HealthStatus> health() async {
    if (error != null) throw error!;
    return status!;
  }

  /// Not used by this test: the contract grew with the acervo endpoint (AP-28)
  /// and every double of `RestClient` has to answer it.
  @override
  Future<List<AcervoItem>> acervo() => throw UnimplementedError();
}

DioException _erroHttp(int statusCode, Object corpo) => DioException.badResponse(
      statusCode: statusCode,
      requestOptions: RequestOptions(path: '/health'),
      response: Response<Object>(
        requestOptions: RequestOptions(path: '/health'),
        statusCode: statusCode,
        data: corpo,
      ),
    );

void main() {
  group('HealthRepositoryImpl', () {
    test('devolve Ok quando o backend responde', () async {
      final repo = HealthRepositoryImpl(
        _FakeRestClient(status: const HealthStatus(status: 'ok')),
      );

      final result = await repo.check();

      expect(result, isA<Ok<HealthStatus>>());
      expect(result.valueOrNull?.status, 'ok');
    });

    test('traduz 401 do backend em UnauthorizedError', () async {
      final repo = HealthRepositoryImpl(
        _FakeRestClient(error: _erroHttp(401, <String, String>{'error': 'unauthorized'})),
      );

      final result = await repo.check();

      expect(result.errorOrNull, isA<UnauthorizedError>());
      expect(result.errorOrNull?.codigo, 'unauthorized');
    });

    test('traduz queda de conexão em NetworkError', () async {
      final repo = HealthRepositoryImpl(
        _FakeRestClient(
          error: DioException.connectionError(
            requestOptions: RequestOptions(path: '/health'),
            reason: 'sem rede',
          ),
        ),
      );

      final result = await repo.check();

      expect(result.errorOrNull, isA<NetworkError>());
    });

    test('traduz 500 sem corpo de erro em ServerError', () async {
      final repo = HealthRepositoryImpl(_FakeRestClient(error: _erroHttp(500, 'boom')));

      final result = await repo.check();

      expect(result.errorOrNull, isA<ServerError>());
    });

    test('traduz 503 auth_unconfigured em ServerError, e não em sessão expirada', () async {
      final repo = HealthRepositoryImpl(
        _FakeRestClient(error: _erroHttp(503, <String, String>{'error': 'auth_unconfigured'})),
      );

      final result = await repo.check();

      expect(result.errorOrNull, isA<ServerError>());
      expect(result.errorOrNull?.mensagem, isNot(contains('sessão')));
    });

    test('resposta em formato inesperado não escapa como exceção crua', () async {
      final repo = HealthRepositoryImpl(
        _FakeRestClient(error: const FormatException('corpo em formato inesperado')),
      );

      final result = await repo.check();

      expect(result.errorOrNull, isA<ServerError>());
      expect(result.valueOrNull, isNull);
    });
  });
}
