import 'dart:async';

import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';

/// Dublê do contrato: o ViewModel nunca depende da implementação de verdade.
class _FakeTituloRepository implements TituloRepository {
  _FakeTituloRepository({this.respostaEmAlta, this.respostaPopulares});

  Result<List<TmdbItem>>? respostaEmAlta;
  Result<List<TmdbItem>>? respostaPopulares;
  int chamadasEmAlta = 0;
  int chamadasPopulares = 0;

  @override
  Future<Result<List<TmdbItem>>> emAlta() async {
    chamadasEmAlta++;
    return respostaEmAlta!;
  }

  @override
  Future<Result<List<TmdbItem>>> populares() async {
    chamadasPopulares++;
    return respostaPopulares!;
  }

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) => throw UnimplementedError();

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// Cada chamada fica pendente até o teste responder: é como se prova a corrida.
class _FakeControlado implements TituloRepository {
  final List<Completer<Result<List<TmdbItem>>>> emAltaPend =
      <Completer<Result<List<TmdbItem>>>>[];
  final List<Completer<Result<List<TmdbItem>>>> popularesPend =
      <Completer<Result<List<TmdbItem>>>>[];

  void responderEmAlta(int i, Result<List<TmdbItem>> r) => emAltaPend[i].complete(r);

  void responderPopulares(int i, Result<List<TmdbItem>> r) => popularesPend[i].complete(r);

  @override
  Future<Result<List<TmdbItem>>> emAlta() {
    final Completer<Result<List<TmdbItem>>> c = Completer<Result<List<TmdbItem>>>();
    emAltaPend.add(c);
    return c.future;
  }

  @override
  Future<Result<List<TmdbItem>>> populares() {
    final Completer<Result<List<TmdbItem>>> c = Completer<Result<List<TmdbItem>>>();
    popularesPend.add(c);
    return c.future;
  }

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) => throw UnimplementedError();

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// Fura o contrato em "em alta" e responde normal em "populares".
class _FakeQueLanca implements TituloRepository {
  @override
  Future<Result<List<TmdbItem>>> emAlta() async => throw const FormatException('contrato furado');

  @override
  Future<Result<List<TmdbItem>>> populares() async =>
      Result<List<TmdbItem>>.ok(<TmdbItem>[_item(9)]);

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) => throw UnimplementedError();

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

TmdbItem _item(int id) => TmdbItem(
      id: id,
      tipo: TipoMidia.movie,
      titulo: 'Título $id',
      ano: '2025',
      posterPath: '/p$id.jpg',
    );

Result<List<TmdbItem>> _ok(List<int> ids) =>
    Result<List<TmdbItem>>.ok(<TmdbItem>[for (final int id in ids) _item(id)]);

void main() {
  group('HomeViewModel', () {
    test('carrega as duas seções', () async {
      final vm = HomeViewModel(
        _FakeTituloRepository(
          respostaEmAlta: _ok(<int>[1, 2]),
          respostaPopulares: _ok(<int>[3, 4, 5]),
        ),
      );

      await vm.load();

      expect(vm.emAlta.itens, hasLength(2));
      expect(vm.populares.itens, hasLength(3));
      expect(vm.emAlta.carregando, isFalse);
      expect(vm.populares.carregando, isFalse);
      expect(vm.emAlta.erro, isNull);
    });

    test('o segundo carrossel não repete o que o primeiro mostrou', () async {
      final vm = HomeViewModel(
        _FakeTituloRepository(
          respostaEmAlta: _ok(<int>[1, 2]),
          respostaPopulares: _ok(<int>[2, 3]),
        ),
      );

      await vm.load();

      expect(vm.emAlta.itens.map((TmdbItem t) => t.id), <int>[1, 2]);
      expect(vm.populares.itens.map((TmdbItem t) => t.id), <int>[3]);
    });

    test('o mesmo id em tipos diferentes sobrevive ao dedupe', () async {
      final vm = HomeViewModel(
        _FakeTituloRepository(
          respostaEmAlta: Result<List<TmdbItem>>.ok(<TmdbItem>[
            const TmdbItem(id: 550, tipo: TipoMidia.movie, titulo: 'Filme 550'),
          ]),
          respostaPopulares: Result<List<TmdbItem>>.ok(<TmdbItem>[
            const TmdbItem(id: 550, tipo: TipoMidia.tv, titulo: 'Série 550'),
          ]),
        ),
      );

      await vm.load();

      expect(vm.populares.itens.map((TmdbItem t) => t.titulo), <String>['Série 550'],
          reason: 'filme 550 e série 550 são títulos diferentes');
    });

    test('erro em uma seção não apaga a outra', () async {
      final vm = HomeViewModel(
        _FakeTituloRepository(
          respostaEmAlta: const Result<List<TmdbItem>>.error(NetworkError()),
          respostaPopulares: _ok(<int>[3]),
        ),
      );

      await vm.load();

      expect(vm.emAlta.erro, 'Sem conexão com a internet. Confira sua rede e tente de novo.');
      expect(vm.emAlta.itens, isEmpty);
      expect(vm.populares.itens, hasLength(1));
      expect(vm.populares.erro, isNull);
    });

    test('lista vazia deixa a seção vazia, não em erro', () async {
      final vm = HomeViewModel(
        _FakeTituloRepository(
          respostaEmAlta: _ok(<int>[]),
          respostaPopulares: _ok(<int>[]),
        ),
      );

      await vm.load();

      expect(vm.emAlta.vazio, isTrue);
      expect(vm.populares.vazio, isTrue);
      expect(vm.emAlta.erro, isNull);
    });

    test('retry de uma seção não recarrega a outra', () async {
      final repo = _FakeTituloRepository(
        respostaEmAlta: _ok(<int>[1]),
        respostaPopulares: const Result<List<TmdbItem>>.error(NetworkError()),
      );
      final vm = HomeViewModel(repo);

      await vm.load();
      expect(vm.populares.erro, isNotNull);

      repo.respostaPopulares = _ok(<int>[2]);
      await vm.recarregarPopulares();

      expect(vm.populares.itens, hasLength(1));
      expect(vm.populares.erro, isNull);
      expect(repo.chamadasEmAlta, 1, reason: 'em alta não pode ser recarregado junto');
      expect(repo.chamadasPopulares, 2);
    });

    test('retry de em alta reaplica o dedupe sobre populares', () async {
      final repo = _FakeTituloRepository(
        respostaEmAlta: _ok(<int>[1]),
        respostaPopulares: _ok(<int>[2, 3]),
      );
      final vm = HomeViewModel(repo);

      await vm.load();
      expect(vm.populares.itens.map((TmdbItem t) => t.id), <int>[2, 3]);

      // o retry traz um título que "Populares" já mostra
      repo.respostaEmAlta = _ok(<int>[2]);
      await vm.recarregarEmAlta();

      expect(vm.emAlta.itens.map((TmdbItem t) => t.id), <int>[2]);
      expect(
        vm.populares.itens.map((TmdbItem t) => t.id),
        <int>[3],
        reason: 'o dedupe tem de valer em qualquer ordem de carga',
      );
    });

    test('a segunda carga zera as seções antes de responder', () async {
      final _FakeControlado repo = _FakeControlado();
      final vm = HomeViewModel(repo);

      unawaited(vm.load());
      repo.responderEmAlta(0, _ok(<int>[1]));
      await pumpEventQueue();
      repo.responderPopulares(0, _ok(<int>[2]));
      await pumpEventQueue();
      expect(vm.emAlta.itens, hasLength(1));

      // segunda carga: começa e fica pendente
      unawaited(vm.load());

      expect(vm.emAlta.carregando, isTrue);
      expect(vm.emAlta.itens, isEmpty, reason: 'os títulos antigos saem da tela já no início');
      expect(vm.populares.carregando, isTrue);

      repo.responderEmAlta(1, _ok(<int>[]));
      await pumpEventQueue();
      repo.responderPopulares(1, _ok(<int>[]));
      await pumpEventQueue();

      expect(vm.emAlta.itens, isEmpty);
      expect(vm.populares.itens, isEmpty);
    });

    test('o reset zera o que a conta anterior tinha, sem avisar a View', () async {
      final vm = HomeViewModel(
        _FakeTituloRepository(respostaEmAlta: _ok(<int>[1]), respostaPopulares: _ok(<int>[2])),
      );
      await vm.load();

      int avisos = 0;
      vm.addListener(() => avisos++);
      vm.reset();

      expect(vm.emAlta.itens, isEmpty);
      expect(vm.populares.itens, isEmpty);
      expect(vm.emAlta.carregando, isTrue, reason: 'o primeiro frame tem de ser o spinner');
      expect(vm.populares.vazio, isFalse);
      expect(avisos, 0, reason: 'reset roda no initState: não pode notificar');
    });

    test('reset invalida a requisição em voo mesmo sem load em seguida', () async {
      final _FakeControlado repo = _FakeControlado();
      final vm = HomeViewModel(repo);

      unawaited(vm.load());
      vm.reset();

      // a sessão anterior responde depois do reset, sem nenhum load novo
      repo.responderEmAlta(0, _ok(<int>[1]));
      await pumpEventQueue();

      expect(vm.emAlta.itens, isEmpty,
          reason: 'a resposta da sessão que acabou não pode entrar');
      expect(vm.emAlta.carregando, isTrue);
    });

    test('carga antiga terminando depois da nova não deixa carrossel girando', () async {
      final _FakeControlado repo = _FakeControlado();
      final vm = HomeViewModel(repo);

      // conta A: começa e fica pendente no primeiro carrossel
      unawaited(vm.load());
      // relogin: conta B é a dona do estado
      vm.reset();
      unawaited(vm.load());

      // B responde os dois carrosséis e termina
      repo.responderEmAlta(1, _ok(<int>[7]));
      await pumpEventQueue();
      repo.responderPopulares(0, _ok(<int>[3]));
      await pumpEventQueue();

      expect(vm.emAlta.itens.map((TmdbItem t) => t.id), <int>[7]);
      expect(vm.populares.itens.map((TmdbItem t) => t.id), <int>[3]);

      // agora a conta A responde: o primeiro carrossel dela já estava pendente,
      // e ao resolver ela segue para o SEGUNDO carrossel — que é a carga velha
      // entrando depois de a nova ter terminado
      repo.responderEmAlta(0, _ok(<int>[9]));
      await pumpEventQueue();
      await pumpEventQueue();

      expect(repo.popularesPend, hasLength(1),
          reason: 'a carga velha não pode nem pedir o segundo carrossel');

      expect(vm.emAlta.itens.map((TmdbItem t) => t.id), <int>[7],
          reason: 'a conta anterior não pode pintar a tela');
      expect(vm.populares.itens.map((TmdbItem t) => t.id), <int>[3]);
      expect(vm.populares.carregando, isFalse,
          reason: 'a carga velha não pode deixar Populares girando para sempre');
    });

    test('repository que lança Error (não Exception) não deixa a seção girando', () async {
      final vm = HomeViewModel(_FakeQueLancaError());

      await vm.load();

      expect(vm.emAlta.carregando, isFalse);
      expect(vm.emAlta.erro, const ServerError().mensagem);
      expect(vm.populares.itens, hasLength(1), reason: 'a outra seção carrega normalmente');
    });

    test('repository que lança não deixa a seção presa em carregando', () async {
      final vm = HomeViewModel(_FakeQueLanca());

      await vm.load();

      expect(vm.emAlta.carregando, isFalse);
      expect(vm.emAlta.erro, 'O servidor deu uma escorregada. Tente em instantes.');
      expect(vm.populares.itens, hasLength(1));
    });
  });
}

/// Fura o contrato com um `Error` (não `Exception`), como um cast quebrado no
/// `fromJson` produz.
class _FakeQueLancaError implements TituloRepository {
  @override
  Future<Result<List<TmdbItem>>> emAlta() async => throw StateError('cast quebrado');

  @override
  Future<Result<List<TmdbItem>>> populares() async =>
      Result<List<TmdbItem>>.ok(<TmdbItem>[_item(9)]);

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) => throw UnimplementedError();

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}
