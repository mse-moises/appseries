import 'package:appseries/data/api_models/carta_rec.dart';
import 'package:appseries/data/repositories/rec_repository.dart';
import 'package:appseries/ui/view/rec_page.dart';
import 'package:appseries/ui/view_model/rec_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeRec implements RecRepository {
  _FakeRec(this.respostas);

  final List<Future<Result<RecResult>>> respostas;
  int chamadas = 0;

  @override
  Future<Result<RecResult>> recomendar({String? momento}) {
    final int i = chamadas < respostas.length ? chamadas : respostas.length - 1;
    chamadas++;
    return respostas[i];
  }
}

Future<Result<RecResult>> _ok(List<CartaRec> cartas, {OrigemRec origem = OrigemRec.llm}) =>
    Future<Result<RecResult>>.value(Result<RecResult>.ok(RecResult(cartas: cartas, origem: origem)));

/// Cartas sem pôster de propósito: o teste não toca a rede.
const List<CartaRec> _tres = <CartaRec>[
  CartaRec(
    tmdbId: 1399,
    tipo: TipoMidia.tv,
    titulo: 'Game of Thrones',
    ano: '2011',
    justificativa: 'Combina com o seu momento',
  ),
  CartaRec(
    tmdbId: 550,
    tipo: TipoMidia.movie,
    titulo: 'Clube da Luta',
    ano: '1999',
    justificativa: 'Você curtiu suspense',
  ),
  CartaRec(
    tmdbId: 1396,
    tipo: TipoMidia.tv,
    titulo: 'Breaking Bad',
    ano: '2008',
    justificativa: 'Parecido com o que você assistiu',
  ),
];

Future<_FakeRec> _abrir(WidgetTester tester, List<Future<Result<RecResult>>> respostas) async {
  final _FakeRec repo = _FakeRec(respostas);
  final RecViewModel vm = RecViewModel(repo);
  await tester.pumpWidget(
    ChangeNotifierProvider<RecViewModel>.value(
      value: vm,
      child: const MaterialApp(home: RecPage()),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  testWidgets('abre ociosa: explica e não gasta uma das 20 do dia', (tester) async {
    final _FakeRec repo = await _abrir(tester, <Future<Result<RecResult>>>[_ok(_tres)]);

    expect(find.text('O que assistir agora'), findsOneWidget);
    expect(find.byKey(const Key('rec-momento')), findsOneWidget);
    expect(find.textContaining('toque em Recomendar'), findsOneWidget);
    expect(repo.chamadas, 0, reason: 'abrir a tela não pode chamar o servidor');
  });

  testWidgets('mostra as três cartas e marca só a primeira', (tester) async {
    final _FakeRec repo = await _abrir(tester, <Future<Result<RecResult>>>[_ok(_tres)]);

    await tester.tap(find.byKey(const Key('rec-gerar')));
    await tester.pumpAndSettle();

    expect(repo.chamadas, 1);
    expect(find.text('Game of Thrones'), findsOneWidget);
    expect(find.text('Clube da Luta'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('A recomendação pra você'), findsOneWidget,
        reason: 'só a primeira carta é a recomendação');
    expect(find.text('Combina com o seu momento'), findsOneWidget);
    expect(find.byKey(const Key('rec-outra')), findsOneWidget);
    expect(find.textContaining('Só achei'), findsNothing);
  });

  testWidgets('com menos de três, a tela explica em vez de ficar vazia', (tester) async {
    await _abrir(tester, <Future<Result<RecResult>>>[_ok(<CartaRec>[_tres.first])]);

    await tester.tap(find.byKey(const Key('rec-gerar')));
    await tester.pumpAndSettle();

    expect(find.text('Game of Thrones'), findsOneWidget);
    expect(find.textContaining('Só achei uma opção'), findsOneWidget);
  });

  testWidgets('sem nenhuma carta, explica o que fazer', (tester) async {
    await _abrir(tester, <Future<Result<RecResult>>>[_ok(const <CartaRec>[])]);

    await tester.tap(find.byKey(const Key('rec-gerar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não achei nada que combine'), findsOneWidget);
    expect(find.byKey(const Key('rec-outra')), findsNothing);
  });

  testWidgets('falha mostra a frase e oferece tentar de novo', (tester) async {
    await _abrir(tester, <Future<Result<RecResult>>>[
      Future<Result<RecResult>>.value(const Result<RecResult>.error(RateLimitError())),
    ]);

    await tester.tap(find.byKey(const Key('rec-gerar')));
    await tester.pumpAndSettle();

    expect(find.text(const RateLimitError().mensagem), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing,
        reason: 'o teto do dia responde igual até amanhã: o botão convidaria a repetir');
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha de rede oferece tentar de novo', (tester) async {
    await _abrir(tester, <Future<Result<RecResult>>>[
      Future<Result<RecResult>>.value(const Result<RecResult>.error(NetworkError())),
    ]);

    await tester.tap(find.byKey(const Key('rec-gerar')));
    await tester.pumpAndSettle();

    expect(find.text(const NetworkError().mensagem), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget, reason: 'a rede pode voltar');
  });

  testWidgets('outra rodada pede de novo ao servidor', (tester) async {
    final _FakeRec repo = await _abrir(tester, <Future<Result<RecResult>>>[_ok(_tres), _ok(_tres)]);

    await tester.tap(find.byKey(const Key('rec-gerar')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('rec-outra')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rec-outra')));
    await tester.pumpAndSettle();

    expect(repo.chamadas, 2);
    expect(find.text('A recomendação pra você'), findsOneWidget);
  });

  testWidgets('o momento digitado chega ao view model', (tester) async {
    final _FakeRec repo = await _abrir(tester, <Future<Result<RecResult>>>[_ok(_tres)]);

    await tester.enterText(find.byKey(const Key('rec-momento')), 'algo leve pra ver com a esposa');
    await tester.tap(find.byKey(const Key('rec-gerar')));
    await tester.pumpAndSettle();

    expect(repo.chamadas, 1);
    expect(find.text('Game of Thrones'), findsOneWidget);
  });
}
