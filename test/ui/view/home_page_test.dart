import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/repositories/health_repository.dart';
import 'package:appseries/ui/view/home_page.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<Result<HealthStatus>> check() async =>
      const Result<HealthStatus>.ok(HealthStatus(status: 'ok'));
}

void main() {
  testWidgets('a home mostra o estado do backend', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<HomeViewModel>(
        create: (_) => HomeViewModel(_FakeHealthRepository())..load(),
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Backend respondeu'), findsOneWidget);
    expect(find.textContaining('ok'), findsWidgets);
  });
}
