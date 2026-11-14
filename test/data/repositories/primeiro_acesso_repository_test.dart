import 'package:appseries/data/repositories/primeiro_acesso_repository_impl.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PrimeiroAcessoRepositoryImpl', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('conta nova ainda não passou pela tela', () async {
      final result = await PrimeiroAcessoRepositoryImpl().jaPassou('u1');

      expect(result.valueOrNull, isFalse);
    });

    test('marcar fica gravado para a próxima leitura', () async {
      final PrimeiroAcessoRepositoryImpl repo = PrimeiroAcessoRepositoryImpl();

      expect((await repo.marcar('u1')).isOk, isTrue);

      expect((await repo.jaPassou('u1')).valueOrNull, isTrue);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PrimeiroAcessoRepositoryImpl.chave('u1')), isTrue);
    });

    test('a marca é por conta: outra pessoa no mesmo aparelho não herda', () async {
      final PrimeiroAcessoRepositoryImpl repo = PrimeiroAcessoRepositoryImpl();
      await repo.marcar('u1');

      expect((await repo.jaPassou('u2')).valueOrNull, isFalse);
    });

    test('armazenamento que falha vira Result de erro, não exceção', () async {
      final PrimeiroAcessoRepositoryImpl repo = PrimeiroAcessoRepositoryImpl(
        prefs: () => Future<SharedPreferences>.error(StateError('sem disco')),
      );

      expect((await repo.jaPassou('u1')).errorOrNull, isA<ArmazenamentoLocalError>());
      expect((await repo.marcar('u1')).errorOrNull, isA<ArmazenamentoLocalError>());
    });
  });
}
