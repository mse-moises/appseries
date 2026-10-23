import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
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

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) async => resposta;

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

      expect(find.text('Nada encontrado para "xyzxyz". Tente outro nome.'), findsOneWidget);
    });

    testWidgets('erro mostra a frase e o botão de tentar de novo', (tester) async {
      await _buscar(tester, const Result<List<TmdbItem>>.error(NetworkError()), 'pokemon');

      expect(find.text(const NetworkError().mensagem), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });
}
