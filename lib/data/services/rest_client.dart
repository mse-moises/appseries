import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../api_models/acervo_item.dart';
import '../api_models/health_status.dart';
import '../api_models/titulos_response.dart';

part 'rest_client.g.dart';

/// Every backend call goes through here.
///
/// The Firebase id token is added by the Dio interceptor, so **no endpoint
/// takes a token parameter**. Run
/// `dart run build_runner build --delete-conflicting-outputs` after changing
/// this file (it generates `rest_client.g.dart`).
@RestApi()
abstract class RestClient {
  factory RestClient(Dio dio, {String? baseUrl}) = _RestClient;

  /// `GET /health` — the only endpoint that needs no auth.
  @GET('/health')
  Future<HealthStatus> health();

  /// `GET /api/v1/acervo` — everything the signed-in user marked, newest
  /// first. The server filters by the token's uid, so no user id goes here.
  @GET('/api/v1/acervo')
  Future<List<AcervoItem>> acervo();

  /// `GET /api/v1/em-alta` — 10 titles of the week, movies and series
  /// interleaved. The array comes inside `resultados`.
  @GET('/api/v1/em-alta')
  Future<TitulosResponse> emAlta();

  /// `GET /api/v1/populares` — 10 popular titles, same shape as [emAlta].
  @GET('/api/v1/populares')
  Future<TitulosResponse> populares();
}
