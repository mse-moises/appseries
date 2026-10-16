import 'dart:async';

import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/ui/view_model/auth_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

class _FakeAuthRepository implements AuthRepository {
  final StreamController<AppUser?> _sessao = StreamController<AppUser?>.broadcast();
  int saidas = 0;

  /// Resposta do proximo `sair()`; `portaDaSaida` faz ele pendurar ate alguem soltar.
  Result<void> respostaSaida = const Result<void>.ok(null);
  Completer<void>? portaDaSaida;
  /// `null` = sai normalmente; qualquer objeto = o `sair()` LANÇA (contrato furado).
  Object? erroAoSair;

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
    if (erroAoSair != null) throw erroAoSair!;
    if (portaDaSaida != null) await portaDaSaida!.future;
    return respostaSaida;
  }

  Future<void> emitir(AppUser? user) async {
    _sessao.add(user);
    await Future<void>.delayed(Duration.zero);
  }

  void falhar(Object error) => _sessao.addError(error);

  Future<void> fechar() => _sessao.close();
}

void main() {
  group('AuthViewModel', () {
    test('começa em desconhecido, sem chutar quem está logado', () {
      final vm = AuthViewModel(_FakeAuthRepository());

      expect(vm.state, SessionState.unknown);
      expect(vm.user, isNull);
    });

    test('usuário no stream vira estado logado', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);

      await repo.emitir(_livia);

      expect(vm.state, SessionState.signedIn);
      expect(vm.user, _livia);
    });

    test('stream sem usuário vira estado deslogado', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);
      await repo.emitir(_livia);

      await repo.emitir(null);

      expect(vm.state, SessionState.signedOut);
      expect(vm.user, isNull);
    });

    test('avisa a View a cada mudança de sessão', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);
      int avisos = 0;
      vm.addListener(() => avisos++);

      await repo.emitir(_livia);
      await repo.emitir(null);

      expect(avisos, 2);
    });

    test('canal de sessão com erro também cai no login', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);

      repo.falhar(StateError('canal caiu'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.state, SessionState.signedOut);
      expect(vm.user, isNull);
    });

    test('o erro do canal de sessão não some sem deixar rastro', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);
      final List<String> logs = <String>[];
      final void Function(String?, {int? wrapWidth}) original = debugPrint;
      debugPrint = (String? mensagem, {int? wrapWidth}) => logs.add(mensagem ?? '');
      addTearDown(() => debugPrint = original);

      repo.falhar(StateError('canal caiu'));
      await Future<void>.delayed(Duration.zero);

      expect(logs.any((String l) => l.contains('canal de sessão')), isTrue);
      expect(vm.state, SessionState.signedOut);
    });

    test('canal de sessão fechado também cai no login', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);

      await repo.fechar();
      await Future<void>.delayed(Duration.zero);

      expect(vm.state, SessionState.signedOut);
    });

    test('sair chama o repository', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);

      await vm.signOut();

      expect(repo.saidas, 1);
    });

    test('sair avisa a tela enquanto está em andamento', () async {
      final repo = _FakeAuthRepository()..portaDaSaida = Completer<void>();
      final vm = AuthViewModel(repo);

      final Future<void> emVoo = vm.signOut();
      expect(vm.isSigningOut, isTrue);

      repo.portaDaSaida!.complete();
      await emVoo;

      expect(vm.isSigningOut, isFalse);
      expect(vm.signOutError, isNull);
    });

    test('sair que falha vira frase, não silêncio', () async {
      final repo = _FakeAuthRepository()
        ..respostaSaida = const Result<void>.error(ServerError());
      final vm = AuthViewModel(repo);

      await vm.signOut();

      expect(vm.signOutError, 'O servidor deu uma escorregada. Tente em instantes.');
      expect(vm.isSigningOut, isFalse);
    });

    test('sair fora do contrato libera o ícone e a tentativa seguinte', () async {
      final repo = _FakeAuthRepository()
        ..erroAoSair = const FormatException('contrato furado');
      final vm = AuthViewModel(repo);

      await vm.signOut();

      expect(vm.isSigningOut, isFalse, reason: 'a espera não pode ficar presa');
      expect(vm.signOutError, 'O servidor deu uma escorregada. Tente em instantes.');

      repo.erroAoSair = null;
      await vm.signOut();

      expect(repo.saidas, 2, reason: 'a guarda não pode prender a saída');
    });

    test('bug de programação no sair sobe, mas libera o estado', () async {
      final repo = _FakeAuthRepository()..erroAoSair = StateError('bug daqui');
      final vm = AuthViewModel(repo);

      await expectLater(vm.signOut(), throwsStateError);

      expect(vm.isSigningOut, isFalse);
    });

    test('a saída que falhou não engole o aviso de um 401 depois', () async {
      final repo = _FakeAuthRepository()
        ..respostaSaida = const Result<void>.error(ServerError());
      final vm = AuthViewModel(repo);
      await repo.emitir(_livia);
      await vm.signOut();
      expect(vm.signOutError, isNotNull);

      // A sessão cai sozinha depois: é o caminho do interceptor.
      await repo.emitir(null);

      expect(vm.notice, 'Sua sessão expirou. Entre de novo.');
    });

    test('evento com o mesmo usuário não apaga o que ela ainda não leu', () async {
      final repo = _FakeAuthRepository()
        ..respostaSaida = const Result<void>.error(ServerError());
      final vm = AuthViewModel(repo);
      await repo.emitir(_livia);
      await vm.signOut();
      expect(vm.signOutError, isNotNull);

      // Um refresh de token emite o mesmo usuário: não é sessão nova.
      await repo.emitir(_livia);

      expect(vm.signOutError, isNotNull);
    });

    test('o motivo da saída antiga morre com a sessão', () async {
      final repo = _FakeAuthRepository()
        ..respostaSaida = const Result<void>.error(ServerError());
      final vm = AuthViewModel(repo);
      await repo.emitir(_livia);
      await vm.signOut();
      expect(vm.signOutError, isNotNull);

      // A sessão caiu por outro caminho e ela entrou de novo.
      await repo.emitir(null);
      await repo.emitir(_livia);

      expect(vm.signOutError, isNull, reason: 'o banner não pode falar da conta anterior');
    });

    test('sessão nova apaga o aviso antigo', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);
      await repo.emitir(_livia);
      await repo.emitir(null);
      expect(vm.notice, isNotNull);

      await repo.emitir(_livia);

      expect(vm.notice, isNull);
    });

    test('sessão que acaba sem ela pedir avisa por quê', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);
      await repo.emitir(_livia);

      // É o caminho do 401: o interceptor desloga e o stream emite sozinho.
      await repo.emitir(null);

      expect(vm.notice, 'Sua sessão expirou. Entre de novo.');
    });

    test('sair pedido por ela não vira aviso de sessão expirada', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);
      await repo.emitir(_livia);

      final Future<void> emVoo = vm.signOut();
      await repo.emitir(null);
      await emVoo;

      expect(vm.notice, isNull);
      expect(vm.state, SessionState.signedOut);
    });

    test('o aviso sai da tela quando ela manda', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);
      await repo.emitir(_livia);
      await repo.emitir(null);

      vm.clearNotice();

      expect(vm.notice, isNull);
    });

    test('depois do dispose a inscrição é cancelada', () async {
      final repo = _FakeAuthRepository();
      final vm = AuthViewModel(repo);
      int avisos = 0;
      vm.addListener(() => avisos++);

      vm.dispose();
      await repo.emitir(_livia);

      expect(avisos, 0);
    });
  });
}
