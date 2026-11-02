import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/ui/view/historico_page.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/data_curta.dart';
import 'package:appseries/utils/result.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAcervo implements AcervoRepository {
  _FakeAcervo(this.respostas);

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

Future<Result<List<AcervoItem>>> _ok(List<AcervoItem> itens) =>
    Future<Result<List<AcervoItem>>>.value(Result<List<AcervoItem>>.ok(itens));

Future<_FakeAcervo> _abrir(
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
        home: const HistoricoPage(),
        routes: <String, WidgetBuilder>{
          Routes.detalhe: (BuildContext c) {
            final TituloRef ref = ModalRoute.of(c)!.settings.arguments! as TituloRef;
            return Text('detalhe ${ref.tipo.name}:${ref.id}');
          },
        },
      ),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  // Meio-dia UTC: o mesmo dia em qualquer fuso do Brasil. O esperado sai do
  // `dataCurta`, que tem teste de fuso próprio.
  final DateTime dia20 = DateTime.utc(2026, 10, 20, 12);
  final DateTime dia5 = DateTime.utc(2026, 10, 5, 12);

  group('HistoricoPage (AP-73)', () {
    testWidgets('mostra os assistidos, o mais recente primeiro, com a data', (tester) async {
      final _FakeAcervo repo = await _abrir(tester, <Future<Result<List<AcervoItem>>>>[
        _ok(<AcervoItem>[
          AcervoItem(
            tmdbId: 1,
            estado: EstadoAcervo.watched,
            tipo: TipoMidia.movie,
            titulo: 'A Origem',
            atualizadoEm: dia5,
          ),
          AcervoItem(
            tmdbId: 2,
            estado: EstadoAcervo.watched,
            tipo: TipoMidia.tv,
            titulo: 'Dexter',
            atualizadoEm: dia20,
          ),
          AcervoItem(
            tmdbId: 3,
            estado: EstadoAcervo.dropped,
            tipo: TipoMidia.tv,
            titulo: 'Lost',
            atualizadoEm: dia20,
          ),
        ]),
      ]);
      await tester.pumpAndSettle();

      expect(repo.leituras, 1, reason: 'usa o acervo que a home já leu');
      expect(find.text('Lost'), findsNothing, reason: 'abandonado não entra no histórico');
      final double yDexter = tester.getTopLeft(find.text('Dexter')).dy;
      final double yOrigem = tester.getTopLeft(find.text('A Origem')).dy;
      expect(yDexter, lessThan(yOrigem), reason: 'Dexter foi marcado depois');
      expect(find.text('Assistido em ${dataCurta(dia20)}'), findsOneWidget);
      expect(find.text('Assistido em ${dataCurta(dia5)}'), findsOneWidget);
      expect(find.textContaining('TMDB API'), findsOneWidget);
    });

    testWidgets('assistido sem data diz que a data é desconhecida', (tester) async {
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[
        _ok(const <AcervoItem>[
          AcervoItem(
            tmdbId: 1,
            estado: EstadoAcervo.watched,
            tipo: TipoMidia.movie,
            titulo: 'A Origem',
          ),
        ]),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Assistido, sem data'), findsOneWidget);
      expect(find.textContaining('Assistido em'), findsNothing);
    });

    testWidgets('sem nada assistido, uma frase, nunca lista em branco', (tester) async {
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[
        _ok(const <AcervoItem>[
          AcervoItem(
            tmdbId: 1,
            estado: EstadoAcervo.watching,
            tipo: TipoMidia.movie,
            titulo: 'A Origem',
          ),
        ]),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Nada assistido ainda.'), findsOneWidget);
      expect(find.text('A Origem'), findsNothing);
    });

    testWidgets('enquanto carrega: progresso, sem a frase de vazio', (tester) async {
      final Completer<Result<List<AcervoItem>>> pendente = Completer<Result<List<AcervoItem>>>();
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[pendente.future]);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Nada assistido ainda.'), findsNothing);

      pendente.complete(const Result<List<AcervoItem>>.ok(<AcervoItem>[]));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nada assistido ainda.'), findsOneWidget);
    });

    testWidgets('erro mostra a frase e o "tentar de novo" lê de novo', (tester) async {
      final _FakeAcervo repo = await _abrir(tester, <Future<Result<List<AcervoItem>>>>[
        Future<Result<List<AcervoItem>>>.value(
          const Result<List<AcervoItem>>.error(NetworkError()),
        ),
        _ok(<AcervoItem>[
          AcervoItem(
            tmdbId: 1,
            estado: EstadoAcervo.watched,
            tipo: TipoMidia.movie,
            titulo: 'A Origem',
            atualizadoEm: dia5,
          ),
        ]),
      ]);
      await tester.pumpAndSettle();

      expect(find.text(const NetworkError().mensagem), findsOneWidget);
      expect(
        find.textContaining('Nada assistido ainda.'),
        findsNothing,
        reason: 'erro não é histórico vazio',
      );

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(repo.leituras, 2);
      expect(find.text('A Origem'), findsOneWidget);
    });

    testWidgets('tocar no título abre o detalhe com o par (tipo, id)', (tester) async {
      await _abrir(tester, <Future<Result<List<AcervoItem>>>>[
        _ok(<AcervoItem>[
          AcervoItem(
            tmdbId: 2,
            estado: EstadoAcervo.watched,
            tipo: TipoMidia.tv,
            titulo: 'Dexter',
            atualizadoEm: dia20,
          ),
        ]),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dexter'));
      await tester.pumpAndSettle();

      expect(find.text('detalhe tv:2'), findsOneWidget);
    });
  });
}
