import 'dart:async';

import 'package:appseries/ui/widgets/motivo_abandono.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Monta uma tela com um botão que abre a folha e guarda o que ela devolveu.
  Future<Completer<MotivoAbandono?>> montar(WidgetTester tester) async {
    final Completer<MotivoAbandono?> devolvido = Completer<MotivoAbandono?>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async => devolvido.complete(await perguntarMotivoAbandono(context)),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return devolvido;
  }

  group('perguntarMotivoAbandono', () {
    testWidgets('mostra os dois motivos e a saída "Agora não"', (tester) async {
      await montar(tester);

      expect(find.text('Por que você abandonou?'), findsOneWidget);
      expect(find.text('Opcional: ajuda a recomendar melhor.'), findsOneWidget);
      expect(find.text('Sem tempo'), findsOneWidget);
      expect(find.text('Não gostei'), findsOneWidget);
      expect(find.text('Agora não'), findsOneWidget);
    });

    testWidgets('devolve o motivo tocado, não um valor fixo', (tester) async {
      final Completer<MotivoAbandono?> devolvido = await montar(tester);

      await tester.tap(find.byKey(const Key('motivo-naoGostei')));
      await tester.pumpAndSettle();

      expect(await devolvido.future, MotivoAbandono.naoGostei);
    });

    testWidgets('"Agora não" devolve null: o motivo é opcional', (tester) async {
      final Completer<MotivoAbandono?> devolvido = await montar(tester);

      await tester.tap(find.byKey(const Key('motivo-agora-nao')));
      await tester.pumpAndSettle();

      expect(await devolvido.future, isNull);
    });
  });
}
