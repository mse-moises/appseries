import 'dart:typed_data';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/marcar_acervo_request.dart';
import 'package:appseries/data/api_models/preferencias.dart';
import 'package:appseries/data/services/rest_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prova o **fio**: método, caminho, query e corpo de cada endpoint novo.
///
/// Sem este arquivo, todos os outros testes trocam o `RestClient` por um dublê —
/// e um typo em `@GET('/api/v1/titulos/{tmdbId}')` ou um `@Query('tipo')`
/// esquecido deixariam a suíte inteira verde enquanto o app toma 404/400.
class _AdapterFalso implements HttpClientAdapter {
  _AdapterFalso(this.corpo, {this.status = 200});

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

RestClient _cliente(_AdapterFalso adaptador) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://exemplo.test'));
  dio.httpClientAdapter = adaptador;
  return RestClient(dio);
}

const String _itemJson =
    '{"tmdbId":1399,"estado":"watching","tipo":"tv","titulo":"Game of Thrones","ano":"2011"}';

void main() {
  group('RestClient — contrato de fio', () {
    test('busca vai para /api/v1/busca com a consulta em q', () async {
      final _AdapterFalso a = _AdapterFalso(
        '{"resultados":[{"id":1399,"tipo":"tv","titulo":"Game of Thrones","ano":"2011"}]}',
      );

      final resposta = await _cliente(a).busca('game of thrones');

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/busca');
      expect(a.ultima.queryParameters, <String, dynamic>{'q': 'game of thrones'});
      expect(resposta.resultados.single.titulo, 'Game of Thrones');
    });

    test('detalhe põe o id no caminho e o tipo na query', () async {
      final _AdapterFalso a = _AdapterFalso(
        '{"id":1399,"tipo":"tv","titulo":"Game of Thrones","sinopse":"x","nota":8.4,"generos":["Drama"]}',
      );

      final ficha = await _cliente(a).titulo(1399, 'tv');

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/titulos/1399');
      expect(a.ultima.queryParameters, <String, dynamic>{'tipo': 'tv'});
      expect(ficha.generos, <String>['Drama']);
    });

    test('marcar é PUT no acervo com estado e tipo no corpo', () async {
      final _AdapterFalso a = _AdapterFalso(_itemJson);

      await _cliente(a).marcar(
        1399,
        const MarcarAcervoRequest(estado: EstadoAcervo.watching, tipo: TipoMidia.tv),
      );

      expect(a.ultima.method, 'PUT');
      expect(a.ultima.path, '/api/v1/acervo/1399');
      expect(a.ultima.data, <String, dynamic>{'estado': 'watching', 'tipo': 'tv'});
    });

    test('remover é DELETE com o tipo na query e aceita 204 sem corpo', () async {
      final _AdapterFalso a = _AdapterFalso('', status: 204);

      await _cliente(a).remover(550, 'movie');

      expect(a.ultima.method, 'DELETE');
      expect(a.ultima.path, '/api/v1/acervo/550');
      expect(a.ultima.queryParameters, <String, dynamic>{'tipo': 'movie'});
    });

    test('ler preferências é GET em /api/v1/preferencias', () async {
      final _AdapterFalso a = _AdapterFalso('{"momento":"domingo","generos":["Drama"]}');

      final p = await _cliente(a).preferencias();

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/preferencias');
      expect(p.momento, 'domingo');
    });

    test('salvar preferências é PUT com momento e gêneros no corpo', () async {
      final _AdapterFalso a = _AdapterFalso('{"momento":"domingo","generos":["Drama"]}');

      await _cliente(a).salvarPreferencias(
        const Preferencias(momento: 'domingo', generos: <String>['Drama']),
      );

      expect(a.ultima.method, 'PUT');
      expect(a.ultima.path, '/api/v1/preferencias');
      expect(a.ultima.data, <String, dynamic>{'momento': 'domingo', 'generos': <String>['Drama']});
    });
  });
}
