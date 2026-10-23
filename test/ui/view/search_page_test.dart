import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
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

class _FakeAcervo implements AcervoRepository {
  final List<String> marcados = <String>[];

  @override
  Future<Result<List<AcervoItem>>> listar() async =>
      const Result<List<AcervoItem>>.ok(<AcervoItem>[]);

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) async {
    marcados.add('${tipo.name}:$tmdbId ${estado.name}');
    return Result<AcervoItem>.ok(AcervoItem(tmdbId: tmdbId, estado: estado, tipo: tipo));
  }

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// A tela de busca lê a busca e o acervo da raiz, como no `main.dart`.
Widget _comProviders(SearchViewModel busca, Widget filho, {AcervoViewModel? acervo}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SearchViewModel>.value(value: busca),
        ChangeNotifierProvider<AcervoViewModel>.value(
          value: acervo ?? (AcervoViewModel(_FakeAcervo())..load()),
        ),
      ],
      child: filho,
    );

/// Sem `posterPath`: o card cai no ícone, e o teste não toca a rede de imagem.
Future<void> _buscar(WidgetTester tester, Result<List<TmdbItem>> resposta, String texto) async {
  await tester.pumpWidget(
    _comProviders(
      SearchViewModel(_FakeBusca(resposta), espera: Duration.zero),
      const MaterialApp(home: SearchPage()),
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
        _comProviders(
          SearchViewModel(_FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[]))),
          const MaterialApp(home: SearchPage()),
        ),
      );

      expect(find.text('Digite pelo menos 3 letras para buscar.'), findsOneWidget);
    });

    testWidgets('reabrir a tela não mostra a busca anterior', (tester) async {
      await tester.pumpWidget(
        _comProviders(
          SearchViewModel(
            _FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[
              TmdbItem(id: 1, tipo: TipoMidia.movie, titulo: 'Pokémon: O Filme'),
            ])),
            espera: Duration.zero,
          ),
          MaterialApp(
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

    testWidgets('catálogo fora do ar na busca: frase clara e retry (AP-79)', (tester) async {
      await _buscar(
        tester,
        const Result<List<TmdbItem>>.error(CatalogoIndisponivelError()),
        'pokemon',
      );

      expect(find.text(const CatalogoIndisponivelError().mensagem), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('erro mostra a frase e o botão de tentar de novo', (tester) async {
      await _buscar(tester, const Result<List<TmdbItem>>.error(NetworkError()), 'pokemon');

      expect(find.text(const NetworkError().mensagem), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('o resultado tem o mesmo botão do acervo: um toque grava "Quero ver"', (tester) async {
      final _FakeAcervo repo = _FakeAcervo();
      final AcervoViewModel acervo = AcervoViewModel(repo);
      await acervo.load();
      await tester.pumpWidget(
        _comProviders(
          SearchViewModel(
            _FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[
              TmdbItem(id: 2, tipo: TipoMidia.tv, titulo: 'Pokémon', ano: '1997'),
            ])),
            espera: Duration.zero,
          ),
          const MaterialApp(home: SearchPage()),
          acervo: acervo,
        ),
      );
      await tester.enterText(find.byKey(const Key('campo-busca')), 'pokemon');
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Quero ver'));
      await tester.pumpAndSettle();

      expect(repo.marcados, <String>['tv:2 planToWatch']);
      expect(acervo.estadoDe(TipoMidia.tv, 2), EstadoAcervo.planToWatch);
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
        _comProviders(
          SearchViewModel(
            _FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[
              TmdbItem(id: 1399, tipo: TipoMidia.tv, titulo: 'Game of Thrones'),
            ])),
            espera: Duration.zero,
          ),
          MaterialApp(
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
        _comProviders(
          SearchViewModel(repo),
          MaterialApp(
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
        _comProviders(
          SearchViewModel(_FakeBusca(const Result<List<TmdbItem>>.ok(<TmdbItem>[]))),
          const MaterialApp(home: SearchPage()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Digite pelo menos 3 letras para buscar.'), findsOneWidget);
    });

    testWidgets('resultado em tela estreita com fonte grande não estoura', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _buscar(
        tester,
        const Result<List<TmdbItem>>.ok(<TmdbItem>[
          TmdbItem(id: 1, tipo: TipoMidia.movie, titulo: 'Pokémon: O Filme', ano: '1999'),
        ]),
        'pokemon',
      );

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Quero ver'), findsOneWidget, reason: 'o botão compacto cabe');
    });
  });
}
