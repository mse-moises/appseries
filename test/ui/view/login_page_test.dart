import 'dart:async';

import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/ui/view/login_page.dart';
import 'package:appseries/ui/view_model/auth_view_model.dart';
import 'package:appseries/ui/view_model/login_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository([this._resposta = const Result<AppUser>.ok(_livia)]);

  final Result<AppUser> _resposta;
  final StreamController<AppUser?> _sessao = StreamController<AppUser?>.broadcast();
  int entradas = 0;
  int criadas = 0;
  int comGoogle = 0;

  /// Se não-nulo, o `signIn` pendura até alguém completar (deixa `isSubmitting` em voo).
  Completer<Result<AppUser>>? portaDoLogin;

  /// O mesmo, para o caminho do Google.
  Completer<Result<AppUser>>? portaDoGoogle;

  @override
  Stream<AppUser?> get sessionStream => _sessao.stream;

  /// Sincrono: em `testWidgets` o relogio e falso.
  void emitir(AppUser? user) => _sessao.add(user);

  @override
  Future<Result<AppUser>> signIn(String email, String password) async {
    entradas++;
    if (portaDoLogin != null) return portaDoLogin!.future;
    return _resposta;
  }

  @override
  Future<Result<AppUser>> signUp(String email, String password) async {
    criadas++;
    return _resposta;
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    comGoogle++;
    if (portaDoGoogle != null) return portaDoGoogle!.future;
    return _resposta;
  }

  @override
  Future<Result<void>> signOut() async => const Result<void>.ok(null);
}

Future<_FakeAuthRepository> _montar(
  WidgetTester tester, [
  Result<AppUser>? resposta,
  _FakeAuthRepository? repo,
]) async {
  final _FakeAuthRepository repoFinal =
      repo ?? _FakeAuthRepository(resposta ?? const Result<AppUser>.ok(_livia));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LoginViewModel>(create: (_) => LoginViewModel(repoFinal)),
        // A tela mostra o aviso de sessão expirada, que mora no estado da sessão.
        ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel(repoFinal)),
      ],
      child: const MaterialApp(home: LoginPage()),
    ),
  );
  return repoFinal;
}

Future<void> _preencher(
  WidgetTester tester, {
  String email = 'livia@exemplo.com',
  String password = 'segredo123',
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), password);
}

void main() {
  group('LoginPage', () {
    testWidgets('a senha tem olhinho para revelar e esconder', (tester) async {
      await _montar(tester);

      EditableText password() => tester.widget<EditableText>(
            find.descendant(
              of: find.widgetWithText(TextFormField, 'Senha'),
              matching: find.byType(EditableText),
            ),
          );
      expect(password().obscureText, isTrue, reason: 'começa escondida');

      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();
      expect(password().obscureText, isFalse, reason: 'revelou');

      await tester.tap(find.byTooltip('Esconder senha'));
      await tester.pump();
      expect(password().obscureText, isTrue, reason: 'escondeu de novo');
    });

    testWidgets('o olhinho desliga enquanto o login está em voo', (tester) async {
      final repo = _FakeAuthRepository()..portaDoLogin = Completer<Result<AppUser>>();
      await _montar(tester, null, repo);

      await _preencher(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      // O campo e os botões congelam durante o envio, e o olhinho tem que ir junto
      // (o suffixIcon não herda o `enabled` do campo).
      final IconButton olhinho =
          tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.visibility));
      expect(olhinho.onPressed, isNull, reason: 'não pode ser tocável durante o envio');

      repo.portaDoLogin!.complete(const Result<AppUser>.ok(_livia));
      await tester.pump();
    });

    testWidgets('mostra os campos, o botão e o título', (tester) async {
      await _montar(tester);

      expect(find.text('AppSeries'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Senha'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Entrar com Google'), findsOneWidget);
    });

    testWidgets('o botão do Google entra sem passar pela validação dos campos', (tester) async {
      final repo = await _montar(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Entrar com Google'));
      await tester.pump();

      // Nada preenchido e o caminho do Google tem de sair assim mesmo: a
      // validação do formulário é do login por e-mail.
      expect(repo.comGoogle, 1);
      expect(repo.entradas, 0);
      expect(find.text('Informe o e-mail'), findsNothing);
    });

    testWidgets('o progresso aparece no botão que ela apertou', (tester) async {
      final repo = _FakeAuthRepository()..portaDoGoogle = Completer<Result<AppUser>>();
      await _montar(tester, null, repo);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Entrar com Google'));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'o progresso é do botão do Google',
      );
      expect(
        find.widgetWithText(FilledButton, 'Entrar'),
        findsOneWidget,
        reason: 'o botão de e-mail não pode virar spinner',
      );

      repo.portaDoGoogle!.complete(const Result<AppUser>.ok(_livia));
      await tester.pump();
    });

    testWidgets('"esse e-mail já tem conta com senha" devolve a tela ao modo entrar', (tester) async {
      await _montar(tester, const Result<AppUser>.error(ContaDeOutroMetodoError()));

      await tester.tap(find.widgetWithText(TextButton, 'Ainda não tenho conta'));
      await tester.pump();
      expect(find.widgetWithText(FilledButton, 'Criar conta'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Entrar com Google'));
      await tester.pump();

      expect(find.text('Esse e-mail já tem conta com senha. Entre com a sua senha.'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Entrar'),
        findsOneWidget,
        reason: 'a frase manda entrar com a senha: o botão tem de dizer isso',
      );
    });

    testWidgets('campos vazios não chamam o repositório', (tester) async {
      final repo = await _montar(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(repo.entradas, 0);
      expect(find.text('Informe o e-mail'), findsOneWidget);
    });

    testWidgets('e-mail sem arroba é recusado na tela', (tester) async {
      final repo = await _montar(tester);

      await _preencher(tester, email: 'livia.exemplo.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(repo.entradas, 0);
      expect(find.text('Confira o e-mail digitado'), findsOneWidget);
    });

    testWidgets('senha curta é recusada antes de sair do app', (tester) async {
      final repo = await _montar(tester);

      await _preencher(tester, password: '123');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(repo.entradas, 0);
      expect(find.textContaining('6 caracteres'), findsOneWidget);
    });

    testWidgets('e-mail e senha válidos chamam o login', (tester) async {
      final repo = await _montar(tester);

      await _preencher(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(repo.entradas, 1);
    });

    testWidgets('o erro do campo sai quando ela corrige, sem tocar de novo', (tester) async {
      await _montar(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();
      expect(find.text('Informe o e-mail'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'livia@exemplo.com',
      );
      await tester.pump();

      expect(find.text('Informe o e-mail'), findsNothing);
    });

    testWidgets('"esse e-mail já tem conta" devolve a tela ao modo entrar', (tester) async {
      await _montar(tester, const Result<AppUser>.error(EmailJaEmUsoError()));

      await tester.tap(find.widgetWithText(TextButton, 'Ainda não tenho conta'));
      await tester.pump();
      expect(find.widgetWithText(FilledButton, 'Criar conta'), findsOneWidget);

      await _preencher(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await tester.pump();

      expect(find.text('Esse e-mail já tem conta. Tente entrar.'), findsOneWidget);
      // A frase é uma instrução: o botão embaixo dela tem que ser o que ela manda.
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Criar conta'), findsNothing);
    });

    testWidgets('a tela explica a sessão que acabou sozinha', (tester) async {
      final repo = await _montar(tester);

      repo.emitir(_livia);
      await tester.pump();
      await tester.pump();
      repo.emitir(null);
      await tester.pump();
      await tester.pump();

      expect(find.text('Sua sessão expirou. Entre de novo.'), findsOneWidget);
    });

    testWidgets('erro do Firebase aparece com a frase pronta', (tester) async {
      await _montar(tester, const Result<AppUser>.error(CredenciaisInvalidasError()));

      await _preencher(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(find.text('E-mail ou senha incorretos. Confira e tente de novo.'), findsOneWidget);
    });

    testWidgets('digitar de novo limpa o erro antigo', (tester) async {
      await _montar(tester, const Result<AppUser>.error(CredenciaisInvalidasError()));
      await _preencher(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();
      expect(find.textContaining('incorretos'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'outrasenha');
      await tester.pump();

      expect(find.textContaining('incorretos'), findsNothing);
    });

    testWidgets('alterna para criar conta e chama o cadastro', (tester) async {
      final repo = await _montar(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Ainda não tenho conta'));
      await tester.pump();
      await _preencher(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await tester.pump();

      expect(repo.criadas, 1);
      expect(repo.entradas, 0);
    });
  });
}
