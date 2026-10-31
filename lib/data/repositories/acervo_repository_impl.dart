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
    final String? wire = tipoWire(tipo);
    if (wire == null) {
      // Tipo fora do contrato: o servidor recusaria com 400 e não há o que
      // atualizar no acervo, então nem vale a requisição.
      return const Result<AcervoItem>.error(AcervoIndisponivelError());
    }
    if (estado == EstadoAcervo.desconhecido) {
      // Guarda de contrato para chamador programático: o `AcervoActionButton` só
      // emite os quatro estados reais, então este ramo não vem da tela.
      return const Result<AcervoItem>.error(AcervoIndisponivelError());
    }
    try {
      final MarcarAcervoRequest corpo = MarcarAcervoRequest(estado: estado, tipo: tipo);
      return Result.ok(await _api.marcar(tmdbId, corpo));
    } on DioException catch (e) {
      return Result.error(_doAcervo(e));
    } catch (_) {
      return const Result<AcervoItem>.error(ServerError());
    }
  }

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) async {
    final String? wire = tipoWire(tipo);
    if (wire == null) return const Result<void>.error(AcervoIndisponivelError());
    try {
      await _api.remover(tmdbId, wire);
      return const Result<void>.ok(null);
    } on DioException catch (e) {
      return Result.error(_doAcervo(e));
    } catch (_) {
      return const Result<void>.error(ServerError());
    }
  }

  /// A write the server refused fails the same way when repeated, so the
  /// shelf answers with its own sentence instead of a "tente de novo":
  ///
  /// - any `400`, whatever the code in the body: `invalid_estado`,
  ///   `invalid_tipo`, a code this app does not know yet, or none. Without this
  ///   check the last two would fall into [ServerError] ("Tente em instantes");
  /// - a `409`, and the codes `appErrorFromCodigo` maps to [ConflictError].
  ///
  /// Everything else keeps the general mapping of `appErrorFromDio`: a `500`
  /// still invites a retry, and a `401` asks to sign in again when its body has
  /// no code or the code `unauthorized` (another code goes through
  /// `appErrorFromCodigo`, as in every repository).
  static AppError _doAcervo(DioException e) {
    if (e.response?.statusCode == 400) return const AcervoIndisponivelError();
    final AppError erro = appErrorFromDio(e);
    return erro is ConflictError ? const AcervoIndisponivelError() : erro;
  }
}
