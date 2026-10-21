import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/ui/view/acervo_page.dart';
import 'package:appseries/ui/view/busca_page.dart';
import 'package:appseries/ui/view/detalhe_page.dart';
import 'package:appseries/ui/view/preferencias_page.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proof that the foundation opened the map: each route resolves to its stub and
/// the detail stub receives the typed pair the other screens will send.
void main() {
  group('Routes.mapa', () {
    test('as quatro rotas internas estão registradas', () {
      final Map<String, WidgetBuilder> mapa = Routes.mapa;

      expect(mapa.keys, containsAll(<String>[
        Routes.busca,
        Routes.detalhe,
        Routes.acervo,
        Routes.preferencias,
      ]));
      expect(mapa.length, 4);
    });

    testWidgets('cada rota abre a sua tela', (tester) async {
      final Map<String, Type> esperado = <String, Type>{
        Routes.busca: BuscaPage,
        Routes.detalhe: DetalhePage,
        Routes.acervo: AcervoPage,
        Routes.preferencias: PreferenciasPage,
      };

      for (final MapEntry<String, Type> e in esperado.entries) {
        await tester.pumpWidget(MaterialApp(
          key: ValueKey<String>(e.key),
          routes: Routes.mapa,
          initialRoute: e.key,
        ));
        await tester.pump();
        expect(find.byType(e.value), findsOneWidget, reason: 'rota ${e.key}');
      }
    });

    testWidgets('o detalhe mostra o título que recebeu na rota', (tester) async {
      await tester.pumpWidget(MaterialApp(
        routes: Routes.mapa,
        onGenerateInitialRoutes: (String _) => <Route<dynamic>>[
          MaterialPageRoute<void>(
            settings: const RouteSettings(
              name: Routes.detalhe,
              arguments: TituloRef(tipo: TipoMidia.tv, id: 1399),
            ),
            builder: Routes.mapa[Routes.detalhe]!,
          ),
        ],
      ));
      await tester.pump();

      expect(find.textContaining('tv 1399'), findsOneWidget);
    });
  });
}
