import 'package:appseries/ui/widgets/seletor_estado.dart';
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
          body: Center(child: SeletorEstado(atual: atual, onEscolher: onEscolher)),
        ),
      ),
    );
  }

  group('SeletorEstado', () {
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
    });

    testWidgets('com estado mostra o rótulo atual', (tester) async {
      await montar(tester, atual: EstadoAcervo.watched, onEscolher: (_) {});

      expect(find.text('Assistido'), findsOneWidget);
      expect(find.text('Marcar'), findsNothing);
    });

    testWidgets('escolher entrega o estado tipado, não um texto', (tester) async {
      final List<EstadoAcervo> escolhidos = <EstadoAcervo>[];
      await montar(tester, atual: EstadoAcervo.watching, onEscolher: escolhidos.add);

      await tester.tap(find.text('Assistindo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abandonei'));
      await tester.pumpAndSettle();

      expect(escolhidos, <EstadoAcervo>[EstadoAcervo.dropped]);
    });
  });
}
