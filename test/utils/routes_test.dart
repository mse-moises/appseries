import 'package:appseries/app.dart';
import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/data/repositories/feedback_repository.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/ui/view/acervo_tabs_page.dart';
import 'package:appseries/ui/view/search_page.dart';
import 'package:appseries/ui/view/title_detail_page.dart';
import 'package:appseries/ui/view/preferences_page.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/ui/view_model/auth_view_model.dart';
import 'package:appseries/ui/view_model/login_view_model.dart';
import 'package:appseries/ui/view_model/search_view_model.dart';
import 'package:appseries/ui/view_model/title_detail_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

  @override
  Future<Result<List<TmdbItem>>> emAlta() => throw UnimplementedError();

  @override
  Future<Result<List<TmdbItem>>> populares() => throw UnimplementedError();

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

final _FakeTituloRepository _titulos = _FakeTituloRepository();

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
    test('as quatro rotas internas estão registradas', () {
      expect(
        Routes.mapa.keys,
        containsAll(<String>[Routes.busca, Routes.detalhe, Routes.acervo, Routes.preferencias]),
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
        ],
        child: const App(),
      ));
      await tester.pump();

      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        app.routes!.keys,
        containsAll(<String>[Routes.busca, Routes.detalhe, Routes.acervo, Routes.preferencias]),
        reason: 'sem `routes:` no App, nenhuma tela interna é alcançável',
      );
    });

    testWidgets('cada rota abre a sua tela', (tester) async {
      final Map<String, Type> esperado = <String, Type>{
        Routes.busca: SearchPage,
        Routes.acervo: AcervoTabsPage,
        Routes.preferencias: PreferencesPage,
      };

      for (final MapEntry<String, Type> e in esperado.entries) {
        await _empurrar(tester, e.key);
        expect(find.byType(e.value), findsOneWidget, reason: 'rota ${e.key}');
      }
      expect(_titulos.buscas, 0, reason: 'abrir a busca não pode chamar o servidor');
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
}
