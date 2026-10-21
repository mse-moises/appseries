import 'dart:typed_data';

import 'package:appseries/data/services/rest_client.dart';
import 'package:dio/dio.dart';

/// Adapter de mentira: nenhum teste de fio toca a rede.
///
/// Serve JSON cru e guarda a última [RequestOptions], que é onde está o contrato
/// (método, caminho, query e corpo).
class AdapterFalso implements HttpClientAdapter {
  AdapterFalso(this.corpo, {this.status = 200});

  final String corpo;
  final int status;
  late RequestOptions ultima;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultima = options;
    return ResponseBody.fromString(
      corpo,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

RestClient clienteFalso(AdapterFalso adaptador) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://exemplo.test'));
  dio.httpClientAdapter = adaptador;
  return RestClient(dio);
}
