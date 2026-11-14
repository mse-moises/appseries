import 'dart:async';

import 'package:appseries/app.dart';
import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/carta_rec.dart';
import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/api_models/preferencias.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/data/repositories/feedback_repository.dart';
import 'package:appseries/data/repositories/rec_repository.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/ui/view/acervo_tabs_page.dart';
import 'package:appseries/ui/view/historico_page.dart';
import 'package:appseries/ui/view/home_page.dart';
import 'package:appseries/ui/view/login_page.dart';
import 'package:appseries/ui/view/preferences_page.dart';
import 'package:appseries/ui/view/rec_page.dart';
import 'package:appseries/ui/view/search_page.dart';
import 'package:appseries/ui/view/title_detail_page.dart';
import 'package:appseries/ui/widgets/genero_chip.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/ui/view_model/auth_view_model.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/ui/view_model/login_view_model.dart';
import 'package:appseries/ui/view_model/preferences_view_model.dart';
import 'package:appseries/ui/view_model/rec_view_model.dart';
import 'package:appseries/ui/view_model/search_view_model.dart';
import 'package:appseries/ui/view_model/title_detail_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/fake_preferencias.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AppUser?> get sessionStream => const Stream<AppUser?>.empty();

  @override
  Future<Result<AppUser>> signIn(String email, String password) async =>
      const Result<AppUser>.error(UnauthorizedError());

  @override
  Future<Result<AppUser>> signUp(String email, String password) async =>
      const Result<AppUser>.error(UnauthorizedError());

  @override
  Future<Result<AppUser>> signInWithGoogle() async =>
      const Result<AppUser>.error(UnauthorizedError());

  @override
  Future<Result<void>> signOut() async => const Result<void>.ok(null);
}

/// A busca abre ociosa: só abrir a rota não pode chamar o servidor. O detalhe
/// guarda o par que pediu.
class _FakeTituloRepository implements TituloRepository {
  int buscas = 0;
  final List<String> pedidos = <String>[];

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) async {
    buscas++;
    return const Result<List<TmdbItem>>.ok(<TmdbItem>[]);
  }

  // A home monta embaixo do detalhe aberto pela URL e carrega os carrosséis.
  @override
  Future<Result<List<TmdbItem>>> emAlta() async => const Result<List<TmdbItem>>.ok(<TmdbItem>[]);

  @override
  Future<Result<List<TmdbItem>>> populares() async =>
      const Result<List<TmdbItem>>.ok(<TmdbItem>[]);

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) async {
    pedidos.add('${tipo.name}:$tmdbId');
    return Result<TituloDetalhe>.ok(
      TituloDetalhe(id: tmdbId, tipo: tipo, titulo: 'Game of Thrones'),
    );
  }
}

class _FakeAcervo implements AcervoRepository {
  @override
  Future<Result<List<AcervoItem>>> listar() async =>
      const Result<List<AcervoItem>>.ok(<AcervoItem>[]);

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

class _FakeFeedback implements FeedbackRepository {
  @override
  Future<Result<List<FeedbackItem>>> listar() async =>
      const Result<List<FeedbackItem>>.ok(<FeedbackItem>[]);

  @override
  Future<Result<FeedbackItem>> marcar(
    TipoMidia tipo,
    int tmdbId,
    SinalGosto sinal, {
    int peso = 2,
    OrigemFeedback origem = OrigemFeedback.fechamento,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// A recomendação abre ociosa: só abrir a rota não pode chamar o servidor.
class _FakeRec implements RecRepository {
  int chamadas = 0;

  @override
  Future<Result<RecResult>> recomendar({String? momento}) async {
    chamadas++;
    return const Result<RecResult>.ok(
      RecResult(cartas: <CartaRec>[], origem: OrigemRec.llm),
    );
  }
}

final _FakeTituloRepository _titulos = _FakeTituloRepository();
final _FakeRec _rec = _FakeRec();

/// A sessão chega quando o teste quiser, como o SDK restaurando depois do F5.
class _SessaoControlada extends _FakeAuthRepository {
  final StreamController<AppUser?> controle = StreamController<AppUser?>();

  @override
  Stream<AppUser?> get sessionStream => controle.stream;
}

/// Abre o app inteiro na URL dada, como um F5 ou um link colado: a rota inicial
/// vem da barra de endereço, não de um `pushNamed`.
Future<(_SessaoControlada, _FakeTituloRepository)> _abrirPelaUrl(
  WidgetTester tester,
  String url, {
  PreferencesViewModel Function()? preferencias,
}) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue = url;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
  final _SessaoControlada sessao = _SessaoControlada();
  addTearDown(sessao.controle.close);
  final _FakeTituloRepository titulos = _FakeTituloRepository();

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel(sessao)),
      ChangeNotifierProvider<LoginViewModel>(create: (_) => LoginViewModel(sessao)),
      ChangeNotifierProvider<HomeViewModel>(create: (_) => HomeViewModel(titulos)),
      ChangeNotifierProvider<SearchViewModel>(create: (_) => SearchViewModel(titulos)),
      ChangeNotifierProvider<AcervoViewModel>(create: (_) => AcervoViewModel(_FakeAcervo())),
      ChangeNotifierProvider<TitleDetailViewModel>(
        create: (_) => TitleDetailViewModel(titulos, _FakeFeedback()),
      ),
      ChangeNotifierProvider<PreferencesViewModel>(
        create: (_) => (preferencias ?? preferenciasJaEscolhidas)(),
      ),
    ],
    child: const App(),
  ));
  await tester.pump();
  return (sessao, titulos);
}

const AppUser _usuaria = AppUser(id: 'u1', email: 'a@b.com');

/// Abre a rota pelo caminho real do app: `Navigator.pushNamed`, não uma rota
/// montada à mão no teste.
Future<void> _empurrar(WidgetTester tester, String nome, {Object? argumentos}) async {
  // As telas leem os ViewModels da raiz, como no `main.dart`.
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SearchViewModel>(create: (_) => SearchViewModel(_titulos)),
      // Carregado, como a home deixa: sem isso o botão do acervo espera para sempre.
      ChangeNotifierProvider<AcervoViewModel>(create: (_) => AcervoViewModel(_FakeAcervo())..load()),
      ChangeNotifierProvider<TitleDetailViewModel>(
        create: (_) => TitleDetailViewModel(_titulos, _FakeFeedback()),
      ),
      ChangeNotifierProvider<RecViewModel>(create: (_) => RecViewModel(_rec)),
      ChangeNotifierProvider<PreferencesViewModel>(create: (_) => preferenciasJaEscolhidas()),
    ],
    child: MaterialApp(
      key: ValueKey<String>('rota-$nome'),
      routes: Routes.mapa,
      home: Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => Navigator.pushNamed(context, nome, arguments: argumentos),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('Routes.mapa', () {
    test('as rotas internas estão registradas', () {
      expect(
        Routes.mapa.keys,
        containsAll(<String>[
          Routes.busca,
          Routes.detalhe,
          Routes.acervo,
          Routes.historico,
          Routes.preferencias,
          Routes.recomendacao,
        ]),
      );
    });

    testWidgets('o app monta o MaterialApp com o mapa de rotas', (tester) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<AuthRepository>(create: (_) => _FakeAuthRepository()),
          ChangeNotifierProvider<AuthViewModel>(
            create: (BuildContext c) => AuthViewModel(c.read<AuthRepository>()),
          ),
          ChangeNotifierProvider<LoginViewModel>(
            create: (BuildContext c) => LoginViewModel(c.read<AuthRepository>()),
          ),
          ChangeNotifierProvider<PreferencesViewModel>(create: (_) => preferenciasJaEscolhidas()),
        ],
        child: const App(),
      ));
      await tester.pump();

      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      // Sem `routes:`: um nome exato casaria ali e pularia a espera pela sessão.
      expect(app.routes ?? const <String, WidgetBuilder>{}, isEmpty);
      for (final String nome in <String>[
        Routes.busca,
        Routes.detalhe,
        Routes.acervo,
        Routes.historico,
        Routes.preferencias,
        Routes.recomendacao,
      ]) {
        expect(app.onGenerateRoute!(RouteSettings(name: nome)), isNotNull,
            reason: 'sem rota no App, $nome não é alcançável');
      }
    });

    testWidgets('cada rota abre a sua tela', (tester) async {
      final Map<String, Type> esperado = <String, Type>{
        Routes.busca: SearchPage,
        Routes.acervo: AcervoTabsPage,
        Routes.historico: HistoricoPage,
        Routes.preferencias: PreferencesPage,
        Routes.recomendacao: RecPage,
      };

      for (final MapEntry<String, Type> e in esperado.entries) {
        await _empurrar(tester, e.key);
        expect(find.byType(e.value), findsOneWidget, reason: 'rota ${e.key}');
      }
      expect(_titulos.buscas, 0, reason: 'abrir a busca não pode chamar o servidor');
      expect(_rec.chamadas, 0, reason: 'abrir a recomendação não pode gastar uma das 20 do dia');
    });

    testWidgets('pushNamed leva o TituloRef até o detalhe', (tester) async {
      await _empurrar(
        tester,
        Routes.detalhe,
        argumentos: const TituloRef(tipo: TipoMidia.tv, id: 1399),
      );

      expect(find.byType(TitleDetailPage), findsOneWidget);
      expect(_titulos.pedidos.last, 'tv:1399', reason: 'o detalhe pede o par que recebeu');
      expect(find.text('Game of Thrones'), findsWidgets);
    });

    testWidgets('detalhe sem argumento degrada em vez de estourar', (tester) async {
      await _empurrar(tester, Routes.detalhe);

      expect(find.byType(TitleDetailPage), findsOneWidget);
      expect(find.text(const TituloIndisponivelError().mensagem), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing, reason: 'sem par não há o que repetir');
      expect(tester.takeException(), isNull);
    });
  });

  group('nome do detalhe com o par', () {
    test('o par vai e volta pelo nome da rota', () {
      for (final TituloRef ref in const <TituloRef>[
        TituloRef(tipo: TipoMidia.tv, id: 1399),
        TituloRef(tipo: TipoMidia.movie, id: 550),
      ]) {
        final TituloRef? volta = Routes.refDoDetalhe(Routes.detalheDe(ref));
        expect((volta?.tipo, volta?.id), (ref.tipo, ref.id));
      }
      expect(Routes.detalheDe(const TituloRef(tipo: TipoMidia.movie, id: 550)),
          '/detalhe?tipo=movie&id=550');
    });

    test('tipo desconhecido fica no nome puro, sem inventar par', () {
      expect(Routes.detalheDe(const TituloRef(tipo: TipoMidia.desconhecido, id: 7)), Routes.detalhe);
    });

    test('nome sem par, com par quebrado ou de outra rota não vira título', () {
      for (final String nome in const <String>[
        '/detalhe',
        '/detalhe?tipo=tv',
        '/detalhe?id=1399',
        '/detalhe?tipo=anime&id=1',
        '/detalhe?tipo=desconhecido&id=1',
        '/detalhe?tipo=tv&id=abc',
        '/detalhe?tipo=tv&id=0',
        '/acervo?tipo=tv&id=1399',
      ]) {
        expect(Routes.refDoDetalhe(nome), isNull, reason: nome);
      }
    });
  });

  group('abrir pela URL (F5 ou link colado)', () {
    testWidgets('detalhe espera a sessão voltar e abre o mesmo título', (tester) async {
      final (_SessaoControlada sessao, _FakeTituloRepository titulos) =
          await _abrirPelaUrl(tester, '/detalhe?tipo=tv&id=1399');

      expect(titulos.pedidos, isEmpty,
          reason: 'sem sessão o pedido sairia sem token, e o 401 deslogaria a pessoa');
      expect(find.byType(TitleDetailPage), findsNothing);
      expect(find.text('Só um instante...'), findsOneWidget);

      sessao.controle.add(_usuaria);
      await tester.pumpAndSettle();

      expect(titulos.pedidos, <String>['tv:1399']);
      expect(find.byType(TitleDetailPage), findsOneWidget);
      expect(find.text('Game of Thrones'), findsWidgets);

      // Voltar leva para onde um toque teria vindo: a home, pelo gate.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('sem sessão volta para o login sem chamar o servidor', (tester) async {
      final (_SessaoControlada sessao, _FakeTituloRepository titulos) =
          await _abrirPelaUrl(tester, '/detalhe?tipo=tv&id=1399');

      sessao.controle.add(null);
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(TitleDetailPage), findsNothing);
      expect(titulos.pedidos, isEmpty);
    });

    testWidgets('detalhe sem o par na URL degrada, sem pedir nada', (tester) async {
      final (_SessaoControlada sessao, _FakeTituloRepository titulos) =
          await _abrirPelaUrl(tester, '/detalhe');

      sessao.controle.add(_usuaria);
      await tester.pumpAndSettle();

      expect(find.text(const TituloIndisponivelError().mensagem), findsOneWidget);
      expect(titulos.pedidos, isEmpty);
    });

    // O gate (resetSessao + verificarPrimeiroAcesso) e a tela (carregar) usam o
    // mesmo PreferencesViewModel e montam no mesmo frame quando a sessão volta.
    testWidgets('F5 em /preferencias abre com os gêneros salvos e o Salvar ativo', (tester) async {
      final FakePreferenciasRepository repo = FakePreferenciasRepository(
        atual: const Preferencias(momento: 'algo leve', generos: <String>['Drama', 'Terror']),
      );
      final (_SessaoControlada sessao, _) = await _abrirPelaUrl(
        tester,
        Routes.preferencias,
        preferencias: () => PreferencesViewModel(
          repo,
          FakePrimeiroAcessoRepository(marcados: <String>{_usuaria.id}),
        ),
      );
      expect(find.byType(PreferencesPage), findsNothing);

      sessao.controle.add(_usuaria);
      await tester.pumpAndSettle();

      expect(find.byType(PreferencesPage), findsOneWidget);
      for (final String g in <String>['Drama', 'Terror']) {
        expect(
          tester.widget<GeneroChip>(find.byKey(ValueKey<String>('genero-$g'))).selecionado,
          isTrue,
          reason: '$g veio do GET',
        );
      }
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('preferencias-salvar'))).onPressed,
        isNotNull,
        reason: 'a leitura chegou: salvar não apaga o momento',
      );

      await tester.tap(find.byKey(const ValueKey<String>('genero-Ação')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('preferencias-salvar')));
      await tester.pumpAndSettle();

      expect(repo.atual.momento, 'algo leve');
      expect(repo.atual.generos, <String>['Ação', 'Drama', 'Terror']);
      expect(find.byType(HomePage), findsOneWidget, reason: 'salvar volta para a home do gate');
    });

    testWidgets('F5 em /preferencias numa conta nova abre os chips sem estourar', (tester) async {
      final (_SessaoControlada sessao, _) = await _abrirPelaUrl(
        tester,
        Routes.preferencias,
        preferencias: () =>
            PreferencesViewModel(FakePreferenciasRepository(), FakePrimeiroAcessoRepository()),
      );

      sessao.controle.add(_usuaria);
      await tester.pumpAndSettle();

      expect(find.byType(PreferencesPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('outra tela interna também espera a sessão', (tester) async {
      final (_SessaoControlada sessao, _) = await _abrirPelaUrl(tester, '/acervo');

      expect(find.byType(AcervoTabsPage), findsNothing);

      sessao.controle.add(_usuaria);
      await tester.pumpAndSettle();

      expect(find.byType(AcervoTabsPage), findsOneWidget);
    });

    testWidgets('URL que não é rota do app abre o gate normalmente', (tester) async {
      final (_SessaoControlada sessao, _) = await _abrirPelaUrl(tester, '/nao-existe');

      sessao.controle.add(_usuaria);
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Com o app aberto, colar um link ou editar o hash não recarrega a página:
    // o engine empurra o nome sem argumentos (`pushRoute`).
    testWidgets('link colado com o app aberto abre o título da URL', (tester) async {
      final (_SessaoControlada sessao, _FakeTituloRepository titulos) =
          await _abrirPelaUrl(tester, '/');
      sessao.controle.add(_usuaria);
      await tester.pumpAndSettle();

      await tester.binding.handlePushRoute('/detalhe?tipo=tv&id=1399');
      await tester.pumpAndSettle();

      expect(titulos.pedidos, <String>['tv:1399']);
      expect(find.text('Game of Thrones'), findsWidgets);
    });

    testWidgets('link colado sem sessão não passa por cima do login', (tester) async {
      final (_SessaoControlada sessao, _) = await _abrirPelaUrl(tester, '/');
      sessao.controle.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      await tester.binding.handlePushRoute(Routes.acervo);
      await tester.pumpAndSettle();

      expect(find.byType(AcervoTabsPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('sessão que cai com o detalhe aberto por toque volta para o login', (tester) async {
      final (_SessaoControlada sessao, _) = await _abrirPelaUrl(tester, '/');
      sessao.controle.add(_usuaria);
      await tester.pumpAndSettle();
      unawaited(Routes.abrirDetalhe(
        tester.element(find.byType(HomePage)),
        const TituloRef(tipo: TipoMidia.tv, id: 1399),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(TitleDetailPage), findsOneWidget);

      // O 401 que faz o interceptor deslogar chega aqui como sessão vazia.
      sessao.controle.add(null);
      await tester.pumpAndSettle();

      expect(find.byType(TitleDetailPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('dentro do app, abrir o detalhe põe o par no nome da rota', (tester) async {
      final (_SessaoControlada sessao, _FakeTituloRepository titulos) =
          await _abrirPelaUrl(tester, '/');
      sessao.controle.add(_usuaria);
      await tester.pumpAndSettle();

      unawaited(Routes.abrirDetalhe(
        tester.element(find.byType(HomePage)),
        const TituloRef(tipo: TipoMidia.movie, id: 550),
      ));
      await tester.pumpAndSettle();

      final BuildContext pagina = tester.element(find.byType(TitleDetailPage));
      expect(ModalRoute.of(pagina)!.settings.name, '/detalhe?tipo=movie&id=550');
      expect(titulos.pedidos, <String>['movie:550']);
    });
  });
}
