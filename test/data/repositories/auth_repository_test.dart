import 'dart:async';

import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/auth_repository_impl.dart';
import 'package:appseries/data/services/auth_service.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
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
    if (erroAoNaoSair == true) throw const ServerError();
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

    test('o erro do Google traduzido no Service chega intacto ao app', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthService(error: const GoogleCanceladoError()),
      );

      final result = await repo.signInWithGoogle();

      expect(result.errorOrNull, isA<GoogleCanceladoError>());
      expect(result.errorOrNull?.mensagem, 'Entrada com o Google cancelada.');
    });

    test('e-mail que já tem conta por senha pede a senha', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthService(error: const ContaDeOutroMetodoError()),
      );

      final result = await repo.signInWithGoogle();

      expect(result.errorOrNull, isA<ContaDeOutroMetodoError>());
    });

    test('o caminho do Google não herda o prazo curto de rede', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthServiceQuePendura(),
        timeLimit: const Duration(milliseconds: 20),
        interactiveLimit: const Duration(milliseconds: 400),
      );

      bool respondeu = false;
      unawaited(repo.signInWithGoogle().then((_) => respondeu = true));

      await Future<void>.delayed(const Duration(milliseconds: 120));

      // Escolher uma conta leva tempo humano: estourar aqui devolveria a frase
      // "Demorou demais" com o seletor ainda aberto na tela.
      expect(respondeu, isFalse, reason: 'herdou o prazo de rede de 20 ms');
    });

    test('o prazo do caminho interativo também estoura, com a frase certa', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthServiceQuePendura(),
        interactiveLimit: const Duration(milliseconds: 50),
      );

      final result = await repo.signInWithGoogle();

      expect(result.errorOrNull, isA<TempoEsgotadoError>());
    });

    test('o erro de credencial do Service chega com a frase pronta', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthService(error: const CredenciaisInvalidasError()),
      );

      final result = await repo.signIn('livia@exemplo.com', 'errada');

      expect(result.errorOrNull, isA<CredenciaisInvalidasError>());
      expect(result.errorOrNull?.codigo, 'invalid-credential');
      expect(result.errorOrNull?.mensagem, contains('E-mail ou senha'));
      expect(result.errorOrNull?.mensagem, isNot(contains('Firebase')));
    });

    test('o erro de e-mail em uso do Service passa intacto', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthService(error: const EmailJaEmUsoError()),
      );

      final result = await repo.signUp('livia@exemplo.com', 'segredo123');

      expect(result.errorOrNull, isA<EmailJaEmUsoError>());
    });

    test('o erro de rede do Service passa intacto', () async {
      final repo = AuthRepositoryImpl(
        _FakeAuthService(error: const NetworkError()),
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
      service.falharTarde(const ServerError());
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
