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
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

Result<List<TmdbItem>> _lista(List<int> ids) =>
    Result<List<TmdbItem>>.ok(<TmdbItem>[for (final int id in ids) _titulo(id)]);

class _FakeAcervoRepository implements AcervoRepository {
  @override
  Future<Result<List<AcervoItem>>> listar() async =>
      const Result<List<AcervoItem>>.ok(<AcervoItem>[]);
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
      child: const MaterialApp(home: HomePage()),
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

    testWidgets('mostra a atribuição do TMDB', (tester) async {
      await _montar(tester);

      expect(find.textContaining('TMDB API'), findsOneWidget);
    });

    testWidgets('conta sem nada no acervo mostra 0', (tester) async {
      await _montar(tester);

      expect(find.text('Seu acervo: 0 títulos'), findsOneWidget);
    });

    testWidgets('carrossel que falha não derruba o outro', (tester) async {
      await _montar(
        tester,
        titulos: _FakeTituloRepository(
          respostaEmAlta: const Result<List<TmdbItem>>.error(NetworkError()),
          respostaPopulares: _lista(<int>[3]),
        ),
      );

      expect(find.text('Em alta'), findsOneWidget);
      expect(
        find.text('Sem conexão com a internet. Confira sua rede e tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('Título 3'), findsOneWidget);
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

    testWidgets('no primeiro frame após o login não mostra os títulos da conta anterior',
        (tester) async {
      final HomeViewModel anterior = HomeViewModel(
        _FakeTituloRepository(
          respostaEmAlta: _lista(<int>[7, 8]),
          respostaPopulares: _lista(<int>[9]),
        ),
      );
      await anterior.load();
      expect(anterior.emAlta.itens, hasLength(2));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HomeViewModel>.value(value: anterior),
            ChangeNotifierProvider<AuthViewModel>(
              create: (_) => AuthViewModel(_FakeAuthRepository()),
            ),
            ChangeNotifierProvider<AcervoViewModel>(
              create: (_) => AcervoViewModel(_FakeAcervoRepository()),
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      expect(
        find.text('Título 7'),
        findsNothing,
        reason: 'o ViewModel sobrevive ao logout: o frame 1 não pode desenhar o dado anterior',
      );
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
