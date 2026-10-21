import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/ui/widgets/poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O card é onde o pôster nulo, o título vazio e o ano vazio são tratados; sem
/// este teste, trocar o `if` por um `Text` cru não quebrava nada.
void main() {
  Future<void> montar(WidgetTester tester, TmdbItem item) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 240, child: PosterCard(item: item)),
        ),
      ),
    );
    await tester.pump();
  }

  group('PosterCard', () {
    testWidgets('sem pôster mostra o ícone, nunca quebra', (tester) async {
      await montar(
        tester,
        const TmdbItem(id: 1, tipo: TipoMidia.movie, titulo: 'Sem Pôster', ano: '2020'),
      );

      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Sem Pôster'), findsOneWidget);
      expect(find.text('2020'), findsOneWidget);
    });

    testWidgets('título vazio vira "Sem título"', (tester) async {
      await montar(tester, const TmdbItem(id: 2, tipo: TipoMidia.tv, titulo: ''));

      expect(find.text('Sem título'), findsOneWidget);
    });

    testWidgets('ano vazio não desenha linha em branco', (tester) async {
      await montar(
        tester,
        const TmdbItem(id: 3, tipo: TipoMidia.movie, titulo: 'Sem data', ano: ''),
      );

      expect(find.text(''), findsNothing);
      expect(find.text('Sem data'), findsOneWidget);
    });
  });
}
