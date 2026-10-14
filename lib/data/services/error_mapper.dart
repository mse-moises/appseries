import 'package:dio/dio.dart';

import '../../utils/app_error.dart';

/// Turns a [DioException] into the typed [AppError] the UI shows.
///
/// Repositories call this in their `on DioException catch` — the mapping lives
/// in one place so every feature answers the same way.
AppError appErrorFromDio(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return const NetworkError();
    case DioExceptionType.badResponse:
      final codigo = _codigoDoCorpo(e.response?.data);
      if (codigo != null) return appErrorFromCodigo(codigo);
      return switch (e.response?.statusCode) {
        401 || 403 => const UnauthorizedError(),
        404 => const NotFoundError(),
        409 => const ConflictError(),
        429 => const RateLimitError(),
        _ => const ServerError(),
      };
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return const ServerError();
  }
}

String? _codigoDoCorpo(Object? data) {
  if (data is Map && data['error'] is String) return data['error'] as String;
  return null;
}
