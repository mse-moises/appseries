import 'dart:async';

import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/auth_repository_impl.dart';
import 'package:appseries/data/services/auth_service.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

/// Dublê do Service: nenhum teste desta camada toca no Firebase.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.error, this.erroAoNaoSair});

  final Object? error;
  final bool? erroAoNaoSair;
  final StreamController<AppUser?> _sessao = StreamController<AppUser?>.broadcast();
  int saidas = 0;

  @override
  Stream<AppUser?> get sessionStream => _sessao.stream;

  @override
  Future<AppUser> signIn(String email, String password) async {
    if (error != null) throw error!;
    return _livia;
  }

  @override
  Future<AppUser> signUp(String email, String password) async {
    if (error != null) throw error!;
    return _livia;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    if (error != null) throw error!;
    return _livia;
  }

  @override
  Future<void> signOut() async {
    saidas++;
    if (erroAoNaoSair == true) throw FirebaseAuthException(code: 'internal-error');
  }

  @override
  Future<String?> idToken() async => 'token-falso';

  Future<void> emitir(AppUser? user) async {
    _sessao.add(user);
    await Future<void>.delayed(Duration.zero);
  }
}

/// Service que aceita a requisição e nunca responde: é o caso que o tempo
/// limite existe para cobrir.
class _FakeAuthServiceQuePendura implements AuthService {
  final Completer<AppUser> _loginParaSempre = Completer<AppUser>();
  final Completer<void> _saidaParaSempre = Completer<void>();

  @override
  Stream<AppUser?> get sessionStream => const Stream<AppUser?>.empty();

  @override
  Future<AppUser> signIn(String email, String password) => _loginParaSempre.future;

  @override
  Future<AppUser> signUp(String email, String password) => _loginParaSempre.future;

  @override
  Future<AppUser> signInWithGoogle() => _loginParaSempre.future;

  @override
  Future<void> signOut() => _saidaParaSempre.future;

  @override
  Future<String?> idToken() async => null;

  /// Falha o login pendurado DEPOIS do prazo estourar: é a metade que o
  /// comentário do repository promete (o erro tardio é descartado em silêncio).
  void falharTarde(Object error) => _loginParaSempre.completeError(error);
}

void main() {
  group('AuthRepositoryImpl', () {
    test('devolve Ok com o usuário quando o login dá certo', () async {
      final repo = AuthRepositoryImpl(_FakeAuthService());

      final result = await repo.signIn('livia@exemplo.com', 'segredo123');

      expect(result, isA<Ok<AppUser>>());
      expect(result.valueOrNull?.email, 'livia@exemplo.com');
    });

    test('devolve Ok com o usuário quando o login é pelo Google', () async {
      final repo = AuthRepositoryImpl(_FakeAuthService());

      final result = await repo.signInWithGoogle();

      expect(result, isA<Ok<AppUser>>());
      expect(result.valueOrNull?.email, 'livia@exemplo.com');
    });

    test('traduz credencial inválida na frase da tela', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthService(
          error: FirebaseAuthException(code: 'invalid-credential'),
        ),
      );

      final result = await repo.signIn('livia@exemplo.com', 'errada');

      expect(result.errorOrNull, isA<CredenciaisInvalidasError>());
      expect(result.errorOrNull?.codigo, 'invalid-credential');
      expect(result.errorOrNull?.mensagem, contains('E-mail ou senha'));
      expect(result.errorOrNull?.mensagem, isNot(contains('Firebase')));
    });

    test('traduz e-mail já cadastrado no cadastro', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthService(
          error: FirebaseAuthException(code: 'email-already-in-use'),
        ),
      );

      final result = await repo.signUp('livia@exemplo.com', 'segredo123');

      expect(result.errorOrNull, isA<EmailJaEmUsoError>());
    });

    test('traduz queda de rede do Firebase em NetworkError', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthService(
          error: FirebaseAuthException(code: 'network-request-failed'),
        ),
      );

      final result = await repo.signIn('livia@exemplo.com', 'segredo123');

      expect(result.errorOrNull, isA<NetworkError>());
    });

    test('exceção inesperada não escapa como exceção crua', () async {
      final repo = AuthRepositoryImpl(_FakeAuthService(error: StateError('boom')));

      final result = await repo.signIn('livia@exemplo.com', 'segredo123');

      expect(result.errorOrNull, isA<ServerError>());
      expect(result.valueOrNull, isNull);
    });

    test('provedor que não responde vira frase, não espera eterna', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthServiceQuePendura(),
        timeLimit: const Duration(milliseconds: 50),
      );

      final result = await repo.signIn('livia@exemplo.com', 'segredo123');

      expect(result.errorOrNull, isA<TempoEsgotadoError>());
      expect(result.errorOrNull?.mensagem, 'Demorou demais para responder. Tente de novo.');
    });

    test('resposta que chega depois do prazo é descartada em silêncio', () async {
      final service = _FakeAuthServiceQuePendura();
      final repo = AuthRepositoryImpl(
        service,
        timeLimit: const Duration(milliseconds: 50),
      );

      final Result<AppUser> result = await repo.signIn('livia@exemplo.com', 'segredo123');
      expect(result.errorOrNull, isA<TempoEsgotadoError>());

      // `.timeout` não cancela a origem: o erro que chega depois não muda o Result
      // já devolvido e não escapa como exceção não tratada (se escapasse, o
      // próprio teste falharia por erro assíncrono).
      service.falharTarde(FirebaseAuthException(code: 'internal-error'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(result.errorOrNull, isA<TempoEsgotadoError>());
    });

    test('sair também tem tempo limite', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthServiceQuePendura(),
        timeLimit: const Duration(milliseconds: 50),
      );

      final result = await repo.signOut();

      expect(result.errorOrNull, isA<TempoEsgotadoError>());
    });

    test('sair dá Ok e chama o service', () async {
      final service = _FakeAuthService();
      final repo = AuthRepositoryImpl(service);

      final result = await repo.signOut();

      expect(result, isA<Ok<void>>());
      expect(service.saidas, 1);
    });

    test('falha ao sair também vira Result, não exceção', () async {
      final repo = AuthRepositoryImpl(_FakeAuthService(erroAoNaoSair: true));

      final result = await repo.signOut();

      expect(result.errorOrNull, isA<ServerError>());
    });

    test('o stream de sessão do service chega intacto ao app', () async {
      final service = _FakeAuthService();
      final repo = AuthRepositoryImpl(service);
      final List<AppUser?> vistos = <AppUser?>[];
      repo.sessionStream.listen(vistos.add);

      await service.emitir(_livia);
      await service.emitir(null);

      expect(vistos, <AppUser?>[_livia, null]);
    });
  });
}
