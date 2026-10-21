import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato do `GET /api/v1/acervo` (ver `specs/contrato-api.md` no backend).
void main() {
  group('AcervoItem.fromJson', () {
    test('lê o payload do contrato campo a campo', () {
      final item = AcervoItem.fromJson(<String, dynamic>{
        'tmdbId': 1399,
        'estado': 'watching',
        'tipo': 'tv',
        'titulo': 'Game of Thrones',
        'ano': '2011',
        'posterPath': '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
        'atualizadoEm': '2026-10-20T12:00:00.000Z',
      });

      expect(item.tmdbId, 1399);
      expect(item.estado, EstadoAcervo.watching);
      expect(item.tipo, TipoMidia.tv);
      expect(item.titulo, 'Game of Thrones');
      expect(item.ano, '2011');
      expect(item.posterPath, '/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg');
      expect(item.atualizadoEm?.toUtc(), DateTime.utc(2026, 10, 20, 12));
    });

    test('lê os quatro valores de estado do contrato', () {
      const Map<String, EstadoAcervo> esperado = <String, EstadoAcervo>{
        'plan_to_watch': EstadoAcervo.planToWatch,
        'watching': EstadoAcervo.watching,
        'watched': EstadoAcervo.watched,
        'dropped': EstadoAcervo.dropped,
      };

      esperado.forEach((String wire, EstadoAcervo estado) {
        final item = AcervoItem.fromJson(<String, dynamic>{'tmdbId': 1, 'estado': wire});
        expect(item.estado, estado, reason: 'wire value "$wire"');
      });
    });

    test('tipo fora do contrato vira TipoMidia.desconhecido', () {
      final item = AcervoItem.fromJson(<String, dynamic>{
        'tmdbId': 1,
        'estado': 'watched',
        'tipo': 'anime',
      });

      expect(item.tipo, TipoMidia.desconhecido);
    });

    test('toJson devolve os nomes de wire do contrato', () {
      const AcervoItem item = AcervoItem(
        tmdbId: 1399,
        estado: EstadoAcervo.planToWatch,
        tipo: TipoMidia.tv,
        ano: '2011',
      );

      final Map<String, dynamic> json = item.toJson();

      expect(json['estado'], 'plan_to_watch');
      expect(json['tipo'], 'tv');
      expect(json['ano'], '2011');
    });

    test('estado que o app não conhece não derruba a lista', () {
      final item = AcervoItem.fromJson(<String, dynamic>{
        'tmdbId': 1,
        'estado': 'on_hold',
      });

      expect(item.estado, EstadoAcervo.desconhecido);
      expect(item.tipo, isNull);
    });

    test('linha anterior à 008 vem sem tipo e sem mídia', () {
      final item = AcervoItem.fromJson(<String, dynamic>{
        'tmdbId': 550,
        'estado': 'dropped',
        'tipo': null,
        'titulo': null,
        'ano': null,
        'posterPath': null,
        'atualizadoEm': null,
      });

      expect(item.tipo, isNull);
      expect(item.titulo, isNull);
      expect(item.ano, isNull);
      expect(item.posterPath, isNull);
      expect(item.atualizadoEm, isNull);
    });
  });

  group('chaveEstado', () {
    test('separa filme e série do mesmo id, e é estável', () {
      final String filme = chaveEstado(TipoMidia.movie, 550);
      final String serie = chaveEstado(TipoMidia.tv, 550);

      expect(filme, isNot(serie), reason: 'filme 550 e série 550 são títulos diferentes');
      expect(chaveEstado(TipoMidia.movie, 550), filme, reason: 'a mesma consulta devolve a mesma chave');
      expect(chaveEstado(TipoMidia.movie, 551), isNot(filme));
    });
  });
}
