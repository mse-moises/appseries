import 'package:appseries/utils/data_curta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dataCurta', () {
    test('dataCurta usa dia/mês/ano com zero à esquerda', () {
      expect(dataCurta(DateTime(2026, 3, 5, 23, 59)), '05/03/2026');
    });

    test('a conversão padrão leva para o fuso do aparelho, no mesmo instante', () {
      final DateTime doServidor = DateTime.utc(2026, 10, 21, 1);

      final DateTime local = paraLocalDoAparelho(doServidor);

      // Vale em qualquer fuso: a data sai como hora local (não UTC) e aponta
      // para o mesmo instante. Sem a conversão, `isUtc` continuaria true.
      expect(local.isUtc, isFalse);
      expect(local.isAtSameMomentAs(doServidor), isTrue);
    });

    test('dataCurta converte para o fuso antes de formatar', () {
      // 01h UTC do dia 21 é 22h do dia 20 em Brasília (UTC-3).
      DateTime brasilia(DateTime d) => d.toUtc().subtract(const Duration(hours: 3));

      expect(dataCurta(DateTime.utc(2026, 10, 21, 1), paraLocal: brasilia), '20/10/2026');
      expect(dataCurta(DateTime.utc(2026, 10, 21, 4), paraLocal: brasilia), '21/10/2026');
    });
  });
}
