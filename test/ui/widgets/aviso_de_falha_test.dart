import 'package:appseries/ui/widgets/aviso_de_falha.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('falhaDeConexao', () {
    test('rede e tempo esgotado são falhas que repetir pode resolver', () {
      expect(falhaDeConexao(const NetworkError()), isTrue);
      expect(falhaDeConexao(const TempoEsgotadoError()), isTrue);
    });

    test('erro do servidor ou recusa não são', () {
      expect(falhaDeConexao(const ServerError()), isFalse);
      expect(falhaDeConexao(const UnauthorizedError()), isFalse);
      expect(falhaDeConexao(const FeedbackIndisponivelError()), isFalse);
    });
  });

  group('avisarFalha', () {
    late ScaffoldMessengerState aviso;

    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                aviso = ScaffoldMessenger.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    }

    testWidgets('mesma falha duas vezes seguidas mostra um aviso só', (tester) async {
      await montar(tester);

      avisarFalha(aviso, prefixo: 'Não salvou.', erro: const NetworkError(), tentarDeNovo: () {});
      await tester.pump();
      avisarFalha(aviso, prefixo: 'Não salvou.', erro: const NetworkError(), tentarDeNovo: () {});
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Não salvou. ${const NetworkError().mensagem}'), findsOneWidget);
    });

    testWidgets('o botão tentar de novo chama a ação', (tester) async {
      await montar(tester);
      int tentativas = 0;

      avisarFalha(
        aviso,
        prefixo: 'Não salvou.',
        erro: const TempoEsgotadoError(),
        tentarDeNovo: () => tentativas++,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(tentativas, 1);
    });

    testWidgets('sem ação de retry, o aviso não oferece o botão', (tester) async {
      await montar(tester);

      avisarFalha(aviso, prefixo: 'Não salvou.', erro: const NetworkError());
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });
  });
}
