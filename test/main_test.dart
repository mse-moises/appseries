import 'dart:typed_data';

import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/services/auth_service.dart';
import 'package:appseries/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

class _FakeAuthService implements AuthService {
  @override
  Stream<AppUser?> get sessionStream => const Stream<AppUser?>.empty();

  @override
  Future<AppUser> signIn(String email, String password) async => _livia;

  @override
  Future<AppUser> signUp(String email, String password) async => _livia;

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'token-do-app';
}

class _AdapterFalso implements HttpClientAdapter {
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
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('buildDio', () {
    // Sem este teste, apagar o `dio.interceptors.add(authInterceptor(auth))` do
    // app deixaria a suíte inteira verde e o app mandaria requisição sem token.
    test('o Dio do app sai com o interceptor de token ligado', () async {
      final adapter = _AdapterFalso();
      final Dio dio = buildDio(_FakeAuthService());
      dio.httpClientAdapter = adapter;

      await dio.get<Map<String, dynamic>>('/api/v1/acervo');

      expect(adapter.headersRecebidos?['Authorization'], 'Bearer token-do-app');
    });
  });
}
