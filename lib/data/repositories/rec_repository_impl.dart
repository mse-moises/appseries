import 'package:dio/dio.dart';

import '../../utils/app_error.dart';
import '../../utils/result.dart';
import '../api_models/carta_rec.dart';
import '../services/error_mapper.dart';
import '../services/rest_client.dart';
import 'rec_repository.dart';

/// Fala com o `POST /api/v1/rec` e responde `Future<Result<...>>`.
class RecRepositoryImpl implements RecRepository {
  RecRepositoryImpl(this._api);

  final RestClient _api;

  @override
  Future<Result<RecResult>> recomendar({String? momento}) async {
    final String texto = (momento ?? '').trim();
    // Campo em branco = corpo vazio, e corpo vazio faz o servidor usar o
    // momento salvo nas preferências. Mandar `{"momento": ""}` faria o
    // contrário: pedir uma recomendação SEM momento nenhum.
    final Map<String, dynamic> corpo =
        texto.isEmpty ? const <String, dynamic>{} : <String, dynamic>{'momento': texto};

    try {
      return Result.ok(await _api.recomendar(corpo));
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      // Corpo fora do contrato não escapa: o repositório sempre responde um
      // Result, então nenhuma tela precisa se proteger de exceção crua.
      return const Result<RecResult>.error(ServerError());
    }
  }
}
