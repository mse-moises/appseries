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

    test('momento só com espaço conta como vazio; momento preenchido não', () {
      expect(
        Preferencias.fromJson(<String, dynamic>{'momento': '   ', 'generos': <String>[]}).vazio,
        isTrue,
      );
      expect(
        Preferencias.fromJson(<String, dynamic>{'momento': 'x', 'generos': <String>[]}).vazio,
        isFalse,
      );
    });

    test('toJson manda as duas chaves sempre, porque o PUT substitui o registro', () {
      final Map<String, dynamic> soMomento = const Preferencias(momento: 'domingo').toJson();
      expect(soMomento.containsKey('generos'), isTrue);
      expect(soMomento['generos'], isEmpty,
          reason: 'chave presente com lista vazia apaga os gêneros no servidor');

      final Map<String, dynamic> soGeneros =
          const Preferencias(generos: <String>['Drama']).toJson();
      expect(soGeneros.containsKey('momento'), isTrue);
      expect(soGeneros['momento'], isNull, reason: 'momento null limpa o campo no servidor');
    });

    test('toJson manda as chaves que o PUT espera', () {
      final Map<String, dynamic> json =
          const Preferencias(momento: 'domingo', generos: <String>['Drama']).toJson();

      expect(json, <String, dynamic>{'momento': 'domingo', 'generos': <String>['Drama']});
    });
  });
}
