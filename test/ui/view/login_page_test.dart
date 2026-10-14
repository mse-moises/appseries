import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/repositories/health_repository.dart';
import 'package:appseries/ui/view/home_page.dart';
import 'package:appseries/ui/view/login_page.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/utils/result.dart';
import 'package:appseries/utils/routes_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<Result<HealthStatus>> check() async =>
      const Result<HealthStatus>.ok(HealthStatus(status: 'ok'));
}

void main() {
  testWidgets('a tela de login mostra os campos e o botão', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('AppSeries'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('o botão Entrar navega para a home', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<HomeViewModel>(
        create: (_) => HomeViewModel(_FakeHealthRepository())..load(),
        child: MaterialApp(initialRoute: Routes.login, routes: Routes.mapa),
      ),
    );

    expect(find.byType(LoginPage), findsOneWidget);

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });
}
