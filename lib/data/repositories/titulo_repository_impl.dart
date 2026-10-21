import 'package:dio/dio.dart';

import '../../utils/app_error.dart';
import '../../utils/result.dart';
import '../api_models/titulo_detalhe.dart';
import '../api_models/titulos_response.dart';
import '../api_models/tmdb_item.dart';
import '../services/error_mapper.dart';
import '../services/rest_client.dart';
import 'titulo_repository.dart';

/// Talks to the backend through [RestClient] and answers `Future<Result<...>>`.
///
/// Both endpoints have the same shape and the same failure modes, so the
/// try/catch lives in one helper instead of being copied per method.
class TituloRepositoryImpl implements TituloRepository {
  TituloRepositoryImpl(this._api);

  final RestClient _api;

  @override
  Future<Result<List<TmdbItem>>> emAlta() => _lista(_api.emAlta);

  @override
  Future<Result<List<TmdbItem>>> populares() => _lista(_api.populares);

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) => _lista(() => _api.busca(q));

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) async {
    final String? wire = tipoWire(tipo);
    if (wire == null) {
      // Tipo desconhecido veio de uma resposta mais nova que este app: o backend
      // responderia 400 invalid_tipo, então nem vale gastar a requisição.
      return const Result<TituloDetalhe>.error(TituloIndisponivelError());
    }
    try {
      return Result.ok(await _api.titulo(tmdbId, wire));
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      return const Result<TituloDetalhe>.error(ServerError());
    }
  }

  Future<Result<List<TmdbItem>>> _lista(Future<TitulosResponse> Function() chamada) async {
    try {
      final TitulosResponse resposta = await chamada();
      return Result.ok(resposta.resultados);
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      // A body in an unexpected shape (breaking fromJson, for instance) must
      // not escape either: the contract of a repository is to always answer a
      // Result, and the carousel cannot stay loading forever.
      return const Result<List<TmdbItem>>.error(ServerError());
    }
  }
}
