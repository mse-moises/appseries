import 'dart:async';

import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/data/repositories/health_repository.dart';
import 'package:appseries/ui/view/home_page.dart';
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
      ],
      child: const MaterialApp(home: HomePage()),
    ),
  );
  // Sem `pumpAndSettle`: o `LoadingView` anima um `CircularProgressIndicator`, que
  // nunca "assenta" — o spinner infinito trava quem usar pumpAndSettle aqui.
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  group('HomePage', () {
    testWidgets('mostra o estado do backend', (tester) async {
      await _montar(tester);

      expect(find.text('Backend respondeu: ok'), findsOneWidget);
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
