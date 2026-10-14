import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/repositories/health_repository_impl.dart';
import 'package:appseries/data/services/rest_client.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dublê do RestClient: nenhum teste desta camada toca a rede.
class _FakeRestClient implements RestClient {
  _FakeRestClient({this.status, this.erro});

  final HealthStatus? status;
  final DioException? erro;

  @override
  Future<HealthStatus> health() async {
    if (erro != null) throw erro!;
    return status!;
  }
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

      final resultado = await repo.check();

      expect(resultado, isA<Ok<HealthStatus>>());
      expect(resultado.valueOrNull?.status, 'ok');
    });

    test('traduz 401 do backend em UnauthorizedError', () async {
      final repo = HealthRepositoryImpl(
        _FakeRestClient(erro: _erroHttp(401, <String, String>{'error': 'unauthorized'})),
      );

      final resultado = await repo.check();

      expect(resultado.errorOrNull, isA<UnauthorizedError>());
      expect(resultado.errorOrNull?.codigo, 'unauthorized');
    });

    test('traduz queda de conexão em NetworkError', () async {
      final repo = HealthRepositoryImpl(
        _FakeRestClient(
          erro: DioException.connectionError(
            requestOptions: RequestOptions(path: '/health'),
            reason: 'sem rede',
          ),
        ),
      );

      final resultado = await repo.check();

      expect(resultado.errorOrNull, isA<NetworkError>());
    });

    test('traduz 500 sem corpo de erro em ServerError', () async {
      final repo = HealthRepositoryImpl(_FakeRestClient(erro: _erroHttp(500, 'boom')));

      final resultado = await repo.check();

      expect(resultado.errorOrNull, isA<ServerError>());
    });

    test('traduz 503 auth_unconfigured em ServerError, e não em sessão expirada', () async {
      final repo = HealthRepositoryImpl(
        _FakeRestClient(erro: _erroHttp(503, <String, String>{'error': 'auth_unconfigured'})),
      );

      final resultado = await repo.check();

      expect(resultado.errorOrNull, isA<ServerError>());
      expect(resultado.errorOrNull?.mensagem, isNot(contains('sessão')));
    });
  });
}
