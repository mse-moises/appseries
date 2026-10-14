import 'package:dio/dio.dart';

import '../../utils/result.dart';
import '../api_models/health_status.dart';
import '../services/error_mapper.dart';
import '../services/rest_client.dart';
import 'health_repository.dart';

/// Talks to the backend through [RestClient] and answers `Future<Result<...>>`.
class HealthRepositoryImpl implements HealthRepository {
  HealthRepositoryImpl(this._api);

  final RestClient _api;

  @override
  Future<Result<HealthStatus>> check() async {
    try {
      return Result.ok(await _api.health());
    } on DioException catch (e) {
      return Result.error(appErrorFromDio(e));
    }
  }
}
