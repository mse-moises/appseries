import 'dart:async';
import 'dart:typed_data';

import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/services/auth_service.dart';
import 'package:appseries/main.dart';
import 'package:appseries/ui/view/home_page.dart';
import 'package:appseries/ui/view/preferences_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const AppUser _livia = AppUser(id: 'u1', email: 'livia@exemplo.com');

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.logada});

  final AppUser? logada;

  // Como o Firebase: emite o estado atual e fica aberto (um stream que fecha
  // derruba a sessão no AuthViewModel).
  @override
  Stream<AppUser?> get sessionStream => logada == null
      ? const Stream<AppUser?>.empty()
      : Stream<AppUser?>.multi((StreamController<AppUser?> c) => c.add(logada));

  @override
  Future<AppUser> signIn(String email, String password) async => _livia;

  @override
  Future<AppUser> signUp(String email, String password) async => _livia;

  @override
  Future<AppUser> signInWithGoogle() async => _livia;

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'token-do-app';
}

class _AdapterFalso implements HttpClientAdapter {
  _AdapterFalso({this.corpo = '{"status":"ok"}'});

  final String corpo;
  Map<String, dynamic>? headersRecebidos;
  final List<String> caminhos = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headersRecebidos = options.headers;
    caminhos.add(options.path);
    return ResponseBody.fromString(
      corpo,
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

  group('AppSeries', () {
    // Todo widget test monta os providers à mão: sem este, apagar um provider do
    // `main.dart` quebraria o app no boot com a suíte inteira verde.
    testWidgets('o app de verdade sobe logado até a home', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final _AdapterFalso adapter =
          _AdapterFalso(corpo: '{"momento":null,"generos":["Drama"],"resultados":[]}');

      await tester.pumpWidget(AppSeries(
        authService: _FakeAuthService(logada: _livia),
        adaptadorHttp: adapter,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(adapter.caminhos, contains('/api/v1/preferencias'),
          reason: 'o gate decidiu o primeiro acesso pelo PreferencesViewModel da raiz');
      expect(tester.takeException(), isNull);
    });

    testWidgets('conta nova sobe até os chips de gênero', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(AppSeries(
        authService: _FakeAuthService(logada: _livia),
        adaptadorHttp: _AdapterFalso(corpo: '{"momento":null,"generos":[]}'),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PreferencesPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
