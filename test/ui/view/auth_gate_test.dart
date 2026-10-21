import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/data/repositories/health_repository.dart';
import 'package:appseries/ui/view/auth_gate.dart';
import 'package:appseries/ui/view/home_page.dart';
import 'package:appseries/ui/view/login_page.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/ui/view_model/auth_view_model.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/ui/view_model/login_view_model.dart';
import 'package:appseries/ui/widgets/status_view.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

class _FakeAuthRepository implements AuthRepository {
  final StreamController<AppUser?> _sessao = StreamController<AppUser?>.broadcast();
  int saidas = 0;

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
    return const Result<void>.ok(null);
  }

  /// Sincrono de proposito: em `testWidgets` o relogio e falso, entao quem
  /// entrega o evento e o `await tester.pump()` do teste.
  void emitir(AppUser? user) => _sessao.add(user);
}

class _FakeAcervoRepository implements AcervoRepository {
  @override
  Future<Result<List<AcervoItem>>> listar() async =>
      const Result<List<AcervoItem>>.ok(<AcervoItem>[]);
}

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<Result<HealthStatus>> check() async =>
      const Result<HealthStatus>.ok(HealthStatus(status: 'ok'));
}

Widget _tela(AuthRepository auth) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel(auth),
        ),
        ChangeNotifierProvider<LoginViewModel>(
          create: (_) => LoginViewModel(auth),
        ),
        ChangeNotifierProvider<HomeViewModel>(
          // Sem `..load()`: quem carrega é a `HomePage` (igual ao `main.dart`).
          create: (_) => HomeViewModel(_FakeHealthRepository()),
        ),
        ChangeNotifierProvider<AcervoViewModel>(
          create: (_) => AcervoViewModel(_FakeAcervoRepository()),
        ),
      ],
      child: const MaterialApp(home: AuthGate()),
    );

void main() {
  group('AuthGate', () {
    testWidgets('enquanto não sabe quem está logado, mostra o carregando', (tester) async {
      await tester.pumpWidget(_tela(_FakeAuthRepository()));
      await tester.pump();

      expect(find.byType(LoadingView), findsOneWidget);
      // The sentence is part of what the wave fixed: it used to promise a sign-in
      // that was not happening. Without an assert, any text passes green.
      expect(find.text('Só um instante...'), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets('sem sessão, mostra o login', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_tela(repo));

      repo.emitir(null);
      await tester.pump();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets('com sessão, mostra a home', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_tela(repo));

      repo.emitir(_livia);
      await tester.pump();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('sair da conta troca a home pelo login', (tester) async {
      final repo = _FakeAuthRepository();
      await tester.pumpWidget(_tela(repo));
      repo.emitir(_livia);
      await tester.pump();
      expect(find.byType(HomePage), findsOneWidget);

      repo.emitir(null);
      await tester.pump();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });
  });
}
