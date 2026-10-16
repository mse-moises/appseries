import 'package:appseries/data/api_models/health_status.dart';
import 'package:appseries/data/repositories/health_repository.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dublê do contrato: o ViewModel nunca depende da implementação de verdade.
class _FakeHealthRepository implements HealthRepository {
  _FakeHealthRepository(this._resposta);

  final Result<HealthStatus> _resposta;

  @override
  Future<Result<HealthStatus>> check() async => _resposta;
}

/// Fura o contrato: lança em vez de devolver `Result`.
class _FakeHealthRepositoryQueLanca implements HealthRepository {
  int chamadas = 0;

  @override
  Future<Result<HealthStatus>> check() async {
    chamadas++;
    throw const FormatException('contrato furado');
  }
}

/// Devolve uma resposta por chamada, na ordem — é o que permite testar recarga.
class _FakeRespostasSequenciais implements HealthRepository {
  _FakeRespostasSequenciais(this._respostas);

  final List<Result<HealthStatus>> _respostas;
  int _chamadas = 0;

  @override
  Future<Result<HealthStatus>> check() async => _respostas[_chamadas++];
}

void main() {
  group('HomeViewModel', () {
    test('começa carregando e termina com o dado', () async {
      final vm = HomeViewModel(
        _FakeHealthRepository(const Result<HealthStatus>.ok(HealthStatus(status: 'ok'))),
      );

      expect(vm.isLoading, isTrue);

      await vm.load();

      expect(vm.isLoading, isFalse);
      expect(vm.status?.status, 'ok');
      expect(vm.error, isNull);
    });

    test('erro tipado vira mensagem pronta para a tela', () async {
      final vm = HomeViewModel(
        _FakeHealthRepository(const Result<HealthStatus>.error(NetworkError())),
      );

      await vm.load();

      expect(vm.status, isNull);
      expect(vm.error, 'Sem conexão com a internet. Confira sua rede e tente de novo.');
    });

    test('avisa a View no começo e no fim da carga', () async {
      final vm = HomeViewModel(
        _FakeHealthRepository(const Result<HealthStatus>.ok(HealthStatus(status: 'ok'))),
      );
      int avisos = 0;
      vm.addListener(() => avisos++);

      await vm.load();

      expect(avisos, 2);
    });

    test('repository que lança não deixa a home presa em carregando', () async {
      final repo = _FakeHealthRepositoryQueLanca();
      final vm = HomeViewModel(repo);

      await vm.load();

      expect(vm.isLoading, isFalse, reason: 'a tela não pode travar no carregando');
      expect(vm.error, 'O servidor deu uma escorregada. Tente em instantes.');

      // O retry continua saindo depois de o contrato ser furado.
      await vm.load();
      expect(repo.chamadas, 2);
    });

    test('falha na recarga não deixa o dado antigo no estado', () async {
      final vm = HomeViewModel(
        _FakeRespostasSequenciais(<Result<HealthStatus>>[
          const Result<HealthStatus>.ok(HealthStatus(status: 'ok')),
          const Result<HealthStatus>.error(NetworkError()),
        ]),
      );

      await vm.load();
      expect(vm.status?.status, 'ok');

      await vm.load();

      expect(vm.status, isNull);
      expect(vm.error, isNotNull);
    });
  });
}
