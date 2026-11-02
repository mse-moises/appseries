import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/view/home_page.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/ui/view_model/auth_view_model.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/ui/widgets/carousel_section.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:provider/provider.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

/// Sem `posterPath`: o card cai no ícone, e o teste não toca a rede de imagem.
TmdbItem _titulo(int id) => TmdbItem(id: id, tipo: TipoMidia.movie, titulo: 'Título $id', ano: '2025');

class _FakeTituloRepository implements TituloRepository {
  _FakeTituloRepository({this.respostaEmAlta, this.respostaPopulares});

  Result<List<TmdbItem>>? respostaEmAlta;
  Result<List<TmdbItem>>? respostaPopulares;
  int chamadasEmAlta = 0;
  int chamadasPopulares = 0;

  @override
  Future<Result<List<TmdbItem>>> emAlta() async {
    chamadasEmAlta++;
    return respostaEmAlta!;
  }

  @override
  Future<Result<List<TmdbItem>>> populares() async {
    chamadasPopulares++;
    return respostaPopulares!;
  }

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) => throw UnimplementedError();

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

Result<List<TmdbItem>> _lista(List<int> ids) =>
    Result<List<TmdbItem>>.ok(<TmdbItem>[for (final int id in ids) _titulo(id)]);

class _FakeAcervoRepository implements AcervoRepository {
  @override
  Future<Result<List<AcervoItem>>> listar() async =>
      const Result<List<AcervoItem>>.ok(<AcervoItem>[]);

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// A gravação fica pendente: é assim que o teste vê a linha antes da resposta.
class _FakeAcervoPendente extends _FakeAcervoRepository {
  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      Completer<Result<AcervoItem>>().future;
}

/// A leitura nunca responde: a home fica em "Carregando seu acervo...".
class _FakeAcervoPendenteLeitura extends _FakeAcervoRepository {
  @override
  Future<Result<List<AcervoItem>>> listar() => Completer<Result<List<AcervoItem>>>().future;
}

/// Guarda as gravações para o teste responder depois do logout.
class _FakeAcervoGuardado extends _FakeAcervoRepository {
  final List<Completer<Result<AcervoItem>>> marcacoes = <Completer<Result<AcervoItem>>>[];

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) {
    final Completer<Result<AcervoItem>> c = Completer<Result<AcervoItem>>();
    marcacoes.add(c);
    return c.future;
  }
}

class _FakeAcervoComItens implements AcervoRepository {
  @override
  Future<Result<List<AcervoItem>>> listar() async => Result<List<AcervoItem>>.ok(
        <AcervoItem>[
          for (int i = 0; i < 3; i++)
            AcervoItem(tmdbId: i, estado: EstadoAcervo.watched, tipo: TipoMidia.movie),
        ],
      );

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// Falha na primeira chamada e responde vazio na segunda: prova o retry.
class _FakeAcervoFalhaDepoisOk implements AcervoRepository {
  int chamadas = 0;

  @override
  Future<Result<List<AcervoItem>>> listar() async {
    chamadas++;
    if (chamadas == 1) return const Result<List<AcervoItem>>.error(NetworkError());
    return const Result<List<AcervoItem>>.ok(<AcervoItem>[]);
  }

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.saidaFalha = false, this.pendurarSaida = false});

  final bool saidaFalha;
  final bool pendurarSaida;
  final StreamController<AppUser?> _sessao = StreamController<AppUser?>.broadcast();
  final Completer<void> _saidaPendurada = Completer<void>();
  int saidas = 0;

  void soltarSaida() => _saidaPendurada.complete();

  @override
  Stream<AppUser?> get sessionStream => _sessao.stream;

  @override
  Future<Result<AppUser>> signIn(String email, String password) async =>
      const Result<AppUser>.ok(_livia);

  @override
  Future<Result<AppUser>> signUp(String email, String password) async =>
      const Result<AppUser>.ok(_livia);

  @override
  Future<Result<AppUser>> signInWithGoogle() async => const Result<AppUser>.ok(_livia);

  @override
  Future<Result<void>> signOut() async {
    saidas++;
    if (pendurarSaida) await _saidaPendurada.future;
    if (saidaFalha) return const Result<void>.error(ServerError());
    return const Result<void>.ok(null);
  }

  /// Sincrono: em `testWidgets` o relogio e falso.
  void emitir(AppUser? user) => _sessao.add(user);
}

/// A home carrega dois carrosséis em sequência, então precisa de mais de um
/// frame para assentar.
Future<void> _assentar(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump();
  }
}

Future<_FakeAuthRepository> _montar(
  WidgetTester tester, {
  _FakeAuthRepository? auth,
  TituloRepository? titulos,
  AcervoRepository? acervo,
}) async {
  final _FakeAuthRepository repo = auth ?? _FakeAuthRepository();
  // A rota da busca vira um marcador: aqui só importa que a caixa leva até ela.
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(
            titulos ??
                _FakeTituloRepository(respostaEmAlta: _lista(<int>[1]), respostaPopulares: _lista(<int>[2])),
          ),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel(repo),
        ),
        ChangeNotifierProvider<AcervoViewModel>(
          create: (_) => AcervoViewModel(acervo ?? _FakeAcervoRepository()),
        ),
      ],
      child: MaterialApp(
        home: const HomePage(),
        routes: <String, WidgetBuilder>{
          Routes.busca: (BuildContext _) => const Text('tela de busca'),
          Routes.acervo: (BuildContext _) => const Text('tela do acervo'),
          // O detalhe vira um marcador que mostra o par que recebeu.
          Routes.detalhe: (BuildContext c) {
            final TituloRef ref = ModalRoute.of(c)!.settings.arguments! as TituloRef;
            return Text('detalhe ${ref.tipo.name}:${ref.id}');
          },
        },
      ),
    ),
  );
  await _assentar(tester);
  return repo;
}

void main() {
  group('HomePage', () {
    testWidgets('mostra os títulos dos dois carrosséis', (tester) async {
      await _montar(
        tester,
        titulos: _FakeTituloRepository(
          respostaEmAlta: _lista(<int>[1, 2]),
          respostaPopulares: _lista(<int>[3]),
        ),
      );

      expect(find.text('Em alta'), findsOneWidget);
      expect(find.text('Populares'), findsOneWidget);
      expect(find.text('Título 1'), findsOneWidget);
      expect(find.text('Título 3'), findsOneWidget);
    });

    testWidgets('o filtro Séries/Filmes troca o que os carrosséis mostram', (tester) async {
      await _montar(
        tester,
        titulos: _FakeTituloRepository(
          respostaEmAlta: const Result<List<TmdbItem>>.ok(<TmdbItem>[
            TmdbItem(id: 1, tipo: TipoMidia.movie, titulo: 'Filme 1'),
            TmdbItem(id: 2, tipo: TipoMidia.tv, titulo: 'Série 2'),
          ]),
          respostaPopulares: _lista(<int>[]),
        ),
      );

      expect(find.text('Filme 1'), findsOneWidget);
      expect(find.text('Série 2'), findsOneWidget);

      await tester.tap(find.text('Séries'));
      await tester.pump();
      expect(find.text('Filme 1'), findsNothing);
      expect(find.text('Série 2'), findsOneWidget);

      await tester.tap(find.text('Filmes'));
      await tester.pump();
      expect(find.text('Filme 1'), findsOneWidget);
      expect(find.text('Série 2'), findsNothing);
    });

    testWidgets('filtro que esvazia o carrossel diz que é o filtro', (tester) async {
      await _montar(tester);

      await tester.tap(find.text('Séries'));
      await tester.pump();

      expect(find.text('Nenhuma série em alta agora.'), findsOneWidget);
      expect(find.text('Nenhuma série entre os populares agora.'), findsOneWidget);
      expect(find.text('Nada por aqui agora.'), findsNothing);
    });

    testWidgets('a caixa de busca abre a busca pelo toque', (tester) async {
      await _montar(tester);

      await tester.tap(find.byKey(const Key('busca-home')));
      await tester.pumpAndSettle();

      expect(find.text('tela de busca'), findsOneWidget);
    });

    testWidgets('com foco, a caixa de busca abre a busca pelo Enter', (tester) async {
      await _montar(tester);

      final FocusNode? foco = Focus.maybeOf(
        tester.element(find.descendant(of: find.byKey(const Key('busca-home')), matching: find.byType(Row))),
      );
      foco!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('tela de busca'), findsOneWidget);
    });

    testWidgets('catálogo fora do ar: frase clara, e o retry volta depois de nova falha (AP-79)',
        (tester) async {
      final _FakeTituloRepository titulos = _FakeTituloRepository(
        respostaEmAlta: const Result<List<TmdbItem>>.error(CatalogoIndisponivelError()),
        respostaPopulares: _lista(<int>[2]),
      );
      await _montar(tester, titulos: titulos);

      expect(find.text(const CatalogoIndisponivelError().mensagem), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);

      await tester.tap(find.text('Tentar de novo'));
      await _assentar(tester);
      expect(find.text('Tentar de novo'), findsOneWidget, reason: 'nova falha, o botão reaparece');
      expect(titulos.chamadasEmAlta, 2);

      titulos.respostaEmAlta = _lista(<int>[1]);
      await tester.tap(find.text('Tentar de novo'));
      await _assentar(tester);
      expect(find.text('Título 1'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });

    testWidgets('cada pôster da home tem o botão de "Quero ver" (AP-50)', (tester) async {
      await _montar(
        tester,
        titulos: _FakeTituloRepository(
          respostaEmAlta: _lista(<int>[1, 2]),
          respostaPopulares: _lista(<int>[3]),
        ),
      );

      expect(find.byTooltip('Quero ver'), findsNWidgets(3));
    });

    testWidgets('marcar no pôster leva título, ano e pôster para a linha do acervo', (tester) async {
      await _montar(
        tester,
        titulos: _FakeTituloRepository(
          respostaEmAlta: const Result<List<TmdbItem>>.ok(<TmdbItem>[
            TmdbItem(
              id: 1,
              tipo: TipoMidia.movie,
              titulo: 'Título 1',
              ano: '2025',
              posterPath: '/poster-1.jpg',
            ),
          ]),
          respostaPopulares: _lista(<int>[]),
        ),
        acervo: _FakeAcervoPendente(),
      );

      await tester.tap(find.byTooltip('Quero ver'));
      await tester.pump();

      final AcervoViewModel acervo =
          Provider.of<AcervoViewModel>(tester.element(find.byType(HomePage)), listen: false);
      expect(acervo.enviando(TipoMidia.movie, 1), isTrue, reason: 'ainda gravando');
      expect(acervo.itens.single.titulo, 'Título 1');
      expect(acervo.itens.single.ano, '2025');
      expect(acervo.itens.single.posterPath, '/poster-1.jpg');
    });

    testWidgets('"Ver acervo" abre a tela do acervo (AP-59)', (tester) async {
      await _montar(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('abrir-acervo')));
      await tester.pumpAndSettle();

      expect(find.text('tela do acervo'), findsOneWidget);
    });

    testWidgets('sem acervo carregado não há "Ver acervo"', (tester) async {
      await _montar(tester, acervo: _FakeAcervoPendenteLeitura());
      await tester.pump();

      expect(find.byKey(const Key('abrir-acervo')), findsNothing,
          reason: 'enquanto carrega, a linha diz "Carregando"');
    });

    testWidgets('falha que chega depois do logout não aparece no login', (tester) async {
      final _FakeAcervoGuardado acervoRepo = _FakeAcervoGuardado();
      final AcervoViewModel acervo = AcervoViewModel(acervoRepo);
      // Como o AuthGate: a sessão decide entre home e login, e ninguém chama
      // reset() à mão no logout.
      final ValueNotifier<bool> logado = ValueNotifier<bool>(true);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HomeViewModel>(
              create: (_) => HomeViewModel(
                _FakeTituloRepository(respostaEmAlta: _lista(<int>[1]), respostaPopulares: _lista(<int>[])),
              ),
            ),
            ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel(_FakeAuthRepository())),
            ChangeNotifierProvider<AcervoViewModel>.value(value: acervo),
          ],
          child: MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: logado,
              builder: (_, bool l, __) => l ? const HomePage() : const Text('tela de login'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Quero ver'));
      await tester.pump();
      expect(acervoRepo.marcacoes, hasLength(1));

      logado.value = false;
      await tester.pump();
      acervoRepo.marcacoes.single.complete(const Result<AcervoItem>.error(NetworkError()));
      await tester.pumpAndSettle();

      expect(find.text('tela de login'), findsOneWidget);
      expect(find.textContaining('Não salvou no acervo.'), findsNothing);
    });

    testWidgets('com a home na tela, a falha avisa', (tester) async {
      final _FakeAcervoGuardado acervoRepo = _FakeAcervoGuardado();
      await _montar(tester, acervo: acervoRepo);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Quero ver').first);
      await tester.pump();
      acervoRepo.marcacoes.single.complete(const Result<AcervoItem>.error(NetworkError()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Não salvou no acervo.'), findsOneWidget);
    });

    testWidgets('tocar no pôster abre o detalhe com o par (tipo, id)', (tester) async {
      await _montar(tester);

      await tester.tap(find.text('Título 1'));
      await tester.pumpAndSettle();

      expect(find.text('detalhe movie:1'), findsOneWidget);
    });

    testWidgets('mostra a atribuição do TMDB', (tester) async {
      await _montar(tester);

      expect(find.textContaining('TMDB API'), findsOneWidget);
    });

    testWidgets('conta sem nada no acervo mostra 0', (tester) async {
      await _montar(tester);

      expect(find.text('Seu acervo: 0 títulos'), findsOneWidget);
    });

    testWidgets('carrossel que falha não derruba o outro e o retry recarrega só ele',
        (tester) async {
      final _FakeTituloRepository repo = _FakeTituloRepository(
        respostaEmAlta: const Result<List<TmdbItem>>.error(NetworkError()),
        respostaPopulares: _lista(<int>[3]),
      );
      await _montar(tester, titulos: repo);

      expect(find.text('Em alta'), findsOneWidget);
      expect(
        find.text('Sem conexão com a internet. Confira sua rede e tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('Título 3'), findsOneWidget);

      // o retry do carrossel que falhou, e não o do outro
      repo.respostaEmAlta = _lista(<int>[1]);
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(CarouselSection, 'Em alta'),
          matching: find.widgetWithText(TextButton, 'Tentar de novo'),
        ),
      );
      await _assentar(tester);

      expect(find.text('Título 1'), findsOneWidget);
      expect(repo.chamadasEmAlta, 2);
      expect(repo.chamadasPopulares, 1, reason: 'Populares não pode ser recarregado junto');
    });

    testWidgets('acervo que falha não derruba a home e o retry recarrega', (tester) async {
      final _FakeAcervoFalhaDepoisOk repo = _FakeAcervoFalhaDepoisOk();

      await _montar(tester, acervo: repo);

      expect(find.text('Título 1'), findsOneWidget, reason: 'os carrosséis continuam na tela');
      expect(
        find.text('Sem conexão com a internet. Confira sua rede e tente de novo.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('acervo-retry')));
      await _assentar(tester);

      expect(repo.chamadas, 2);
      expect(find.text('Seu acervo: 0 títulos'), findsOneWidget);
    });

    testWidgets('no primeiro frame após o login não mostra dados da conta anterior',
        (tester) async {
      // conta anterior, já carregada: dois títulos e três itens no acervo
      final HomeViewModel homeAnterior = HomeViewModel(
        _FakeTituloRepository(
          respostaEmAlta: _lista(<int>[7, 8]),
          respostaPopulares: _lista(<int>[9]),
        ),
      );
      await homeAnterior.load();
      final AcervoViewModel acervoAnterior = AcervoViewModel(_FakeAcervoComItens());
      await acervoAnterior.load();
      expect(homeAnterior.emAlta.itens, hasLength(2));
      expect(acervoAnterior.total, 3);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HomeViewModel>.value(value: homeAnterior),
            ChangeNotifierProvider<AuthViewModel>(
              create: (_) => AuthViewModel(_FakeAuthRepository()),
            ),
            ChangeNotifierProvider<AcervoViewModel>.value(value: acervoAnterior),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      // o primeiro frame é do reset, não dos dados de quem saiu
      expect(find.text('Título 7'), findsNothing,
          reason: 'os títulos da conta anterior não podem aparecer');
      expect(find.text('Seu acervo: 3 títulos'), findsNothing,
          reason: 'a contagem da conta anterior não pode aparecer');
      expect(find.text('Carregando seu acervo...'), findsOneWidget);
    });

    testWidgets('mostra com qual conta ela está logada', (tester) async {
      final auth = await _montar(tester);

      auth.emitir(_livia);
      await tester.pump();
      await tester.pump();

      expect(find.text('livia@exemplo.com'), findsOneWidget);
    });

    testWidgets('montar de novo recarrega: a segunda conta não herda a primeira',
        (tester) async {
      final _FakeTituloRepository repo = _FakeTituloRepository(
        respostaEmAlta: _lista(<int>[1]),
        respostaPopulares: _lista(<int>[2]),
      );
      final HomeViewModel homeVm = HomeViewModel(repo);
      final AcervoViewModel acervoVm = AcervoViewModel(_FakeAcervoRepository());

      Future<void> montar() async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
              ChangeNotifierProvider<AuthViewModel>(
                create: (_) => AuthViewModel(_FakeAuthRepository()),
              ),
              ChangeNotifierProvider<AcervoViewModel>.value(value: acervoVm),
            ],
            child: const MaterialApp(home: HomePage()),
          ),
        );
        await _assentar(tester);
      }

      await montar();
      expect(repo.chamadasEmAlta, 1);

      // O logout desmonta a home: sem esta troca o `pumpWidget` só atualizaria a
      // árvore existente e o `initState` não rodaria de novo.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      await montar();

      expect(
        repo.chamadasEmAlta,
        2,
        reason: 'a segunda conta não pode abrir com a resposta da primeira',
      );
    });

    testWidgets('em tela pequena (360x640) nada estoura e o rodapé cabe', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final auth = await _montar(tester);
      // e-mail longo de propósito: o rodapé tem de truncar em uma linha
      auth.emitir(
        const AppUser(id: 'u1', email: 'nome.sobrenome.comprido@exemplo-interno.com.br'),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'overflow de layout vira exceção no teste');
      expect(find.text('nome.sobrenome.comprido@exemplo-interno.com.br'), findsOneWidget);
      final Text textoEmail =
          tester.widget<Text>(find.text('nome.sobrenome.comprido@exemplo-interno.com.br'));
      expect(textoEmail.maxLines, 1, reason: 'e-mail longo trunca, não quebra a linha');
      expect(textoEmail.overflow, TextOverflow.ellipsis);
      expect(find.text('Seu acervo: 0 títulos'), findsOneWidget);
      expect(find.textContaining('TMDB API'), findsOneWidget);
    });

    testWidgets('em tela pequena com fonte grande (2x) nada estoura', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _montar(tester);

      expect(tester.takeException(), isNull,
          reason: 'a caixa de busca e os chips presos acima da lista estouravam a coluna');
      expect(find.byKey(const Key('busca-home')), findsOneWidget);
    });

    testWidgets('o botão Sair pede o logout', (tester) async {
      final auth = await _montar(tester);

      await tester.tap(find.byTooltip('Sair'));
      await tester.pump();

      expect(auth.saidas, 1);
    });

    testWidgets('enquanto sai, o ícone vira espera', (tester) async {
      final auth = await _montar(tester, auth: _FakeAuthRepository(pendurarSaida: true));

      await tester.tap(find.byTooltip('Sair'));
      await tester.pump();

      expect(find.byTooltip('Sair'), findsNothing);

      auth.soltarSaida();
      await tester.pump();
    });

    testWidgets('sair que falha diz na tela e a faixa fecha', (tester) async {
      await _montar(tester, auth: _FakeAuthRepository(saidaFalha: true));

      await tester.tap(find.byTooltip('Sair'));
      await tester.pump();
      await tester.pump();

      expect(find.text('O servidor deu uma escorregada. Tente em instantes.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Fechar'));
      await tester.pump();

      expect(find.text('O servidor deu uma escorregada. Tente em instantes.'), findsNothing);
    });
  });
}
