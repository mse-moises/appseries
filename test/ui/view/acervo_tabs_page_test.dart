import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/ui/view/acervo_tabs_page.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAcervo implements AcervoRepository {
  _FakeAcervo(this.respostas);

  /// Uma resposta por leitura, em ordem; a última se repete.
  final List<Future<Result<List<AcervoItem>>>> respostas;
  int leituras = 0;

  @override
  Future<Result<List<AcervoItem>>> listar() {
    final int i = leituras < respostas.length ? leituras : respostas.length - 1;
    leituras++;
    return respostas[i];
  }

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

AcervoItem _linha(int id, String titulo, EstadoAcervo estado, {TipoMidia? tipo = TipoMidia.movie}) =>
    AcervoItem(tmdbId: id, estado: estado, tipo: tipo, titulo: titulo, ano: '2010');

Future<(AcervoViewModel, _FakeAcervo)> _abrir(
  WidgetTester tester,
  List<Future<Result<List<AcervoItem>>>> respostas,
) async {
  final _FakeAcervo repo = _FakeAcervo(respostas);
  final AcervoViewModel vm = AcervoViewModel(repo);
  unawaited(vm.load());
  await tester.pumpWidget(
    ChangeNotifierProvider<AcervoViewModel>.value(
      value: vm,
      child: MaterialApp(
        home: const AcervoTabsPage(),
        routes: <String, WidgetBuilder>{
          Routes.historico: (BuildContext _) => const Text('tela do histórico'),
          Routes.detalhe: (BuildContext c) {
            final TituloRef ref = ModalRoute.of(c)!.settings.arguments! as TituloRef;
            return Text('detalhe ${ref.tipo.name}:${ref.id}');
          },
        },
      ),
    ),
  );
  await tester.pump();
  return (vm, repo);
}

Future<Result<List<AcervoItem>>> _ok(List<AcervoItem> itens) =>
    Future<Result<List<AcervoItem>>>.value(Result<List<AcervoItem>>.ok(itens));

void main() {
  group('AcervoTabsPage (AP-59)', () {
    final List<AcervoItem> tres = <AcervoItem>[
      _linha(1, 'A Origem', EstadoAcervo.planToWatch),
      _linha(2, 'Dexter', EstadoAcervo.watching, tipo: TipoMidia.tv),
      _linha(3, 'Clube da Luta', EstadoAcervo.watched),
      _linha(4, 'Lost', EstadoAcervo.dropped, tipo: TipoMidia.tv),
    ];

    testWidgets('o ícone de histórico abre o histórico (AP-73)', (tester) async {
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[_ok(tres)]);

      await tester.tap(find.byTooltip('Histórico'));
      await tester.pumpAndSettle();

      expect(find.text('tela do histórico'), findsOneWidget);
    });

    testWidgets('três abas com a contagem, cada título na aba certa', (tester) async {
      final (_, _FakeAcervo repo) = await _abrir(tester, <Future<Result<List<AcervoItem>>>>[_ok(tres)]);
      expect(repo.leituras, 1, reason: 'a tela usa o acervo que a home já leu; abrir não pede de novo');

      expect(find.text('Quero ver (1)'), findsOneWidget);
      expect(find.text('Assistindo (1)'), findsOneWidget);
      expect(find.text('Assistido (2)'), findsOneWidget);

      // A primeira aba abre sozinha.
      expect(find.text('A Origem'), findsOneWidget);
      expect(find.text('Dexter'), findsNothing);

      await tester.tap(find.text('Assistindo (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Dexter'), findsOneWidget);
      expect(find.text('A Origem'), findsNothing);

      await tester.tap(find.text('Assistido (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Clube da Luta'), findsOneWidget);
      expect(find.text('Lost'), findsOneWidget);
    });

    testWidgets('na aba Assistido, só o abandonado leva a marca "Abandonei"', (tester) async {
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[_ok(tres)]);
      await tester.tap(find.text('Assistido (2)'));
      await tester.pumpAndSettle();

      final Finder marca = find.text('Abandonei');
      expect(marca, findsOneWidget);
      // A marca está na linha do Lost, não na do Clube da Luta.
      expect(
        find.descendant(of: find.byKey(const ValueKey<String>('acervo-tv-4')), matching: marca),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('acervo-movie-3')),
          matching: find.text('Abandonei'),
        ),
        findsNothing,
      );
    });

    testWidgets('aba vazia diz "Nada aqui ainda.", nunca lista em branco', (tester) async {
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[
        _ok(<AcervoItem>[_linha(3, 'Clube da Luta', EstadoAcervo.watched)]),
      ]);

      expect(find.text('Quero ver (0)'), findsOneWidget);
      expect(find.text('Nada aqui ainda.'), findsOneWidget);
      expect(find.textContaining('TMDB API'), findsNothing, reason: 'sem pôster, sem atribuição');

      await tester.tap(find.text('Assistido (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Nada aqui ainda.'), findsNothing);
      expect(find.textContaining('TMDB API'), findsOneWidget);
    });

    testWidgets('enquanto carrega: progresso e abas sem número', (tester) async {
      final Completer<Result<List<AcervoItem>>> pendente = Completer<Result<List<AcervoItem>>>();
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[pendente.future]);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Quero ver'), findsOneWidget, reason: '"(0)" enquanto carrega seria mentira');
      expect(find.text('Nada aqui ainda.'), findsNothing);

      pendente.complete(Result<List<AcervoItem>>.ok(tres));
      await tester.pumpAndSettle();
      expect(find.text('Quero ver (1)'), findsOneWidget);
    });

    testWidgets('erro mostra a frase e o "tentar de novo" lê de novo', (tester) async {
      final (_, _FakeAcervo repo) = await _abrir(tester, <Future<Result<List<AcervoItem>>>>[
        Future<Result<List<AcervoItem>>>.value(const Result<List<AcervoItem>>.error(NetworkError())),
        _ok(tres),
      ]);
      await tester.pumpAndSettle();

      expect(find.text(const NetworkError().mensagem), findsOneWidget);
      expect(find.text('Quero ver'), findsOneWidget);
      expect(find.text('Nada aqui ainda.'), findsNothing, reason: 'erro não é acervo vazio');

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(repo.leituras, 2);
      expect(find.text('A Origem'), findsOneWidget);
    });

    testWidgets('tocar no título abre o detalhe com o par (tipo, id)', (tester) async {
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[_ok(tres)]);
      await tester.tap(find.text('Assistindo (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dexter'));
      await tester.pumpAndSettle();

      expect(find.text('detalhe tv:2'), findsOneWidget);
    });

    testWidgets('linha antiga sem tipo aparece, mas não abre o detalhe', (tester) async {
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[
        _ok(<AcervoItem>[_linha(7, 'Sem Tipo', EstadoAcervo.planToWatch, tipo: null)]),
      ]);

      await tester.tap(find.text('Sem Tipo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('detalhe'), findsNothing,
          reason: 'o id sozinho pode ser o filme ou a série');
      expect(find.text('Sem Tipo'), findsOneWidget);
    });

    testWidgets('título que o TMDB não deu vira "Sem título"', (tester) async {
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[
        _ok(const <AcervoItem>[AcervoItem(tmdbId: 8, estado: EstadoAcervo.planToWatch, tipo: TipoMidia.movie)]),
      ]);

      expect(find.text('Sem título'), findsOneWidget);
    });

    testWidgets('tela estreita com fonte grande não estoura', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final List<AcervoItem> longos = <AcervoItem>[
        _linha(1, 'Um título bem comprido que não cabe numa linha só', EstadoAcervo.dropped),
      ];
      final AcervoViewModel vm = AcervoViewModel(_FakeAcervo(<Future<Result<List<AcervoItem>>>>[_ok(longos)]));
      await vm.load();
      await tester.pumpWidget(
        ChangeNotifierProvider<AcervoViewModel>.value(
          value: vm,
          child: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: MaterialApp(home: AcervoTabsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Com fonte 2x as três abas não cabem em 320 px: a barra rola até a terceira.
      await tester.ensureVisible(find.text('Assistido (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistido (1)'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Abandonei'), findsOneWidget);
    });
  });
}
