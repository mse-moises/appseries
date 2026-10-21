import 'dart:async';

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

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// Devolve uma resposta por chamada, na ordem — é o que permite testar recarga.
class _FakeRespostasSequenciais implements AcervoRepository {
  _FakeRespostasSequenciais(this._respostas);

  final List<Result<List<AcervoItem>>> _respostas;
  int _chamadas = 0;

  @override
  Future<Result<List<AcervoItem>>> listar() async => _respostas[_chamadas++];

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
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
      // A API devolve "mais recente primeiro": a linha realista é a tipada vir
      // antes. Nesta ordem, um laço único escreveria `dropped` por cima da
      // série e o teste passaria mentindo — só as duas passadas acertam.
      final vm = AcervoViewModel(
        _FakeAcervoRepository(Result<List<AcervoItem>>.ok(<AcervoItem>[
          _item(tmdbId: 550, estado: EstadoAcervo.watched, tipo: TipoMidia.tv),
          _item(tmdbId: 550, estado: EstadoAcervo.dropped, tipo: null),
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

    test('resposta de uma carga antiga não sobrescreve a carga nova', () async {
      final _FakeControlado repo = _FakeControlado();
      final vm = AcervoViewModel(repo);

      unawaited(vm.load()); // conta A: fica pendente
      unawaited(vm.load()); // conta B: é a dona do estado
      expect(repo.pendentes, 2);

      repo.responder(1, Result<List<AcervoItem>>.ok(<AcervoItem>[_item(tmdbId: 550)]));
      await Future<void>.delayed(Duration.zero);
      expect(vm.total, 1);

      // a conta anterior responde DEPOIS: tem de ser descartada
      repo.responder(
        0,
        Result<List<AcervoItem>>.ok(<AcervoItem>[
          _item(tmdbId: 1),
          _item(tmdbId: 2),
          _item(tmdbId: 3),
        ]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(vm.total, 1, reason: 'a resposta da conta anterior não pode entrar');
      expect(vm.isLoading, isFalse);
    });

    test('carga antiga respondendo primeiro não apaga o carregando da nova', () async {
      final _FakeControlado repo = _FakeControlado();
      final vm = AcervoViewModel(repo);

      unawaited(vm.load()); // antiga
      unawaited(vm.load()); // nova

      repo.responder(
        0,
        Result<List<AcervoItem>>.ok(<AcervoItem>[_item(tmdbId: 1), _item(tmdbId: 2)]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(vm.total, 0);
      expect(vm.isLoading, isTrue, reason: 'a carga nova ainda está no ar');

      repo.responder(1, Result<List<AcervoItem>>.ok(<AcervoItem>[_item(tmdbId: 550)]));
      await Future<void>.delayed(Duration.zero);

      expect(vm.total, 1);
      expect(vm.isLoading, isFalse);
    });

    test('erro de uma carga antiga não apaga o acervo da nova', () async {
      final _FakeControlado repo = _FakeControlado();
      final vm = AcervoViewModel(repo);

      unawaited(vm.load());
      unawaited(vm.load());

      repo.responder(1, Result<List<AcervoItem>>.ok(<AcervoItem>[_item(tmdbId: 550)]));
      await Future<void>.delayed(Duration.zero);

      repo.responder(0, const Result<List<AcervoItem>>.error(NetworkError()));
      await Future<void>.delayed(Duration.zero);

      expect(vm.total, 1);
      expect(vm.error, isNull);
    });

    test('a precedência da linha tipada não depende da ordem do JSON', () async {
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

    test('tipo desconhecido responde nos dois espaços', () async {
      final vm = AcervoViewModel(
        _FakeAcervoRepository(Result<List<AcervoItem>>.ok(<AcervoItem>[
          _item(tmdbId: 1399, estado: EstadoAcervo.watched, tipo: TipoMidia.desconhecido),
        ])),
      );

      await vm.load();

      expect(vm.estadoDe(TipoMidia.movie, 1399), EstadoAcervo.watched);
      expect(vm.estadoDe(TipoMidia.tv, 1399), EstadoAcervo.watched);
      expect(vm.estadoDe(TipoMidia.desconhecido, 1399), EstadoAcervo.watched);
    });

    test('repository que lança não deixa a tela presa em carregando', () async {
      final vm = AcervoViewModel(_FakeQueLanca());

      await vm.load();

      expect(vm.isLoading, isFalse);
      expect(vm.error, 'O servidor deu uma escorregada. Tente em instantes.');
    });
  });
}

/// Cada chamada fica pendente até o teste responder: é como se prova a ordem.
class _FakeControlado implements AcervoRepository {
  final List<Completer<Result<List<AcervoItem>>>> _pendentes =
      <Completer<Result<List<AcervoItem>>>>[];

  int get pendentes => _pendentes.length;

  void responder(int indice, Result<List<AcervoItem>> resposta) =>
      _pendentes[indice].complete(resposta);

  @override
  Future<Result<List<AcervoItem>>> listar() {
    final Completer<Result<List<AcervoItem>>> c = Completer<Result<List<AcervoItem>>>();
    _pendentes.add(c);
    return c.future;
  }

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

class _FakeQueLanca implements AcervoRepository {
  @override
  Future<Result<List<AcervoItem>>> listar() async => throw const FormatException('contrato furado');

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}
