import 'package:appseries/data/api_models/titulos_response.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato de `/em-alta` e `/populares` (ver `specs/contrato-api.md`).
void main() {
  group('TmdbItem.fromJson', () {
    test('lê o payload do contrato, com o array dentro de resultados', () {
      final TitulosResponse resposta = TitulosResponse.fromJson(<String, dynamic>{
        'resultados': <dynamic>[
          <String, dynamic>{
            'id': 123,
            'tipo': 'movie',
            'titulo': 'Um Filme',
            'ano': '2025',
            'posterPath': '/x.jpg',
          },
        ],
      });

      expect(resposta.resultados, hasLength(1));
      final TmdbItem item = resposta.resultados.first;
      expect(item.id, 123);
      expect(item.tipo, TipoMidia.movie);
      expect(item.titulo, 'Um Filme');
      expect(item.ano, '2025', reason: 'o backend manda ano como string');
      expect(item.posterPath, '/x.jpg');
    });

    test('lista vazia é lista vazia, não erro', () {
      final TitulosResponse resposta = TitulosResponse.fromJson(
        <String, dynamic>{'resultados': <dynamic>[]},
      );

      expect(resposta.resultados, isEmpty);
    });

    test('posterPath nulo passa (o card cai no ícone)', () {
      final TmdbItem item = TmdbItem.fromJson(<String, dynamic>{
        'id': 1,
        'tipo': 'tv',
        'titulo': 'Sem Pôster',
        'ano': '',
        'posterPath': null,
      });

      expect(item.posterPath, isNull);
      expect(item.ano, isEmpty);
    });

    test('id que chega como número decimal continua inteiro', () {
      final TmdbItem item = TmdbItem.fromJson(<String, dynamic>{
        'id': 123.0,
        'tipo': 'movie',
        'titulo': 'X',
      });

      expect(item.id, 123);
    });

    test('tipo fora do contrato vira desconhecido em vez de quebrar', () {
      final TmdbItem item = TmdbItem.fromJson(<String, dynamic>{
        'id': 1,
        'tipo': 'anime',
        'titulo': 'X',
      });

      expect(item.tipo, TipoMidia.desconhecido);
    });
  });
}
