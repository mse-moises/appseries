import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../api_models/acervo_item.dart';
import '../api_models/carta_rec.dart';
import '../api_models/feedback_item.dart';
import '../api_models/marcar_acervo_request.dart';
import '../api_models/marcar_feedback_request.dart';
import '../api_models/preferencias.dart';
import '../api_models/titulo_detalhe.dart';
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

  /// `GET /api/v1/busca?q=` — up to 10 titles, movies and series mixed.
  /// The backend rejects `q` shorter than 3 or longer than 100 characters
  /// (`400 query_too_short`), so the caller has to debounce before coming here.
  @GET('/api/v1/busca')
  Future<TitulosResponse> busca(@Query('q') String q);

  /// `GET /api/v1/titulos/:tmdbId?tipo=` — full sheet. `tipo` is obligatory on
  /// the query: the same id is two different titles in the TMDB.
  @GET('/api/v1/titulos/{tmdbId}')
  Future<TituloDetalhe> titulo(@Path('tmdbId') int tmdbId, @Query('tipo') String tipo);

  /// `PUT /api/v1/acervo/:tmdbId` — creates or updates the shelf line and
  /// answers the whole item (201 on create, 200 on update).
  @PUT('/api/v1/acervo/{tmdbId}')
  Future<AcervoItem> marcar(@Path('tmdbId') int tmdbId, @Body() MarcarAcervoRequest corpo);

  /// `DELETE /api/v1/acervo/:tmdbId?tipo=` — removes **that** line only. With no
  /// `tipo` the backend removes every line with that id (old behaviour).
  @DELETE('/api/v1/acervo/{tmdbId}')
  Future<void> remover(@Path('tmdbId') int tmdbId, @Query('tipo') String tipo);

  /// `GET /api/v1/preferencias` — moment + genres of the signed-in user.
  @GET('/api/v1/preferencias')
  Future<Preferencias> preferencias();

  /// `PUT /api/v1/preferencias` — upsert; echoes what was saved.
  @PUT('/api/v1/preferencias')
  Future<Preferencias> salvarPreferencias(@Body() Preferencias corpo);

  /// `GET /api/v1/feedback` — the 👍/👎 signals of the signed-in user, newest
  /// first. No pagination.
  @GET('/api/v1/feedback')
  Future<List<FeedbackItem>> feedback();

  /// `PUT /api/v1/feedback/:tmdbId` — creates or replaces the signal of that
  /// `(tipo, tmdbId)` and answers the whole item (201 on create, 200 on update).
  @PUT('/api/v1/feedback/{tmdbId}')
  Future<FeedbackItem> marcarFeedback(
    @Path('tmdbId') int tmdbId,
    @Body() MarcarFeedbackRequest corpo,
  );

  /// `DELETE /api/v1/feedback/:tmdbId?tipo=` — removes **that** signal only.
  @DELETE('/api/v1/feedback/{tmdbId}')
  Future<void> removerFeedback(@Path('tmdbId') int tmdbId, @Query('tipo') String tipo);

  /// `POST /api/v1/rec` — até 5 cartas pelo momento (mais gostos e histórico).
  ///
  /// Corpo vazio (`{}`) faz o servidor usar o momento salvo em `/preferencias`;
  /// com `{"momento": "..."}` o texto vale só nesta chamada.
  /// O teto é de 20 por dia (`429 rec_limit`).
  ///
  /// O parâmetro é não-nulo de propósito: com `Map?` o retrofit gerava
  /// `corpo!` dentro de um `if (corpo != null)` e o `flutter analyze` acusava
  /// `unnecessary_non_null_assertion` no arquivo gerado.
  @POST('/api/v1/rec')
  Future<RecResult> recomendar(@Body() Map<String, dynamic> corpo);
}
