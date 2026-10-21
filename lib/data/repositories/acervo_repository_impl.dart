import 'package:dio/dio.dart';

import '../../utils/app_error.dart';
import '../../utils/result.dart';
import '../api_models/acervo_item.dart';
import '../api_models/marcar_acervo_request.dart';
import '../services/error_mapper.dart';
import '../services/rest_client.dart';
import 'acervo_repository.dart';

/// Talks to the backend through [RestClient] and answers `Future<Result<...>>`.
class AcervoRepositoryImpl implements AcervoRepository {
  AcervoRepositoryImpl(this._api);

  final RestClient _api;

  @override
  Future<Result<List<AcervoItem>>> listar() async {
    try {
      return Result.ok(await _api.acervo());
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      // Anything else (a body in an unexpected shape breaking fromJson, for
      // instance) must not escape either: the contract of a repository is to
      // always answer a Result, so no screen has to guard against a raw
      // exception — and the ViewModel cannot leave the screen loading forever.
      return const Result<List<AcervoItem>>.error(ServerError());
    }
  }

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) async {
    try {
      final MarcarAcervoRequest corpo = MarcarAcervoRequest(estado: estado, tipo: tipo);
      return Result.ok(await _api.marcar(tmdbId, corpo));
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      return const Result<AcervoItem>.error(ServerError());
    }
  }

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) async {
    try {
      await _api.remover(tmdbId, tipo.name);
      return const Result<void>.ok(null);
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      return const Result<void>.error(ServerError());
    }
  }
}
