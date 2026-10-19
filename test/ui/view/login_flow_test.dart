import 'dart:async';

import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/data/repositories/health_repository.dart';
import 'package:appseries/ui/view/auth_gate.dart';
import 'package:appseries/ui/view/home_page.dart';
import 'package:appseries/ui/view/login_page.dart';
import 'package:appseries/ui/view_model/auth_view_model.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/ui/view_model/login_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

/// Dublê que imita o Firebase Auth: signIn/signUp põem o usuário na sessão e
/// signOut tira. É esse acoplamento que faz o AuthGate trocar de tela — sem imitá-lo
/// o teste provaria só que o dublê foi chamado.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.resposta, AppUser? jaLogado}) : _atualEmMemoria = jaLogado;

  /// `null` = sucesso.
  final Result<AppUser>? resposta;
  final StreamController<AppUser?> _mudancas = StreamController<AppUser?>.broadcast();
  AppUser? _atualEmMemoria;
  int saidas = 0;

  @override
  Stream<AppUser?> get sessionStream async* {
    yield _atualEmMemoria; // o Firebase emite o estado atual antes de qualquer mudança
    yield* _mudancas.stream;
  }

  @override
  Future<Result<AppUser>> signIn(String email, String password) => _responder(_livia);

  @override
  Future<Result<AppUser>> signUp(String email, String password) => _responder(_livia);

  @override
  Future<Result<AppUser>> signInWithGoogle() => _responder(_livia);

  @override
  Future<Result<void>> signOut() async {
    saidas++;
    _atualEmMemoria = null;
    _mudancas.add(null);
    return const Result<void>.ok(null);
  }

  Future<Result<AppUser>> _responder(AppUser user) async {
    final Result<AppUser> result = resposta ?? const Result<AppUser>.ok(_livia);
    if (result.isOk) {
      _atualEmMemoria = user;
      _mudancas.add(user);
    }
    return result;
  }
}

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<Result<HealthStatus>> check() async =>
      const Result<HealthStatus>.ok(HealthStatus(status: 'ok'));
}

Future<void> _abrir(WidgetTester tester, AuthRepository auth) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel(auth)),
        ChangeNotifierProvider<LoginViewModel>(create: (_) => LoginViewModel(auth)),
        ChangeNotifierProvider<HomeViewModel>(
          // Sem `..load()`: quem carrega é a `HomePage` (igual ao `main.dart`).
          create: (_) => HomeViewModel(_FakeHealthRepository()),
        ),
      ],
      child: const MaterialApp(home: AuthGate()),
    ),
  );
  await tester.pump(); // o gate recebe o estado atual da sessão
}

Future<void> _preencherEEnviar(WidgetTester tester, {String botao = 'Entrar'}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'livia@exemplo.com');
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'segredo123');
  await tester.tap(find.widgetWithText(FilledButton, botao));
  await tester.pump(); // dispara a requisição
  await tester.pump(); // entrega a mudança de sessão
}

void main() {
  group('fluxo de login, tela a tela', () {
    testWidgets('abrir o app com sessão viva vai direto para a home', (tester) async {
      await _abrir(tester, _FakeAuthRepository(jaLogado: _livia));
      await tester.pump();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('entrar com sucesso leva da tela de login para a home', (tester) async {
      await _abrir(tester, _FakeAuthRepository());
      expect(find.byType(LoginPage), findsOneWidget);

      await _preencherEEnviar(tester);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('entrar com Google leva da tela de login para a home', (tester) async {
      await _abrir(tester, _FakeAuthRepository());
      expect(find.byType(LoginPage), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Entrar com Google'));
      await tester.pump(); // dispara a requisição
      await tester.pump(); // entrega a mudança de sessão

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('criar conta leva para a home pelo mesmo caminho', (tester) async {
      await _abrir(tester, _FakeAuthRepository());

      await tester.tap(find.widgetWithText(TextButton, 'Ainda não tenho conta'));
      await tester.pump();

      await _preencherEEnviar(tester, botao: 'Criar conta');

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('o botão Sair da home volta para o login', (tester) async {
      final auth = _FakeAuthRepository();
      await _abrir(tester, auth);
      await _preencherEEnviar(tester);
      expect(find.byType(HomePage), findsOneWidget);

      await tester.tap(find.byTooltip('Sair'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(auth.saidas, 1);
    });

    testWidgets('login recusado mantém a tela de login com a frase pronta', (tester) async {
      await _abrir(
        tester,
        _FakeAuthRepository(
          resposta: const Result<AppUser>.error(CredenciaisInvalidasError()),
        ),
      );

      await _preencherEEnviar(tester);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      expect(find.text('E-mail ou senha incorretos. Confira e tente de novo.'), findsOneWidget);
    });
  });
}
