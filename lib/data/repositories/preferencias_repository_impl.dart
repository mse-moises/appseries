import 'package:dio/dio.dart';

import '../../utils/app_error.dart';
import '../../utils/result.dart';
import '../api_models/preferencias.dart';
import '../services/error_mapper.dart';
import '../services/rest_client.dart';
import 'preferencias_repository.dart';

/// Talks to the backend through [RestClient] and answers `Future<Result<...>>`.
class PreferenciasRepositoryImpl implements PreferenciasRepository {
  PreferenciasRepositoryImpl(this._api);

  final RestClient _api;

  @override
  Future<Result<Preferencias>> ler() => _chamar(_api.preferencias);

  @override
  Future<Result<Preferencias>> salvar(Preferencias preferencias) =>
      _chamar(() => _api.salvarPreferencias(preferencias));

  Future<Result<Preferencias>> _chamar(Future<Preferencias> Function() chamada) async {
    try {
      return Result.ok(await chamada());
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    } catch (_) {
      // A body out of the contract must not escape: the repository always
      // answers a Result, so no screen has to guard against a raw exception.
      return const Result<Preferencias>.error(ServerError());
    }
  }
}
