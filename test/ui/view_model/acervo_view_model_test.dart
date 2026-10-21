import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dublê do contrato: o ViewModel nunca depende da implementação de verdade.
class _FakeAcervoRepository implements AcervoRepository {
  _FakeAcervoRepository(this._resposta);

  final Result<List<AcervoItem>> _resposta;

  @override
  Future<Result<List<AcervoItem>>> listar() async => _resposta;
}

/// Devolve uma resposta por chamada, na ordem — é o que permite testar recarga.
class _FakeRespostasSequenciais implements AcervoRepository {
  _FakeRespostasSequenciais(this._respostas);

  final List<Result<List<AcervoItem>>> _respostas;
  int _chamadas = 0;

  @override
  Future<Result<List<AcervoItem>>> listar() async => _respostas[_chamadas++];
}

AcervoItem _item({
  required int tmdbId,
  EstadoAcervo estado = EstadoAcervo.planToWatch,
  TipoMidia? tipo = TipoMidia.movie,
}) =>
    AcervoItem(tmdbId: tmdbId, estado: estado, tipo: tipo);

void main() {
  group('AcervoViewModel', () {
    test('monta o mapa por (tipo, tmdbId): filme 550 não é a série 550', () async {
      final vm = AcervoViewModel(
        _FakeAcervoRepository(Result<List<AcervoItem>>.ok(<AcervoItem>[
          _item(tmdbId: 550, estado: EstadoAcervo.planToWatch, tipo: TipoMidia.movie),
          _item(tmdbId: 550, estado: EstadoAcervo.watched, tipo: TipoMidia.tv),
        ])),
      );

      await vm.load();

      expect(vm.total, 2);
      expect(vm.estadoDe(TipoMidia.movie, 550), EstadoAcervo.planToWatch);
      expect(vm.estadoDe(TipoMidia.tv, 550), EstadoAcervo.watched);
      expect(vm.estadoDe(TipoMidia.movie, 999), isNull);
    });

    test('linha antiga sem tipo responde para os dois espaços', () async {
      final vm = AcervoViewModel(
        _FakeAcervoRepository(Result<List<AcervoItem>>.ok(<AcervoItem>[
          _item(tmdbId: 1399, estado: EstadoAcervo.dropped, tipo: null),
        ])),
      );

      await vm.load();

      expect(vm.estadoDe(TipoMidia.movie, 1399), EstadoAcervo.dropped);
      expect(vm.estadoDe(TipoMidia.tv, 1399), EstadoAcervo.dropped);
    });

    test('linha sem tipo não sobrescreve a linha tipada do mesmo id', () async {
      final vm = AcervoViewModel(
        _FakeAcervoRepository(Result<List<AcervoItem>>.ok(<AcervoItem>[
          _item(tmdbId: 550, estado: EstadoAcervo.dropped, tipo: null),
          _item(tmdbId: 550, estado: EstadoAcervo.watched, tipo: TipoMidia.tv),
        ])),
      );

      await vm.load();

      expect(vm.estadoDe(TipoMidia.tv, 550), EstadoAcervo.watched);
      expect(vm.estadoDe(TipoMidia.movie, 550), EstadoAcervo.dropped);
    });

    test('erro tipado vira mensagem pronta para a tela', () async {
      final vm = AcervoViewModel(
        _FakeAcervoRepository(const Result<List<AcervoItem>>.error(NetworkError())),
      );

      await vm.load();

      expect(vm.itens, isEmpty);
      expect(vm.error, 'Sem conexão com a internet. Confira sua rede e tente de novo.');
    });

    test('a segunda carga não devolve o acervo da sessão anterior', () async {
      final vm = AcervoViewModel(
        _FakeRespostasSequenciais(<Result<List<AcervoItem>>>[
          Result<List<AcervoItem>>.ok(<AcervoItem>[_item(tmdbId: 1399)]),
          const Result<List<AcervoItem>>.error(NetworkError()),
        ]),
      );

      await vm.load();
      expect(vm.total, 1);

      await vm.load();

      expect(vm.total, 0, reason: 'a conta nova não pode herdar o acervo da anterior');
      expect(vm.estadoDe(TipoMidia.movie, 1399), isNull);
      expect(vm.error, isNotNull);
    });

    test('o primeiro aviso da recarga já vem com a lista zerada', () async {
      final vm = AcervoViewModel(
        _FakeRespostasSequenciais(<Result<List<AcervoItem>>>[
          Result<List<AcervoItem>>.ok(<AcervoItem>[_item(tmdbId: 1399)]),
          Result<List<AcervoItem>>.ok(<AcervoItem>[]),
        ]),
      );

      await vm.load();

      final List<int> totais = <int>[];
      vm.addListener(() => totais.add(vm.total));

      await vm.load();

      expect(totais.first, 0, reason: 'a View não pode desenhar o dado antigo durante a carga');
      expect(totais.last, 0);
      expect(totais, hasLength(2));
    });

    test('repository que lança não deixa a tela presa em carregando', () async {
      final vm = AcervoViewModel(_FakeQueLanca());

      await vm.load();

      expect(vm.isLoading, isFalse);
      expect(vm.error, 'O servidor deu uma escorregada. Tente em instantes.');
    });
  });
}

class _FakeQueLanca implements AcervoRepository {
  @override
  Future<Result<List<AcervoItem>>> listar() async => throw const FormatException('contrato furado');
}
