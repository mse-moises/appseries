import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/preferencias.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/view/auth_gate.dart';
import 'package:appseries/ui/view/home_page.dart';
import 'package:appseries/ui/view/preferences_page.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/ui/view_model/auth_view_model.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/ui/view_model/login_view_model.dart';
import 'package:appseries/ui/view_model/preferences_view_model.dart';
import 'package:appseries/utils/result.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/fake_preferencias.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

class _FakeAuth implements AuthRepository {
  final StreamController<AppUser?> sessao = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> get sessionStream => sessao.stream;

  @override
  Future<Result<AppUser>> signIn(String email, String password) => throw UnimplementedError();

  @override
  Future<Result<AppUser>> signUp(String email, String password) => throw UnimplementedError();

  @override
  Future<Result<AppUser>> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<Result<void>> signOut() async {
    sessao.add(null);
    return const Result<void>.ok(null);
  }
}

class _FakeTitulos implements TituloRepository {
  int emAltaPedidos = 0;

  @override
  Future<Result<List<TmdbItem>>> emAlta() async {
    emAltaPedidos++;
    return const Result<List<TmdbItem>>.ok(<TmdbItem>[]);
  }

  @override
  Future<Result<List<TmdbItem>>> populares() async =>
      const Result<List<TmdbItem>>.ok(<TmdbItem>[]);

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) => throw UnimplementedError();

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
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

class _Cenario {
  final _FakeAuth auth = _FakeAuth();
  final _FakeTitulos titulos = _FakeTitulos();
  final FakePreferenciasRepository preferencias = FakePreferenciasRepository();
  final FakePrimeiroAcessoRepository marca = FakePrimeiroAcessoRepository();

  Future<void> abrirLogada(WidgetTester tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel(auth)),
        ChangeNotifierProvider<LoginViewModel>(create: (_) => LoginViewModel(auth)),
        ChangeNotifierProvider<HomeViewModel>(create: (_) => HomeViewModel(titulos)),
        ChangeNotifierProvider<AcervoViewModel>(create: (_) => AcervoViewModel(_FakeAcervo())),
        ChangeNotifierProvider<PreferencesViewModel>(
          create: (_) => PreferencesViewModel(preferencias, marca),
        ),
      ],
      child: MaterialApp(home: const AuthGate(), routes: Routes.mapa),
    ));
    auth.sessao.add(_livia);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Preferências no primeiro acesso (AP-38)', () {
    testWidgets('conta nova vê os chips, sem voltar e com Pular', (tester) async {
      final _Cenario c = _Cenario();
      await c.abrirLogada(tester);

      expect(find.byType(PreferencesPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(find.byKey(const Key('preferencias-pular')), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      for (final String genero in kGenerosTmdb.take(3)) {
        expect(find.text(genero), findsOneWidget);
      }
    });

    testWidgets('escolher 3 chips e continuar salva no perfil e abre a home', (tester) async {
      final _Cenario c = _Cenario();
      await c.abrirLogada(tester);

      expect(
        tester.widget<FilledButton>(find.byKey(const Key('preferencias-salvar'))).onPressed,
        isNull,
        reason: 'sem nenhum chip não há o que salvar',
      );
      for (final String g in <String>['Drama', 'Comédia', 'Terror']) {
        await tester.tap(find.byKey(ValueKey<String>('genero-$g')));
        await tester.pump();
      }
      expect(find.text('3 gêneros escolhidos.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('preferencias-salvar')));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(c.preferencias.atual.generos, <String>['Comédia', 'Drama', 'Terror']);
    });

    testWidgets('pular leva para a home com o em alta carregado', (tester) async {
      final _Cenario c = _Cenario();
      await c.abrirLogada(tester);

      await tester.tap(find.byKey(const Key('preferencias-pular')));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Em alta'), findsOneWidget);
      expect(c.titulos.emAltaPedidos, 1, reason: 'a home carrega o em alta, não fica vazia');
      expect(c.preferencias.atual.generos, isEmpty, reason: 'pular não grava nada no servidor');
      expect(c.marca.marcados, contains('u1'));
    });

    testWidgets('depois de pular, o próximo login vai direto para a home', (tester) async {
      final _Cenario c = _Cenario();
      await c.abrirLogada(tester);
      await tester.tap(find.byKey(const Key('preferencias-pular')));
      await tester.pumpAndSettle();

      c.auth.sessao.add(null);
      await tester.pumpAndSettle();
      c.auth.sessao.add(_livia);
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(PreferencesPage), findsNothing);
    });

    testWidgets('voltar pela home mostra os chips marcados, vindos do GET', (tester) async {
      final _Cenario c = _Cenario();
      c.marca.marcados.add('u1');
      c.preferencias.atual = const Preferencias(
        momento: 'algo leve',
        generos: <String>['Drama', 'Comédia', 'Terror'],
      );
      await c.abrirLogada(tester);
      final int leiturasAntes = c.preferencias.leituras;

      await tester.tap(find.byKey(const Key('abrir-preferencias')));
      await tester.pumpAndSettle();

      expect(c.preferencias.leituras, leiturasAntes + 1, reason: 'a tela lê o que está salvo');
      for (final String g in <String>['Drama', 'Comédia', 'Terror']) {
        expect(
          tester.widget<FilterChip>(find.byKey(ValueKey<String>('genero-$g'))).selected,
          isTrue,
          reason: g,
        );
      }
      expect(tester.widget<FilterChip>(find.byKey(const ValueKey<String>('genero-Ação'))).selected,
          isFalse);

      await tester.tap(find.byKey(const ValueKey<String>('genero-Ação')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('preferencias-salvar')));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget, reason: 'salvar fecha a tela');
      expect(c.preferencias.atual.momento, 'algo leve', reason: 'o PUT não apaga o momento');
      expect(c.preferencias.atual.generos, contains('Ação'));
    });
  });
}
