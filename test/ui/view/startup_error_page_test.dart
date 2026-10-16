import 'package:appseries/ui/view/startup_error_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mensagemDeFalhaAoIniciar', () {
    test('plataforma não registrada fala das plataformas do app', () {
      expect(
        startupFailureMessage(UnsupportedError('sem opções para desktop')),
        'O AppSeries roda no Android e no navegador.',
      );
    });

    test('qualquer outra falha de início fala de conexão', () {
      expect(
        startupFailureMessage(Exception('boom')),
        'Não deu para conectar. Confira sua internet e abra o app de novo.',
      );
    });
  });

  testWidgets('a tela de falha na partida mostra a frase, sem termo técnico', (tester) async {
    // Pumpeado como o `main()` faz: o widget traz o proprio MaterialApp. Envolver
    // a pagina num MaterialApp aqui esconderia a falta do Directionality.
    await tester.pumpWidget(
      const StartupErrorApp(
        mensagem: 'Não deu para conectar. Confira sua internet e abra o app de novo.',
      ),
    );

    expect(find.text('Não deu para abrir o AppSeries'), findsOneWidget);
    expect(find.textContaining('Confira sua internet'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
