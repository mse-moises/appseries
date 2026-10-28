import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:appseries/ui/view/search_page.dart';
import 'package:appseries/ui/view_model/search_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeBusca implements TituloRepository {
  _FakeBusca(this.resposta);

  final Result<List<TmdbItem>> resposta;
  int chamadas = 0;

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) async {
    chamadas++;
    return resposta;
  }

  @override
  Future<Result<List<TmdbItem>>> emAlta() => throw UnimplementedError();

  @override
  Future<Result<List<TmdbItem>>> populares() => throw UnimplementedError();

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// Sem `posterPath`: o card cai no ícone, e o teste não toca a rede de imagem.
Future<void> _buscar(WidgetTester tester, Result<List<TmdbItem>> resposta, String texto) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SearchViewModel>(
      create: (_) => SearchViewModel(_FakeBusca(resposta), espera: Duration.zero),
      child: const MaterialApp(home: SearchPage()),
    ),
  );
  await tester.enterText(find.byKey(const Key('campo-busca')), texto);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('SearchPage', () {
    testWidgets('abre com a dica, nunca em branco', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => SearchViewModel(_FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[]))),
          child: const MaterialApp(home: SearchPage()),
        ),
      );

      expect(find.text('Digite pelo menos 3 letras para buscar.'), findsOneWidget);
    });

    testWidgets('reabrir a tela não mostra a busca anterior', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => SearchViewModel(
            _FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[
              TmdbItem(id: 1, tipo: TipoMidia.movie, titulo: 'Pokémon: O Filme'),
            ])),
            espera: Duration.zero,
          ),
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SearchPage()),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('campo-busca')), 'pokemon');
      await tester.pumpAndSettle();
      expect(find.text('Pokémon: O Filme'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Pokémon: O Filme'), findsNothing);
      expect(find.text('Digite pelo menos 3 letras para buscar.'), findsOneWidget);
    });

    testWidgets('resultado mostra título, ano e tipo; o chip filtra', (tester) async {
      await _buscar(
        tester,
        const Result<List<TmdbItem>>.ok(<TmdbItem>[
          TmdbItem(id: 1, tipo: TipoMidia.movie, titulo: 'Pokémon: O Filme', ano: '1999'),
          TmdbItem(id: 2, tipo: TipoMidia.tv, titulo: 'Pokémon', ano: '1997'),
        ]),
        'pokemon',
      );

      expect(find.text('Pokémon: O Filme'), findsOneWidget);
      expect(find.text('1999 · Filme'), findsOneWidget);
      expect(find.text('1997 · Série'), findsOneWidget);

      await tester.tap(find.text('Séries'));
      await tester.pump();
      expect(find.text('Pokémon: O Filme'), findsNothing);
      expect(find.text('Pokémon'), findsOneWidget);
    });

    testWidgets('sem resultado diz o que foi buscado', (tester) async {
      await _buscar(tester, const Result<List<TmdbItem>>.ok(<TmdbItem>[]), 'xyzxyz');

      expect(find.text('Nada encontrado para "xyzxyz". Confira o nome ou tente em inglês.'), findsOneWidget);
    });

    testWidgets('erro mostra a frase e o botão de tentar de novo', (tester) async {
      await _buscar(tester, const Result<List<TmdbItem>>.error(NetworkError()), 'pokemon');

      expect(find.text(const NetworkError().mensagem), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('sem resultado do tipo escolhido, a frase diz que é o filtro', (tester) async {
      await _buscar(
        tester,
        const Result<List<TmdbItem>>.ok(<TmdbItem>[
          TmdbItem(id: 1, tipo: TipoMidia.movie, titulo: 'Pokémon: O Filme'),
        ]),
        'pokemon',
      );

      await tester.tap(find.text('Séries'));
      await tester.pump();

      expect(find.text('Nenhuma série entre os resultados para "pokemon".'), findsOneWidget);
    });

    testWidgets('tocar num resultado abre o detalhe levando o par (tipo, id)', (tester) async {
      RouteSettings? aberta;
      await tester.pumpWidget(
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => SearchViewModel(
            _FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[
              TmdbItem(id: 1399, tipo: TipoMidia.tv, titulo: 'Game of Thrones'),
            ])),
            espera: Duration.zero,
          ),
          child: MaterialApp(
            home: const SearchPage(),
            onGenerateRoute: (RouteSettings s) {
              aberta = s;
              return MaterialPageRoute<void>(builder: (_) => const Text('detalhe'));
            },
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('campo-busca')), 'game');
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Game of Thrones'));
      await tester.pumpAndSettle();

      expect(aberta?.name, Routes.detalhe);
      final TituloRef ref = aberta!.arguments! as TituloRef;
      expect((ref.tipo, ref.id), (TipoMidia.tv, 1399));
    });

    testWidgets('fechar a tela antes da pausa não chama o servidor', (tester) async {
      final _FakeBusca repo = _FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[]));
      await tester.pumpWidget(
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => SearchViewModel(repo),
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SearchPage()),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('campo-busca')), 'pokemon');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(repo.chamadas, 0, reason: 'a busca digitada antes de sair não pode ir ao servidor');
    });

    testWidgets('teclado aberto e fonte grande não estouram a dica', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => SearchViewModel(_FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[]))),
          child: const MaterialApp(home: SearchPage()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Digite pelo menos 3 letras para buscar.'), findsOneWidget);
    });
  });
}
