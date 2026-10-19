import 'dart:async';

import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/ui/view_model/login_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

/// Dublê do contrato: o ViewModel nunca depende da implementação de verdade.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._resposta);

  final Result<AppUser> _resposta;
  int criadas = 0;

  @override
  Stream<AppUser?> get sessionStream => const Stream<AppUser?>.empty();

  @override
  Future<Result<AppUser>> signIn(String email, String password) async => _resposta;

  @override
  Future<Result<AppUser>> signUp(String email, String password) async {
    criadas++;
    return _resposta;
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() async => _resposta;

  @override
  Future<Result<void>> signOut() async => const Result<void>.ok(null);
}

/// Segura a resposta numa porta: é o que permite olhar o estado em voo.
class _FakeAuthRepositoryComPorta implements AuthRepository {
  _FakeAuthRepositoryComPorta(this.porta);

  final Completer<Result<AppUser>> porta;
  int chamadas = 0;

  @override
  Stream<AppUser?> get sessionStream => const Stream<AppUser?>.empty();

  @override
  Future<Result<AppUser>> signIn(String email, String password) {
    chamadas++;
    return porta.future;
  }

  @override
  Future<Result<AppUser>> signUp(String email, String password) {
    chamadas++;
    return porta.future;
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() {
    chamadas++;
    return porta.future;
  }

  @override
  Future<Result<void>> signOut() async => const Result<void>.ok(null);
}

/// Repositório que fura o contrato: lança em vez de devolver `Result`.
///
/// O que ele lança é escolhido pelo teste: `Exception` e `Error` têm destinos
/// diferentes no ViewModel (frase na tela vs. deixar subir).
class _FakeAuthRepositoryQueLanca implements AuthRepository {
  _FakeAuthRepositoryQueLanca([this.error = const FormatException('contrato furado')]);

  final Object error;
  int chamadas = 0;

  @override
  Stream<AppUser?> get sessionStream => const Stream<AppUser?>.empty();

  @override
  Future<Result<AppUser>> signIn(String email, String password) async {
    chamadas++;
    throw error;
  }

  @override
  Future<Result<AppUser>> signUp(String email, String password) async {
    chamadas++;
    throw error;
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    chamadas++;
    throw error;
  }

  @override
  Future<Result<void>> signOut() async => const Result<void>.ok(null);
}

void main() {
  group('LoginViewModel', () {
    test('começa sem erro e sem requisição em voo', () {
      final vm = LoginViewModel(_FakeAuthRepository(const Result<AppUser>.ok(_livia)));

      expect(vm.isSubmitting, isFalse);
      expect(vm.error, isNull);
    });

    test('erro tipado vira a frase pronta da tela', () async {
      final vm = LoginViewModel(
        _FakeAuthRepository(const Result<AppUser>.error(CredenciaisInvalidasError())),
      );

      await vm.signIn('livia@exemplo.com', 'errada');

      expect(vm.isSubmitting, isFalse);
      expect(vm.error, 'E-mail ou senha incorretos. Confira e tente de novo.');
    });

    test('entrar com sucesso não deixa mensagem de erro', () async {
      final vm = LoginViewModel(_FakeAuthRepository(const Result<AppUser>.ok(_livia)));

      await vm.signIn('livia@exemplo.com', 'segredo123');

      expect(vm.error, isNull);
    });

    test('entrar com Google passa pelo mesmo caminho do login', () async {
      final porta = Completer<Result<AppUser>>();
      final vm = LoginViewModel(_FakeAuthRepositoryComPorta(porta));

      final Future<void> emVoo = vm.signInWithGoogle();
      expect(vm.isSubmitting, isTrue, reason: 'a tela tem de congelar durante o fluxo do Google');

      porta.complete(const Result<AppUser>.ok(_livia));
      await emVoo;

      expect(vm.isSubmitting, isFalse);
      expect(vm.error, isNull);
    });

    test('o estado de envio sabe qual botão foi apertado', () async {
      final portaGoogle = Completer<Result<AppUser>>();
      final vmGoogle = LoginViewModel(_FakeAuthRepositoryComPorta(portaGoogle));

      final Future<void> peloGoogle = vmGoogle.signInWithGoogle();
      expect(vmGoogle.isGoogleInFlight, isTrue);
      expect(vmGoogle.isEmailInFlight, isFalse, reason: 'o spinner é do botão do Google');

      portaGoogle.complete(const Result<AppUser>.ok(_livia));
      await peloGoogle;
      expect(vmGoogle.isGoogleInFlight, isFalse);

      final portaEmail = Completer<Result<AppUser>>();
      final vmEmail = LoginViewModel(_FakeAuthRepositoryComPorta(portaEmail));

      final Future<void> peloEmail = vmEmail.signIn('livia@exemplo.com', 'segredo123');
      expect(vmEmail.isEmailInFlight, isTrue);
      expect(vmEmail.isGoogleInFlight, isFalse);

      portaEmail.complete(const Result<AppUser>.ok(_livia));
      await peloEmail;
    });

    test('falha do Google vira frase na tela', () async {
      final vm = LoginViewModel(
        _FakeAuthRepository(const Result<AppUser>.error(ServerError())),
      );

      await vm.signInWithGoogle();

      expect(vm.error, isNotNull);
      expect(vm.isSubmitting, isFalse);
    });

    test('avisa a View no começo e no fim da requisição', () async {
      final vm = LoginViewModel(_FakeAuthRepository(const Result<AppUser>.ok(_livia)));
      int avisos = 0;
      vm.addListener(() => avisos++);

      await vm.signIn('livia@exemplo.com', 'segredo123');

      expect(avisos, 2);
    });

    test('enquanto a requisição está em voo, o estado é entrando', () async {
      final porta = Completer<Result<AppUser>>();
      final vm = LoginViewModel(_FakeAuthRepositoryComPorta(porta));

      final Future<void> emVoo = vm.signIn('livia@exemplo.com', 'segredo123');

      expect(vm.isSubmitting, isTrue);

      porta.complete(const Result<AppUser>.ok(_livia));
      await emVoo;

      expect(vm.isSubmitting, isFalse);
      expect(vm.error, isNull);
    });

    test('toque duplo em Entrar não dispara dois pedidos', () async {
      final porta = Completer<Result<AppUser>>();
      final repo = _FakeAuthRepositoryComPorta(porta);
      final vm = LoginViewModel(repo);

      final Future<void> primeiro = vm.signIn('livia@exemplo.com', 'segredo123');
      final Future<void> segundo = vm.signIn('livia@exemplo.com', 'segredo123');

      expect(repo.chamadas, 1, reason: 'o segundo toque não devia sair para o Firebase');

      porta.complete(const Result<AppUser>.ok(_livia));
      await primeiro;
      await segundo;

      expect(vm.isSubmitting, isFalse);
      expect(vm.error, isNull);
    });

    test('repositório que lança Exception não deixa a tela presa em entrando', () async {
      final repo = _FakeAuthRepositoryQueLanca();
      final vm = LoginViewModel(repo);

      await vm.signIn('livia@exemplo.com', 'segredo123');

      expect(vm.isSubmitting, isFalse, reason: 'a guarda não pode prender a tela');
      expect(vm.error, 'O servidor deu uma escorregada. Tente em instantes.');

      // O ponto do conserto: a tentativa seguinte continua podendo sair.
      await vm.signIn('livia@exemplo.com', 'segredo123');

      expect(repo.chamadas, 2);
    });

    test('bug de programação sobe, mas ainda libera a tela', () async {
      final repo = _FakeAuthRepositoryQueLanca(StateError('bug daqui'));
      final vm = LoginViewModel(repo);

      await expectLater(
        vm.signIn('livia@exemplo.com', 'segredo123'),
        throwsStateError,
      );

      // `Error` não vira frase de servidor (a culpa não é do servidor), e o
      // `finally` limpa o estado do mesmo jeito: a tela não fica presa.
      expect(vm.isSubmitting, isFalse);
      expect(vm.error, isNull);

      // A mesma condição que o guard lê: a tentativa seguinte tem que sair.
      await expectLater(
        vm.signIn('livia@exemplo.com', 'segredo123'),
        throwsStateError,
      );
      expect(repo.chamadas, 2);
    });

    test('toque duplo em Criar conta também não dispara dois pedidos', () async {
      final porta = Completer<Result<AppUser>>();
      final repo = _FakeAuthRepositoryComPorta(porta);
      final vm = LoginViewModel(repo);

      final Future<void> primeiro = vm.signUp('livia@exemplo.com', 'segredo123');
      final Future<void> segundo = vm.signUp('livia@exemplo.com', 'segredo123');

      expect(repo.chamadas, 1, reason: 'o segundo toque não devia sair para o Firebase');

      porta.complete(const Result<AppUser>.ok(_livia));
      await primeiro;
      await segundo;

      expect(vm.isSubmitting, isFalse);
      expect(vm.error, isNull);
    });

    test('cadastro passa pelo mesmo caminho do login', () async {
      final repo = _FakeAuthRepository(const Result<AppUser>.ok(_livia));
      final vm = LoginViewModel(repo);

      await vm.signUp('livia@exemplo.com', 'segredo123');

      expect(repo.criadas, 1);
      expect(vm.error, isNull);
    });

    test('limparErro só notifica quando havia erro', () async {
      final vm = LoginViewModel(
        _FakeAuthRepository(const Result<AppUser>.error(NetworkError())),
      );
      await vm.signIn('livia@exemplo.com', 'segredo123');

      int avisos = 0;
      vm.addListener(() => avisos++);
      vm.clearError();

      expect(vm.error, isNull);
      expect(avisos, 1);
    });

    test('limparErro sem erro nenhum não notifica ninguém', () {
      final vm = LoginViewModel(_FakeAuthRepository(const Result<AppUser>.ok(_livia)));
      int avisos = 0;
      vm.addListener(() => avisos++);

      vm.clearError();

      expect(vm.error, isNull);
      expect(avisos, 0);
    });
  });
}
