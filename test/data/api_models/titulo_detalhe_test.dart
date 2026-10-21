import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TituloDetalhe.fromJson', () {
    test('lê a ficha completa do contrato', () {
      final TituloDetalhe t = TituloDetalhe.fromJson(<String, dynamic>{
        'id': 1399,
        'tipo': 'tv',
        'titulo': 'Game of Thrones',
        'ano': '2011',
        'posterPath': '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
        'sinopse': 'Nove famílias nobres lutam pelo controle de Westeros.',
        'nota': 8.4,
        'generos': <String>['Drama', 'Fantasia'],
      });

      expect(t.id, 1399);
      expect(t.tipo, TipoMidia.tv);
      expect(t.titulo, 'Game of Thrones');
      expect(t.ano, '2011');
      expect(t.sinopse, startsWith('Nove famílias'));
      expect(t.posterPath, '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
          reason: 'é o campo que a tela de detalhe desenha');
      expect(t.nota, 8.4);
      expect(t.generos, <String>['Drama', 'Fantasia']);
    });

    test('nota inteira também decodifica (o backend manda 8 e 8.4)', () {
      final TituloDetalhe t = TituloDetalhe.fromJson(<String, dynamic>{
        'id': 1,
        'tipo': 'movie',
        'titulo': 'X',
        'nota': 8,
      });

      expect(t.nota, 8.0);
    });

    test('sem nota, sem gêneros e sem pôster não quebra a tela', () {
      final TituloDetalhe t = TituloDetalhe.fromJson(<String, dynamic>{
        'id': 2,
        'tipo': 'movie',
        'titulo': 'Sem ficha',
      });

      expect(t.nota, isNull);
      expect(t.notaExibivel, isNull);
      expect(t.generos, isEmpty);
      expect(t.posterPath, isNull);
      expect(t.sinopse, isNull);
    });

    test('nota 0 (sem avaliação no TMDB) não é nota exibível', () {
      final TituloDetalhe t = TituloDetalhe.fromJson(<String, dynamic>{
        'id': 9,
        'tipo': 'movie',
        'titulo': 'Sem votos',
        'nota': 0,
      });

      expect(t.nota, 0.0);
      expect(t.notaExibivel, isNull, reason: 'a tela não pode mostrar 0.0 como nota');
    });

    test('tipo fora do contrato vira desconhecido', () {
      final TituloDetalhe t = TituloDetalhe.fromJson(<String, dynamic>{
        'id': 3,
        'tipo': 'anime',
        'titulo': 'Y',
      });

      expect(t.tipo, TipoMidia.desconhecido);
    });
  });
}
