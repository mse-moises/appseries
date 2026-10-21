import 'package:appseries/data/api_models/preferencias.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Preferencias', () {
    test('lê momento e gêneros do contrato', () {
      final Preferencias p = Preferencias.fromJson(<String, dynamic>{
        'momento': 'maratonar no fim de semana',
        'generos': <String>['Drama', 'Ficção científica'],
      });

      expect(p.momento, 'maratonar no fim de semana');
      expect(p.generos, <String>['Drama', 'Ficção científica']);
      expect(p.vazio, isFalse);
    });

    test('momento nulo e gêneros vazios contam como vazio', () {
      final Preferencias p = Preferencias.fromJson(<String, dynamic>{
        'momento': null,
        'generos': <String>[],
      });

      expect(p.momento, isNull);
      expect(p.vazio, isTrue);
    });

    test('toJson manda as chaves que o PUT espera', () {
      final Map<String, dynamic> json =
          const Preferencias(momento: 'domingo', generos: <String>['Drama']).toJson();

      expect(json, <String, dynamic>{'momento': 'domingo', 'generos': <String>['Drama']});
    });
  });
}
