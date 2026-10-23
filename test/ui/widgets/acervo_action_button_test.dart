import 'dart:async';

import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/ui/widgets/acervo_action_button.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Cada gravação fica pendente até o teste responder; a lista é configurável
/// (inclusive falhar ou ficar pendente).
class _FakeAcervo implements AcervoRepository {
  _FakeAcervo({this.lista = const Result<List<AcervoItem>>.ok(<AcervoItem>[]), this.listaPendente});

  Result<List<AcervoItem>> lista;
  final Completer<Result<List<AcervoItem>>>? listaPendente;
  final List<Completer<Result<AcervoItem>>> marcacoes = <Completer<Result<AcervoItem>>>[];
  final List<String> remocoes = <String>[];
  int leituras = 0;

  @override
  Future<Result<List<AcervoItem>>> listar() {
    leituras++;
    return listaPendente?.future ?? Future<Result<List<AcervoItem>>>.value(lista);
  }

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) {
    final Completer<Result<AcervoItem>> c = Completer<Result<AcervoItem>>();
    marcacoes.add(c);
    return c.future;
  }

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) async {
    remocoes.add('${tipo.name}:$tmdbId');
    return const Result<void>.ok(null);
  }
}

/// O item do menu que tem esse texto (o tipo do valor do menu é privado).
Finder _itemDoMenu(String texto) => find.ancestor(
      of: find.text(texto),
      matching: find.byWidgetPredicate((Widget w) => w is PopupMenuItem),
    );

void main() {
  Future<void> montar(
    WidgetTester tester, {
    EstadoAcervo? atual,
    required ValueChanged<EstadoAcervo> onEscolher,
    VoidCallback? onRemover,
    bool enviando = false,
    bool compacto = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AcervoActionButton(
              atual: atual,
              onEscolher: onEscolher,
              onRemover: onRemover,
              enviando: enviando,
              compacto: compacto,
            ),
          ),
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

    testWidgets('sem estado, um toque marca "Quero ver" (AP-49)', (tester) async {
      final List<EstadoAcervo> escolhidos = <EstadoAcervo>[];
      await montar(tester, onEscolher: escolhidos.add);

      await tester.tap(find.text('Quero ver'));
      await tester.pump();

      expect(escolhidos, <EstadoAcervo>[EstadoAcervo.planToWatch]);
    });

    testWidgets('no pôster (compacto), o mesmo toque marca "Quero ver"', (tester) async {
      final List<EstadoAcervo> escolhidos = <EstadoAcervo>[];
      await montar(tester, onEscolher: escolhidos.add, compacto: true);

      await tester.tap(find.byTooltip('Quero ver'));
      await tester.pump();

      expect(escolhidos, <EstadoAcervo>[EstadoAcervo.planToWatch]);
    });

    testWidgets('sem estado, a seta mostra os quatro estados e nada de remover', (tester) async {
      await montar(tester, onEscolher: (_) {}, onRemover: () {});

      await tester.tap(find.byTooltip('Outros estados'));
      await tester.pumpAndSettle();

      expect(_itemDoMenu('Quero ver'), findsOneWidget);
      expect(find.text('Assistindo'), findsOneWidget);
      expect(find.text('Assistido'), findsOneWidget);
      expect(find.text('Abandonei'), findsOneWidget);
      expect(find.text('Sem estado'), findsNothing,
          reason: 'desconhecido é fallback de decodificação, não opção do menu');
      expect(find.byIcon(Icons.check), findsNothing,
          reason: 'sem estado atual, nenhum item pode vir marcado');
      expect(find.text('Remover do acervo'), findsNothing,
          reason: 'não há o que remover de um título fora do acervo');
    });

    testWidgets('no acervo, o menu oferece remover (o quinto estado)', (tester) async {
      int remocoes = 0;
      await montar(tester, atual: EstadoAcervo.watched, onEscolher: (_) {}, onRemover: () => remocoes++);

      await tester.tap(find.text('Assistido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover do acervo'));
      await tester.pumpAndSettle();

      expect(remocoes, 1);
    });

    testWidgets('enviando mostra progresso e não aceita toque', (tester) async {
      final List<EstadoAcervo> escolhidos = <EstadoAcervo>[];
      await montar(tester, onEscolher: escolhidos.add, enviando: true);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Quero ver'), findsNothing);
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      expect(escolhidos, isEmpty);
    });

    testWidgets('com estado mostra o rótulo atual e marca só ele', (tester) async {
      await montar(tester, atual: EstadoAcervo.watched, onEscolher: (_) {});

      expect(find.text('Assistido'), findsOneWidget);
      expect(find.text('Quero ver'), findsNothing);

      await tester.tap(find.text('Assistido'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _itemDoMenu('Assistido'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
        reason: 'o check tem de estar no estado atual, não em qualquer item',
      );
      for (final String outro in <String>['Quero ver', 'Assistindo', 'Abandonei']) {
        expect(
          find.descendant(
            of: _itemDoMenu(outro),
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

  group('AcervoAcao', () {
    Future<(_FakeAcervo, AcervoViewModel)> montarLigado(WidgetTester tester) async {
      final _FakeAcervo repo = _FakeAcervo();
      final AcervoViewModel vm = AcervoViewModel(repo);
      await vm.load();
      await tester.pumpWidget(
        ChangeNotifierProvider<AcervoViewModel>.value(
          value: vm,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: AcervoAcao(tipo: TipoMidia.tv, tmdbId: 1399))),
          ),
        ),
      );
      return (repo, vm);
    }

    testWidgets('o toque grava pelo ViewModel e o estado salvo aparece', (tester) async {
      final (_FakeAcervo repo, AcervoViewModel vm) = await montarLigado(tester);

      await tester.tap(find.text('Quero ver'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.marcacoes.single.complete(const Result<AcervoItem>.ok(
        AcervoItem(tmdbId: 1399, estado: EstadoAcervo.planToWatch, tipo: TipoMidia.tv),
      ));
      await tester.pumpAndSettle();

      expect(vm.estadoDe(TipoMidia.tv, 1399), EstadoAcervo.planToWatch);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Quero ver'), findsOneWidget, reason: 'agora como o estado atual');
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('falha avisa na tela e o botão volta ao que era', (tester) async {
      final (_FakeAcervo repo, _) = await montarLigado(tester);

      await tester.tap(find.text('Quero ver'));
      await tester.pump();
      repo.marcacoes.single.complete(const Result<AcervoItem>.error(NetworkError()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Não salvou no acervo'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget,
          reason: 'nunca finge que gravou');
    });

    testWidgets('tipo desconhecido não oferece botão', (tester) async {
      final AcervoViewModel vm = AcervoViewModel(_FakeAcervo());
      await vm.load();
      await tester.pumpWidget(
        ChangeNotifierProvider<AcervoViewModel>.value(
          value: vm,
          child: const MaterialApp(
            home: Scaffold(body: AcervoAcao(tipo: TipoMidia.desconhecido, tmdbId: 1)),
          ),
        ),
      );

      expect(find.text('Quero ver'), findsNothing);
    });

    Future<void> montarCom(WidgetTester tester, AcervoViewModel vm, {int tmdbId = 1399}) =>
        tester.pumpWidget(
          ChangeNotifierProvider<AcervoViewModel>.value(
            value: vm,
            child: MaterialApp(
              home: Scaffold(body: Center(child: AcervoAcao(tipo: TipoMidia.tv, tmdbId: tmdbId))),
            ),
          ),
        );

    testWidgets('acervo que não carregou não deixa gravar por cima: oferece recarregar',
        (tester) async {
      final _FakeAcervo repo =
          _FakeAcervo(lista: const Result<List<AcervoItem>>.error(NetworkError()));
      final AcervoViewModel vm = AcervoViewModel(repo);
      await vm.load();
      await montarCom(tester, vm);

      expect(find.text('Quero ver'), findsNothing,
          reason: 'o estado atual é desconhecido: "Quero ver" poderia apagar um "Assistido"');
      repo.lista = const Result<List<AcervoItem>>.ok(<AcervoItem>[]);
      await tester.tap(find.text('Recarregar acervo'));
      await tester.pumpAndSettle();

      expect(repo.leituras, 2);
      expect(repo.marcacoes, isEmpty);
      expect(find.text('Quero ver'), findsOneWidget);
    });

    testWidgets('enquanto o acervo carrega, o botão espera e não grava', (tester) async {
      final _FakeAcervo repo =
          _FakeAcervo(listaPendente: Completer<Result<List<AcervoItem>>>());
      final AcervoViewModel vm = AcervoViewModel(repo);
      unawaited(vm.load());
      await montarCom(tester, vm);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Quero ver'), findsNothing);
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();
      expect(repo.marcacoes, isEmpty);
    });

    testWidgets('"Remover" do menu remove pelo ViewModel, com o tipo', (tester) async {
      final _FakeAcervo repo = _FakeAcervo(
        lista: const Result<List<AcervoItem>>.ok(<AcervoItem>[
          AcervoItem(tmdbId: 1399, estado: EstadoAcervo.watched, tipo: TipoMidia.tv),
        ]),
      );
      final AcervoViewModel vm = AcervoViewModel(repo);
      await vm.load();
      await montarCom(tester, vm);

      await tester.tap(find.text('Assistido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover do acervo'));
      await tester.pumpAndSettle();

      expect(repo.remocoes, <String>['tv:1399']);
      expect(vm.estadoDe(TipoMidia.tv, 1399), isNull);
      expect(find.text('Quero ver'), findsOneWidget);
    });

    testWidgets('linha antiga sem tipo não oferece "Remover"', (tester) async {
      final AcervoViewModel vm = AcervoViewModel(_FakeAcervo(
        lista: const Result<List<AcervoItem>>.ok(<AcervoItem>[
          AcervoItem(tmdbId: 1399, estado: EstadoAcervo.watched),
        ]),
      ));
      await vm.load();
      await montarCom(tester, vm);

      await tester.tap(find.text('Assistido'));
      await tester.pumpAndSettle();

      expect(find.text('Remover do acervo'), findsNothing);
    });
  });
}
