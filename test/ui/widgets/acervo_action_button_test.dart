import 'package:appseries/ui/widgets/acervo_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> montar(
    WidgetTester tester, {
    EstadoAcervo? atual,
    required ValueChanged<EstadoAcervo> onEscolher,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: AcervoActionButton(atual: atual, onEscolher: onEscolher)),
        ),
      ),
    );
  }

  group('AcervoActionButton', () {
    test('rótulo de cada estado, inclusive o de decodificação', () {
      expect(rotuloEstado(EstadoAcervo.planToWatch), 'Quero ver');
      expect(rotuloEstado(EstadoAcervo.watching), 'Assistindo');
      expect(rotuloEstado(EstadoAcervo.watched), 'Assistido');
      expect(rotuloEstado(EstadoAcervo.dropped), 'Abandonei');
      expect(rotuloEstado(EstadoAcervo.desconhecido), 'Sem estado');
    });

    testWidgets('sem estado mostra "Marcar" e os quatro estados no menu', (tester) async {
      await montar(tester, onEscolher: (_) {});

      expect(find.text('Marcar'), findsOneWidget);

      await tester.tap(find.text('Marcar'));
      await tester.pumpAndSettle();

      expect(find.text('Quero ver'), findsOneWidget);
      expect(find.text('Assistindo'), findsOneWidget);
      expect(find.text('Assistido'), findsOneWidget);
      expect(find.text('Abandonei'), findsOneWidget);
      expect(find.text('Sem estado'), findsNothing,
          reason: 'desconhecido é fallback de decodificação, não opção do menu');
      expect(find.byIcon(Icons.check), findsNothing,
          reason: 'sem estado atual, nenhum item pode vir marcado');
    });

    testWidgets('com estado mostra o rótulo atual e marca só ele', (tester) async {
      await montar(tester, atual: EstadoAcervo.watched, onEscolher: (_) {});

      expect(find.text('Assistido'), findsOneWidget);
      expect(find.text('Marcar'), findsNothing);

      await tester.tap(find.text('Assistido'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.widgetWithText(PopupMenuItem<EstadoAcervo>, 'Assistido'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
        reason: 'o check tem de estar no estado atual, não em qualquer item',
      );
      for (final String outro in <String>['Quero ver', 'Assistindo', 'Abandonei']) {
        expect(
          find.descendant(
            of: find.widgetWithText(PopupMenuItem<EstadoAcervo>, outro),
            matching: find.byIcon(Icons.check),
          ),
          findsNothing,
          reason: outro,
        );
      }
    });

    testWidgets('entrega o estado escolhido, não um valor fixo', (tester) async {
      final List<EstadoAcervo> escolhidos = <EstadoAcervo>[];
      await montar(tester, atual: EstadoAcervo.watching, onEscolher: escolhidos.add);

      await tester.tap(find.text('Assistindo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abandonei'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assistindo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quero ver'));
      await tester.pumpAndSettle();

      expect(escolhidos, <EstadoAcervo>[EstadoAcervo.dropped, EstadoAcervo.planToWatch]);
    });
  });
}
