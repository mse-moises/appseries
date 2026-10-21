import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/api_models/marcar_acervo_request.dart';
import 'package:appseries/data/api_models/marcar_feedback_request.dart';
import 'package:appseries/data/api_models/preferencias.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adapter_falso.dart';

/// Prova o **fio de cada método do RestClient**: método, caminho, query e corpo.
///
/// Sem este arquivo, todos os outros testes trocam o `RestClient` por um dublê —
/// e um typo em `@GET('/api/v1/em-alta')` ou um `@Query('tipo')` esquecido
/// deixariam a suíte inteira verde enquanto o app toma 404/400.
const String _itemJson =
    '{"tmdbId":1399,"estado":"watching","tipo":"tv","titulo":"Game of Thrones","ano":"2011"}';
const String _listaJson =
    '{"resultados":[{"id":1399,"tipo":"tv","titulo":"Game of Thrones","ano":"2011"}]}';

void main() {
  group('RestClient — contrato de fio', () {
    test('acervo é GET em /api/v1/acervo e recebe um array no topo', () async {
      final AdapterFalso a = AdapterFalso('[$_itemJson]');

      final itens = await clienteFalso(a).acervo();

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/acervo');
      expect(a.ultima.queryParameters, isEmpty);
      expect(itens.single.titulo, 'Game of Thrones');
      expect(itens.single.estado, EstadoAcervo.watching);
    });

    test('em alta é GET em /api/v1/em-alta e desembrulha resultados', () async {
      final AdapterFalso a = AdapterFalso(_listaJson);

      final resposta = await clienteFalso(a).emAlta();

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/em-alta');
      expect(a.ultima.queryParameters, isEmpty);
      expect(resposta.resultados.single.titulo, 'Game of Thrones');
    });

    test('populares é GET em /api/v1/populares', () async {
      final AdapterFalso a = AdapterFalso(_listaJson);

      final resposta = await clienteFalso(a).populares();

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/populares');
      expect(a.ultima.queryParameters, isEmpty);
      expect(resposta.resultados, hasLength(1));
    });

    test('busca vai para /api/v1/busca com a consulta em q', () async {
      final AdapterFalso a = AdapterFalso(_listaJson);

      final resposta = await clienteFalso(a).busca('game of thrones');

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/busca');
      expect(a.ultima.queryParameters, <String, dynamic>{'q': 'game of thrones'});
      expect(resposta.resultados.single.titulo, 'Game of Thrones');
    });

    test('detalhe põe o id no caminho e o tipo na query', () async {
      final AdapterFalso a = AdapterFalso(
        '{"id":1399,"tipo":"tv","titulo":"Game of Thrones","sinopse":"x","nota":8.4,"generos":["Drama"]}',
      );

      final ficha = await clienteFalso(a).titulo(1399, 'tv');

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/titulos/1399');
      expect(a.ultima.queryParameters, <String, dynamic>{'tipo': 'tv'});
      expect(ficha.generos, <String>['Drama']);
    });

    test('marcar é PUT no acervo com estado e tipo no corpo', () async {
      final AdapterFalso a = AdapterFalso(_itemJson);

      await clienteFalso(a).marcar(
        1399,
        const MarcarAcervoRequest(estado: EstadoAcervo.watching, tipo: TipoMidia.tv),
      );

      expect(a.ultima.method, 'PUT');
      expect(a.ultima.path, '/api/v1/acervo/1399');
      expect(a.ultima.data, <String, dynamic>{'estado': 'watching', 'tipo': 'tv'});
      expect(a.ultima.contentType, startsWith('application/json'));
    });

    test('remover é DELETE com o tipo na query e aceita 204 sem corpo', () async {
      final AdapterFalso a = AdapterFalso('', status: 204);

      await clienteFalso(a).remover(550, 'movie');

      expect(a.ultima.method, 'DELETE');
      expect(a.ultima.path, '/api/v1/acervo/550');
      expect(a.ultima.queryParameters, <String, dynamic>{'tipo': 'movie'});
    });

    test('feedback é GET em /api/v1/feedback e recebe array no topo', () async {
      final AdapterFalso a = AdapterFalso(
        '[{"tmdbId":1399,"sinal":"dislike","peso":1,"origem":"abandono","tipo":"tv"}]',
      );

      final sinais = await clienteFalso(a).feedback();

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/feedback');
      expect(a.ultima.queryParameters, isEmpty);
      expect(sinais.single.sinal, SinalGosto.dislike);
      expect(sinais.single.peso, 1);
    });

    test('marcar feedback é PUT com sinal, tipo, peso e origem no corpo', () async {
      final AdapterFalso a = AdapterFalso(
        '{"tmdbId":1399,"sinal":"dislike","peso":1,"origem":"abandono","tipo":"tv"}',
      );

      await clienteFalso(a).marcarFeedback(
        1399,
        const MarcarFeedbackRequest(
          sinal: SinalGosto.dislike,
          tipo: TipoMidia.tv,
          peso: 1,
          origem: OrigemFeedback.abandono,
        ),
      );

      expect(a.ultima.method, 'PUT');
      expect(a.ultima.path, '/api/v1/feedback/1399');
      expect(a.ultima.data, <String, dynamic>{
        'sinal': 'dislike',
        'tipo': 'tv',
        'peso': 1,
        'origem': 'abandono',
      });
      expect(a.ultima.contentType, startsWith('application/json'));
    });

    test('remover feedback é DELETE com o tipo na query', () async {
      final AdapterFalso a = AdapterFalso('', status: 204);

      await clienteFalso(a).removerFeedback(550, 'movie');

      expect(a.ultima.method, 'DELETE');
      expect(a.ultima.path, '/api/v1/feedback/550');
      expect(a.ultima.queryParameters, <String, dynamic>{'tipo': 'movie'});
    });

    test('ler preferências é GET em /api/v1/preferencias', () async {
      final AdapterFalso a = AdapterFalso('{"momento":"domingo","generos":["Drama"]}');

      final p = await clienteFalso(a).preferencias();

      expect(a.ultima.method, 'GET');
      expect(a.ultima.path, '/api/v1/preferencias');
      expect(p.momento, 'domingo');
    });

    test('salvar preferências é PUT com momento e gêneros no corpo', () async {
      final AdapterFalso a = AdapterFalso('{"momento":"domingo","generos":["Drama"]}');

      await clienteFalso(a).salvarPreferencias(
        const Preferencias(momento: 'domingo', generos: <String>['Drama']),
      );

      expect(a.ultima.method, 'PUT');
      expect(a.ultima.path, '/api/v1/preferencias');
      expect(a.ultima.data, <String, dynamic>{'momento': 'domingo', 'generos': <String>['Drama']});
      expect(a.ultima.contentType, startsWith('application/json'));
    });
  });
}
