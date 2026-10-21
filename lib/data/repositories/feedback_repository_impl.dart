import 'package:dio/dio.dart';

import '../../utils/app_error.dart';
import '../../utils/result.dart';
import '../api_models/feedback_item.dart';
import '../api_models/marcar_feedback_request.dart';
import '../services/error_mapper.dart';
import '../services/rest_client.dart';
import 'feedback_repository.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  FeedbackRepositoryImpl(this._api);

  final RestClient _api;

  @override
  Future<Result<List<FeedbackItem>>> listar() async {
    try {
      return Result.ok(await _api.feedback());
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      return const Result<List<FeedbackItem>>.error(ServerError());
    }
  }

  @override
  Future<Result<FeedbackItem>> marcar(
    TipoMidia tipo,
    int tmdbId,
    SinalGosto sinal, {
    int peso = 2,
    OrigemFeedback origem = OrigemFeedback.fechamento,
  }) async {
    final String? wire = tipoWire(tipo);
    if (wire == null || sinal == SinalGosto.desconhecido) {
      // Valor que esta versão não conhece: o servidor recusaria com 400 e a
      // pessoa receberia "servidor escorregou" por um problema que não é dele.
      return const Result<FeedbackItem>.error(FeedbackIndisponivelError());
    }
    try {
      final MarcarFeedbackRequest corpo = MarcarFeedbackRequest(
        sinal: sinal,
        tipo: tipo,
        // Só 1 e 2 são válidos; qualquer outra coisa cai no default forte.
        peso: peso == 1 ? 1 : 2,
        origem: origem,
      );
      return Result.ok(await _api.marcarFeedback(tmdbId, corpo));
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      return const Result<FeedbackItem>.error(ServerError());
    }
  }

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) async {
    final String? wire = tipoWire(tipo);
    if (wire == null) return const Result<void>.error(FeedbackIndisponivelError());
    try {
      await _api.removerFeedback(tmdbId, wire);
      return const Result<void>.ok(null);
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      return const Result<void>.error(ServerError());
    }
  }
}
