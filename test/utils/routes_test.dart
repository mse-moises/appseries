import 'package:appseries/app.dart';
import 'package:appseries/data/api_models/user.dart';
import 'package:appseries/data/repositories/auth_repository.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/ui/view/acervo_page.dart';
import 'package:appseries/ui/view/busca_page.dart';
import 'package:appseries/ui/view/detalhe_page.dart';
import 'package:appseries/ui/view/preferencias_page.dart';
import 'package:appseries/ui/view_model/auth_view_model.dart';
import 'package:appseries/ui/view_model/login_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AppUser?> get sessionStream => const Stream<AppUser?>.empty();

  @override
  Future<Result<AppUser>> signIn(String email, String password) async =>
      const Result<AppUser>.error(UnauthorizedError());

  @override
  Future<Result<AppUser>> signUp(String email, String password) async =>
      const Result<AppUser>.error(UnauthorizedError());

  @override
  Future<Result<AppUser>> signInWithGoogle() async =>
      const Result<AppUser>.error(UnauthorizedError());

  @override
  Future<Result<void>> signOut() async => const Result<void>.ok(null);
}

/// Abre a rota pelo caminho real do app: `Navigator.pushNamed`, não uma rota
/// montada à mão no teste.
Future<void> _empurrar(WidgetTester tester, String nome, {Object? argumentos}) async {
  await tester.pumpWidget(MaterialApp(
    key: ValueKey<String>('rota-$nome'),
    routes: Routes.mapa,
    home: Builder(
      builder: (BuildContext context) => TextButton(
        onPressed: () => Navigator.pushNamed(context, nome, arguments: argumentos),
        child: const Text('abrir'),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('Routes.mapa', () {
    test('as quatro rotas internas estão registradas', () {
      expect(
        Routes.mapa.keys,
        containsAll(<String>[Routes.busca, Routes.detalhe, Routes.acervo, Routes.preferencias]),
      );
    });

    testWidgets('o app monta o MaterialApp com o mapa de rotas', (tester) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<AuthRepository>(create: (_) => _FakeAuthRepository()),
          ChangeNotifierProvider<AuthViewModel>(
            create: (BuildContext c) => AuthViewModel(c.read<AuthRepository>()),
          ),
          ChangeNotifierProvider<LoginViewModel>(
            create: (BuildContext c) => LoginViewModel(c.read<AuthRepository>()),
          ),
        ],
        child: const App(),
      ));
      await tester.pump();

      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        app.routes!.keys,
        containsAll(<String>[Routes.busca, Routes.detalhe, Routes.acervo, Routes.preferencias]),
        reason: 'sem `routes:` no App, nenhuma tela interna é alcançável',
      );
    });

    testWidgets('cada rota abre a sua tela', (tester) async {
      final Map<String, Type> esperado = <String, Type>{
        Routes.busca: BuscaPage,
        Routes.acervo: AcervoPage,
        Routes.preferencias: PreferenciasPage,
      };

      for (final MapEntry<String, Type> e in esperado.entries) {
        await _empurrar(tester, e.key);
        expect(find.byType(e.value), findsOneWidget, reason: 'rota ${e.key}');
      }
    });

    testWidgets('pushNamed leva o TituloRef até o detalhe', (tester) async {
      await _empurrar(
        tester,
        Routes.detalhe,
        argumentos: const TituloRef(tipo: TipoMidia.tv, id: 1399),
      );

      expect(find.byType(DetalhePage), findsOneWidget);
      expect(find.textContaining('tv 1399'), findsOneWidget);
    });

    testWidgets('detalhe sem argumento degrada em vez de estourar', (tester) async {
      await _empurrar(tester, Routes.detalhe);

      expect(find.byType(DetalhePage), findsOneWidget);
      expect(find.textContaining('sem título na rota'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
