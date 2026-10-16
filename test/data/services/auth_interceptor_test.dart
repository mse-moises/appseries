import 'dart:async';

import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/services/auth_interceptor.dart';
import 'package:appseries/data/services/error_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:appseries/data/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

class _FakeAuthService implements AuthService {
  _FakeAuthService({
    this.token = 'token-falso',
    this.falharAoSair = false,
    this.pendurarAoSair = false,
    this.pendurarNoToken = false,
  });

  final String? token;
  final bool falharAoSair;
  final bool pendurarAoSair;
  final bool pendurarNoToken;
  final Completer<void> _saidaPendurada = Completer<void>();
  final Completer<void> _tokenPendurado = Completer<void>();
  int saidas = 0;

  @override
  Stream<AppUser?> get sessionStream => const Stream<AppUser?>.empty();

  @override
  Future<AppUser> signIn(String email, String password) async => _livia;

  @override
  Future<AppUser> signUp(String email, String password) async => _livia;

  @override
  Future<void> signOut() async {
    saidas++;
    if (falharAoSair) throw StateError('signOut falhou');
    // Aceita o pedido e nunca responde: é o caso que o prazo existe para cobrir.
    if (pendurarAoSair) await _saidaPendurada.future;
  }

  @override
  Future<String?> idToken() async {
    // Refresh em rede que nunca responde: o caso que o prazo do token cobre.
    if (pendurarNoToken) await _tokenPendurado.future;
    return token;
  }
}

/// Adapter de mentira: captura os headers e devolve a resposta pedida, sem rede.
class _AdapterFalso implements HttpClientAdapter {
  _AdapterFalso({this.statusCode = 200});

  final int statusCode;
  Map<String, dynamic>? headersRecebidos;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headersRecebidos = options.headers;
    return ResponseBody.fromString(
      '{"status":"ok"}',
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioCom(_FakeAuthService auth, _AdapterFalso adapter, {Duration? timeLimit}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://exemplo.test'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    timeLimit == null
        ? authInterceptor(auth)
        : authInterceptor(auth, timeLimit: timeLimit),
  );
  return dio;
}

void main() {
  group('authInterceptor', () {
    test('manda o token do Firebase em toda requisição', () async {
      final adapter = _AdapterFalso();
      final dio = _dioCom(_FakeAuthService(), adapter);

      await dio.get<Map<String, dynamic>>('/api/v1/acervo');

      expect(adapter.headersRecebidos?['Authorization'], 'Bearer token-falso');
    });

    test('sem token, não inventa header', () async {
      final adapter = _AdapterFalso();
      final dio = _dioCom(_FakeAuthService(token: null), adapter);

      await dio.get<Map<String, dynamic>>('/health');

      expect(adapter.headersRecebidos?.containsKey('Authorization'), isFalse);
    });

    test('token que demora não desloga ninguém: o pedido falha como conexão', () async {
      final auth = _FakeAuthService(pendurarNoToken: true);
      final adapter = _AdapterFalso();
      final dio = _dioCom(
        auth,
        adapter,
        timeLimit: const Duration(milliseconds: 50),
      );

      final Stopwatch relogio = Stopwatch()..start();
      DioException? capturado;
      try {
        await dio.get<Map<String, dynamic>>('/health');
      } on DioException catch (e) {
        capturado = e;
      }
      relogio.stop();

      expect(capturado?.type, DioExceptionType.connectionError);
      // Fixa o prazo INJETADO: um prazo fixo de 5s ignorando o parâmetro também
      // passaria no resto do teste, só mais devagar.
      expect(relogio.elapsed, lessThan(const Duration(seconds: 1)));
      expect(capturado?.response, isNull, reason: 'não foi o servidor que respondeu');

      // O pedido não pode ter saído sem o header: seria um 401 de mentira, e o
      // interceptor deslogaria a pessoa por causa de um refresh lento.
      expect(adapter.headersRecebidos, isNull);
      expect(auth.saidas, 0);

      // Um refresh de token lento é um problema do provedor, não da rede da
      // pessoa: a frase certa é "Demorou demais", não "Confira sua rede".
      expect(appErrorFromDio(capturado!), isA<TempoEsgotadoError>());
    });

    test('401 desloga e o erro continua subindo', () async {
      final auth = _FakeAuthService();
      final dio = _dioCom(auth, _AdapterFalso(statusCode: 401));

      await expectLater(
        dio.get<Map<String, dynamic>>('/api/v1/acervo'),
        throwsA(isA<DioException>()),
      );

      expect(auth.saidas, 1);
    });

    test('se o signOut pendurar, o 401 também não é engolido', () async {
      final auth = _FakeAuthService(pendurarAoSair: true);
      final dio = _dioCom(
        auth,
        _AdapterFalso(statusCode: 401),
        timeLimit: const Duration(milliseconds: 50),
      );

      await expectLater(
        dio.get<Map<String, dynamic>>('/api/v1/acervo'),
        throwsA(
          isA<DioException>().having(
            (DioException e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // Sem o prazo, este `await` dentro do interceptor nunca voltaria e o 401
      // ficaria esperando para sempre.
      expect(auth.saidas, 1);
    });

    test('outros erros não deslogam', () async {
      final auth = _FakeAuthService();
      final dio = _dioCom(auth, _AdapterFalso(statusCode: 500));

      await expectLater(
        dio.get<Map<String, dynamic>>('/api/v1/acervo'),
        throwsA(isA<DioException>()),
      );

      expect(auth.saidas, 0);
    });

    test('a falha do signOut deixa rastro no log', () async {
      final auth = _FakeAuthService(falharAoSair: true);
      final dio = _dioCom(auth, _AdapterFalso(statusCode: 401));
      final List<String> logs = <String>[];
      final void Function(String?, {int? wrapWidth}) original = debugPrint;
      debugPrint = (String? mensagem, {int? wrapWidth}) => logs.add(mensagem ?? '');
      addTearDown(() => debugPrint = original);

      await expectLater(
        dio.get<Map<String, dynamic>>('/api/v1/acervo'),
        throwsA(isA<DioException>()),
      );

      expect(logs.any((String l) => l.contains('falha ao sair')), isTrue);
    });

    test('se o signOut falhar, o 401 não é engolido', () async {
      final auth = _FakeAuthService(falharAoSair: true);
      final dio = _dioCom(auth, _AdapterFalso(statusCode: 401));

      await expectLater(
        dio.get<Map<String, dynamic>>('/api/v1/acervo'),
        throwsA(
          isA<DioException>().having(
            (DioException e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      // tentou deslogar, e a exceção do signOut não virou um erro "unknown"
      expect(auth.saidas, 1);
    });
  });
}
