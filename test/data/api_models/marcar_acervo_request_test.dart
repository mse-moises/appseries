import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/marcar_acervo_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarcarAcervoRequest', () {
    test('serializa os valores que o backend conhece', () {
      final Map<String, dynamic> json = const MarcarAcervoRequest(
        estado: EstadoAcervo.watching,
        tipo: TipoMidia.tv,
      ).toJson();

      expect(json, <String, dynamic>{'estado': 'watching', 'tipo': 'tv'});
    });

    test('os quatro estados reais têm nome de wire', () {
      const Map<EstadoAcervo, String> esperado = <EstadoAcervo, String>{
        EstadoAcervo.planToWatch: 'plan_to_watch',
        EstadoAcervo.watching: 'watching',
        EstadoAcervo.watched: 'watched',
        EstadoAcervo.dropped: 'dropped',
      };

      esperado.forEach((EstadoAcervo estado, String wire) {
        final Map<String, dynamic> json =
            MarcarAcervoRequest(estado: estado, tipo: TipoMidia.movie).toJson();
        expect(json['estado'], wire, reason: estado.name);
      });
    });

    test('quero ver vai como plan_to_watch', () {
      final Map<String, dynamic> json = const MarcarAcervoRequest(
        estado: EstadoAcervo.planToWatch,
        tipo: TipoMidia.movie,
      ).toJson();

      expect(json['estado'], 'plan_to_watch');
      expect(json['tipo'], 'movie');
    });
  });
}
