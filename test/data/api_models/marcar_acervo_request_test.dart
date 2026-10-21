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
