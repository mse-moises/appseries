import 'package:appseries/data/api_models/carta_rec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecResult', () {
    test('lê o corpo que o contrato do backend publica', () {
      final RecResult r = RecResult.fromJson(<String, dynamic>{
        'cartas': <dynamic>[
          <String, dynamic>{
            'tmdbId': 1399,
            'tipo': 'tv',
            'titulo': 'Game of Thrones',
            'ano': '2011',
            'posterPath': '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
            'justificativa': 'Combina com o seu momento',
          },
        ],
        'origem': 'llm',
      });

      expect(r.origem, OrigemRec.llm);
      expect(r.cartas, hasLength(1));
      expect(r.cartas.single.tmdbId, 1399);
      expect(r.cartas.single.tipo, TipoMidia.tv);
      expect(r.cartas.single.titulo, 'Game of Thrones');
      expect(r.cartas.single.ano, '2011', reason: 'o ano vem como String, igual ao acervo');
      expect(r.cartas.single.justificativa, 'Combina com o seu momento');
    });

    test('origem em_alta é o fallback do servidor, não um erro', () {
      final RecResult r = RecResult.fromJson(<String, dynamic>{
        'cartas': <dynamic>[],
        'origem': 'em_alta',
      });

      expect(r.origem, OrigemRec.emAlta);
      expect(r.cartas, isEmpty, reason: 'lista vazia é resposta válida do contrato');
    });

    test('tipo e origem que esta versão não conhece não estouram', () {
      final RecResult r = RecResult.fromJson(<String, dynamic>{
        'cartas': <dynamic>[
          <String, dynamic>{
            'tmdbId': 1,
            'tipo': 'podcast',
            'titulo': 'Inventado',
            'justificativa': 'porque sim',
          },
        ],
        'origem': 'outra_coisa',
      });

      expect(r.cartas.single.tipo, TipoMidia.desconhecido);
      expect(r.origem, OrigemRec.desconhecida);
      expect(r.cartas.single.ano, isNull, reason: 'ano ausente não vira erro');
      expect(r.cartas.single.posterPath, isNull);
    });

  });
}
