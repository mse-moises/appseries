import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/data/repositories/health_repository.dart';
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

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<Result<HealthStatus>> check() async =>
      const Result<HealthStatus>.ok(HealthStatus(status: 'ok'));
}

class _ContadorHealthRepository implements HealthRepository {
  int chamadas = 0;

  @override
  Future<Result<HealthStatus>> check() async {
    chamadas++;
    return const Result<HealthStatus>.ok(HealthStatus(status: 'ok'));
  }
}

class _FakeAcervoRepository implements AcervoRepository {
  _FakeAcervoRepository([this.itens = const <AcervoItem>[]]);

  final List<AcervoItem> itens;

  @override
  Future<Result<List<AcervoItem>>> listar() async => Result<List<AcervoItem>>.ok(itens);
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

  /// Sincrono: em `testWidgets` o relogio e falso (ver `auth_gate_test.dart`).
  void emitir(AppUser? user) => _sessao.add(user);
}

Future<_FakeAuthRepository> _montar(
  WidgetTester tester, {
  _FakeAuthRepository? auth,
  HealthRepository? health,
  AcervoRepository? acervo,
}) async {
  final _FakeAuthRepository repo = auth ?? _FakeAuthRepository();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        // Sem `..load()`: quem carrega é a própria `HomePage`, e é isso que faz a
        // segunda conta não abrir com a resposta da primeira.
        ChangeNotifierProvider<HomeViewModel>(
          create: (_) => HomeViewModel(health ?? _FakeHealthRepository()),
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
  // Sem `pumpAndSettle`: o `LoadingView` anima um `CircularProgressIndicator`, que
  // nunca "assenta" — o spinner infinito trava quem usar pumpAndSettle aqui.
  await tester.pump();
  await tester.pump();
  // The shelf loads in parallel with the health call; one more frame lets its
  // notifyListeners land before the test reads the screen.
  await tester.pump();
  return repo;
}

void main() {
  group('HomePage', () {
    testWidgets('mostra o estado do backend', (tester) async {
      await _montar(tester);

      expect(find.text('Backend respondeu: ok'), findsOneWidget);
    });

    testWidgets('mostra quantos títulos tem o acervo', (tester) async {
      await _montar(
        tester,
        acervo: _FakeAcervoRepository(<AcervoItem>[
          const AcervoItem(tmdbId: 1399, estado: EstadoAcervo.watching, tipo: TipoMidia.tv),
          const AcervoItem(tmdbId: 550, estado: EstadoAcervo.planToWatch, tipo: TipoMidia.movie),
        ]),
      );

      expect(find.text('Seu acervo: 2 títulos'), findsOneWidget);
    });

    testWidgets('conta com um título só usa o singular', (tester) async {
      await _montar(
        tester,
        acervo: _FakeAcervoRepository(<AcervoItem>[
          const AcervoItem(tmdbId: 1399, estado: EstadoAcervo.watched, tipo: TipoMidia.tv),
        ]),
      );

      expect(find.text('Seu acervo: 1 título'), findsOneWidget);
    });

    testWidgets('conta sem nada no acervo mostra 0', (tester) async {
      await _montar(tester);

      expect(find.text('Seu acervo: 0 títulos'), findsOneWidget);
    });

    testWidgets('acervo que falha não derruba a home e o retry recarrega', (tester) async {
      final _FakeAcervoFalhaDepoisOk repo = _FakeAcervoFalhaDepoisOk();

      await _montar(tester, acervo: repo);

      expect(
        find.text('Backend respondeu: ok'),
        findsOneWidget,
        reason: 'o health continua na tela: o acervo é um bloco, não a tela',
      );
      expect(
        find.text('Sem conexão com a internet. Confira sua rede e tente de novo.'),
        findsOneWidget,
      );

      // 'Tentar de novo' também existe no bloco do health: a key é o que diz
      // qual dos dois foi tocado.
      await tester.tap(find.byKey(const Key('acervo-retry')));
      await tester.pump();
      await tester.pump();

      expect(repo.chamadas, 2);
      expect(find.text('Seu acervo: 0 títulos'), findsOneWidget);
    });

    testWidgets('no primeiro frame após o login não mostra a contagem da conta anterior',
        (tester) async {
      final AcervoViewModel anterior = AcervoViewModel(
        _FakeAcervoRepository(<AcervoItem>[
          for (int i = 0; i < 7; i++)
            AcervoItem(tmdbId: i, estado: EstadoAcervo.watched, tipo: TipoMidia.movie),
        ]),
      );
      await anterior.load();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<HomeViewModel>(
              create: (_) => HomeViewModel(_FakeHealthRepository()),
            ),
            ChangeNotifierProvider<AuthViewModel>(
              create: (_) => AuthViewModel(_FakeAuthRepository()),
            ),
            ChangeNotifierProvider<AcervoViewModel>.value(value: anterior),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      expect(
        find.text('Seu acervo: 7 títulos'),
        findsNothing,
        reason: 'o ViewModel sobrevive ao logout: o frame 1 não pode desenhar o dado da conta anterior',
      );
      expect(find.text('Carregando seu acervo...'), findsOneWidget);
    });

    testWidgets('mostra o e-mail de quem está logado', (tester) async {
      final auth = await _montar(tester);

      auth.emitir(_livia);
      await tester.pump();
      await tester.pump();

      expect(find.text('livia@exemplo.com'), findsOneWidget);
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

    testWidgets('sair que falha diz na tela', (tester) async {
      await _montar(tester, auth: _FakeAuthRepository(saidaFalha: true));

      await tester.tap(find.byTooltip('Sair'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('O servidor deu uma escorregada. Tente em instantes.'),
        findsOneWidget,
      );
    });

    testWidgets('a faixa de saída falhada sai quando ela fecha', (tester) async {
      await _montar(tester, auth: _FakeAuthRepository(saidaFalha: true));

      await tester.tap(find.byTooltip('Sair'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('O servidor deu uma escorregada. Tente em instantes.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Fechar'));
      await tester.pump();

      expect(
        find.text('O servidor deu uma escorregada. Tente em instantes.'),
        findsNothing,
      );
    });

    testWidgets('montar de novo recarrega: a 2ª conta não herda a 1ª', (tester) async {
      final health = _ContadorHealthRepository();
      final homeVm = HomeViewModel(health);

      Future<void> montar(WidgetTester tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<HomeViewModel>.value(value: homeVm),
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
        await tester.pump();
        await tester.pump();
      }

      await montar(tester);
      expect(health.chamadas, 1);

      // O logout desmonta a home: sem esta troca o `pumpWidget` só atualizaria a
      // árvore existente e o `initState` não rodaria de novo.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      // Segundo login: tela nova, o MESMO ViewModel (o provider roda uma vez só).
      await montar(tester);

      expect(
        health.chamadas,
        2,
        reason: 'a segunda conta não pode abrir com a resposta da primeira',
      );
    });
  });
}
