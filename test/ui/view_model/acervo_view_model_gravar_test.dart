import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cada gravação fica pendente até o teste responder: é como se vê o estado
/// otimista antes da resposta, e a corrida com o logout.
class _FakeAcervo implements AcervoRepository {
  _FakeAcervo([this.inicial = const <AcervoItem>[]]);

  final List<AcervoItem> inicial;
  final List<String> chamadas = <String>[];
  final List<Completer<Result<AcervoItem>>> marcacoes = <Completer<Result<AcervoItem>>>[];
  final List<Completer<Result<void>>> remocoes = <Completer<Result<void>>>[];

  @override
  Future<Result<List<AcervoItem>>> listar() async => Result<List<AcervoItem>>.ok(inicial);

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) {
    chamadas.add('marcar ${tipo.name}:$tmdbId ${estado.name}');
    final Completer<Result<AcervoItem>> c = Completer<Result<AcervoItem>>();
    marcacoes.add(c);
    return c.future;
  }

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) {
    chamadas.add('remover ${tipo.name}:$tmdbId');
    final Completer<Result<void>> c = Completer<Result<void>>();
    remocoes.add(c);
    return c.future;
  }
}

/// Fura o contrato: um repository nunca lança, mas o botão não pode girar se lançar.
class _FakeQueLanca extends _FakeAcervo {
  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) async =>
      throw StateError('cast quebrado');
}

const AcervoItem _salvo = AcervoItem(
  tmdbId: 1399,
  estado: EstadoAcervo.planToWatch,
  tipo: TipoMidia.tv,
  titulo: 'Game of Thrones',
  ano: '2011',
);

Future<AcervoViewModel> _carregado(_FakeAcervo repo) async {
  final AcervoViewModel vm = AcervoViewModel(repo);
  await vm.load();
  return vm;
}

void main() {
  group('AcervoViewModel.marcar', () {
    test('o estado novo aparece antes da resposta, e o botão fica ocupado', () async {
      final _FakeAcervo repo = _FakeAcervo();
      final AcervoViewModel vm = await _carregado(repo);

      unawaited(vm.marcar(TipoMidia.tv, 1399, EstadoAcervo.planToWatch));

      expect(vm.estadoDe(TipoMidia.tv, 1399), EstadoAcervo.planToWatch);
      expect(vm.enviando(TipoMidia.tv, 1399), isTrue);
      expect(vm.total, 1);
    });

    test('sucesso fica com a linha do servidor e libera o botão', () async {
      final _FakeAcervo repo = _FakeAcervo();
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> gravando = vm.marcar(TipoMidia.tv, 1399, EstadoAcervo.planToWatch);
      repo.marcacoes.single.complete(const Result<AcervoItem>.ok(_salvo));

      expect(await gravando, isNull);
      expect(vm.estadoDe(TipoMidia.tv, 1399), EstadoAcervo.planToWatch);
      expect(vm.itens.single.titulo, 'Game of Thrones', reason: 'a linha otimista não tem título');
      expect(vm.enviando(TipoMidia.tv, 1399), isFalse);
      expect(repo.chamadas, <String>['marcar tv:1399 planToWatch']);
    });

    test('falha volta ao estado anterior e devolve o erro para a tela', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[
        const AcervoItem(tmdbId: 1399, estado: EstadoAcervo.watching, tipo: TipoMidia.tv),
      ]);
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> gravando = vm.marcar(TipoMidia.tv, 1399, EstadoAcervo.dropped);
      expect(vm.estadoDe(TipoMidia.tv, 1399), EstadoAcervo.dropped);
      repo.marcacoes.single.complete(const Result<AcervoItem>.error(NetworkError()));

      expect(await gravando, isA<NetworkError>());
      expect(vm.estadoDe(TipoMidia.tv, 1399), EstadoAcervo.watching);
      expect(vm.enviando(TipoMidia.tv, 1399), isFalse);
    });

    test('falha num título que não estava no acervo tira a linha otimista', () async {
      final _FakeAcervo repo = _FakeAcervo();
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> gravando = vm.marcar(TipoMidia.movie, 550, EstadoAcervo.planToWatch);
      repo.marcacoes.single.complete(const Result<AcervoItem>.error(ConflictError()));

      expect(await gravando, isA<ConflictError>(), reason: 'erro 400 nunca é engolido');
      expect(vm.estadoDe(TipoMidia.movie, 550), isNull);
      expect(vm.total, 0);
    });

    test('o rollback de um título não desfaz o que outro gravou no meio', () async {
      final _FakeAcervo repo = _FakeAcervo();
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> a = vm.marcar(TipoMidia.movie, 1, EstadoAcervo.planToWatch);
      final Future<AppError?> b = vm.marcar(TipoMidia.tv, 2, EstadoAcervo.watching);
      repo.marcacoes[1].complete(const Result<AcervoItem>.ok(
        AcervoItem(tmdbId: 2, estado: EstadoAcervo.watching, tipo: TipoMidia.tv),
      ));
      await b;
      repo.marcacoes[0].complete(const Result<AcervoItem>.error(NetworkError()));
      await a;

      expect(vm.estadoDe(TipoMidia.movie, 1), isNull);
      expect(vm.estadoDe(TipoMidia.tv, 2), EstadoAcervo.watching);
    });

    test('filme 550 e série 550 são linhas diferentes', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[
        const AcervoItem(tmdbId: 550, estado: EstadoAcervo.watched, tipo: TipoMidia.tv),
      ]);
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> gravando = vm.marcar(TipoMidia.movie, 550, EstadoAcervo.planToWatch);
      repo.marcacoes.single.complete(const Result<AcervoItem>.ok(
        AcervoItem(tmdbId: 550, estado: EstadoAcervo.planToWatch, tipo: TipoMidia.movie),
      ));
      await gravando;

      expect(vm.estadoDe(TipoMidia.movie, 550), EstadoAcervo.planToWatch);
      expect(vm.estadoDe(TipoMidia.tv, 550), EstadoAcervo.watched);
    });

    test('segundo toque durante a gravação não manda outra requisição', () async {
      final _FakeAcervo repo = _FakeAcervo();
      final AcervoViewModel vm = await _carregado(repo);

      unawaited(vm.marcar(TipoMidia.tv, 1399, EstadoAcervo.planToWatch));
      await vm.marcar(TipoMidia.tv, 1399, EstadoAcervo.watched);

      expect(repo.chamadas, hasLength(1));
      expect(vm.estadoDe(TipoMidia.tv, 1399), EstadoAcervo.planToWatch);
    });

    test('tipo desconhecido recusa sem mexer na tela', () async {
      final _FakeAcervo repo = _FakeAcervo();
      final AcervoViewModel vm = await _carregado(repo);
      int avisos = 0;
      vm.addListener(() => avisos++);

      final AppError? erro = await vm.marcar(TipoMidia.desconhecido, 1, EstadoAcervo.planToWatch);

      expect(erro, isA<AcervoIndisponivelError>());
      expect(repo.chamadas, isEmpty);
      expect(avisos, 0);
    });

    test('resposta que chega depois do logout não pinta o acervo da conta nova', () async {
      final _FakeAcervo repo = _FakeAcervo();
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> gravando = vm.marcar(TipoMidia.tv, 1399, EstadoAcervo.planToWatch);
      vm.reset();
      repo.marcacoes.single.complete(const Result<AcervoItem>.ok(_salvo));
      await gravando;

      expect(vm.estadoDe(TipoMidia.tv, 1399), isNull);
      expect(vm.enviando(TipoMidia.tv, 1399), isFalse);
    });

    test('repository que lança não deixa o botão girando', () async {
      final AcervoViewModel vm = await _carregado(_FakeQueLanca());

      final AppError? erro = await vm.marcar(TipoMidia.tv, 1399, EstadoAcervo.planToWatch);

      expect(erro, isA<ServerError>());
      expect(vm.enviando(TipoMidia.tv, 1399), isFalse);
      expect(vm.estadoDe(TipoMidia.tv, 1399), isNull);
    });
  });

  group('AcervoViewModel — ordem e remover', () {
    test('título novo entra no topo; trocar o estado não muda a posição', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[
        const AcervoItem(tmdbId: 1, estado: EstadoAcervo.watched, tipo: TipoMidia.movie),
        const AcervoItem(tmdbId: 2, estado: EstadoAcervo.watched, tipo: TipoMidia.movie),
      ]);
      final AcervoViewModel vm = await _carregado(repo);

      unawaited(vm.marcar(TipoMidia.tv, 9, EstadoAcervo.planToWatch));
      unawaited(vm.marcar(TipoMidia.movie, 2, EstadoAcervo.dropped));

      expect(vm.itens.map((AcervoItem i) => i.tmdbId), <int>[9, 1, 2]);
    });

    test('remoção que falha devolve o título ao mesmo lugar, com a ficha inteira', () async {
      final AcervoItem doMeio = AcervoItem(
        tmdbId: 2,
        estado: EstadoAcervo.watching,
        tipo: TipoMidia.movie,
        titulo: 'A Origem',
        ano: '2010',
        posterPath: '/origem.jpg',
        atualizadoEm: DateTime.utc(2026, 10, 20),
      );
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[
        const AcervoItem(tmdbId: 1, estado: EstadoAcervo.watched, tipo: TipoMidia.movie),
        doMeio,
        const AcervoItem(tmdbId: 3, estado: EstadoAcervo.watched, tipo: TipoMidia.movie),
      ]);
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> removendo = vm.remover(TipoMidia.movie, 2);
      expect(vm.itens.map((AcervoItem i) => i.tmdbId), <int>[1, 3]);
      repo.remocoes.single.complete(const Result<void>.error(NetworkError()));
      await removendo;

      expect(vm.itens.map((AcervoItem i) => i.tmdbId), <int>[1, 2, 3]);
      final AcervoItem devolvido = vm.itens[1];
      expect(devolvido.estado, EstadoAcervo.watching);
      expect(devolvido.titulo, 'A Origem');
      expect(devolvido.ano, '2010');
      expect(devolvido.posterPath, '/origem.jpg');
      expect(devolvido.atualizadoEm, DateTime.utc(2026, 10, 20));
    });

    test('remover um título não mexe nos outros', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[
        const AcervoItem(tmdbId: 550, estado: EstadoAcervo.watched, tipo: TipoMidia.movie),
        const AcervoItem(tmdbId: 550, estado: EstadoAcervo.watching, tipo: TipoMidia.tv),
      ]);
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> removendo = vm.remover(TipoMidia.tv, 550);
      repo.remocoes.single.complete(const Result<void>.ok(null));
      await removendo;

      expect(vm.estadoDe(TipoMidia.tv, 550), isNull);
      expect(vm.estadoDe(TipoMidia.movie, 550), EstadoAcervo.watched,
          reason: 'filme 550 e série 550 são títulos diferentes');
      expect(repo.chamadas, <String>['remover tv:550']);
    });

    test('"Remover" só existe para a linha com tipo', () async {
      final AcervoViewModel vm = await _carregado(_FakeAcervo(<AcervoItem>[
        const AcervoItem(tmdbId: 1, estado: EstadoAcervo.watched, tipo: TipoMidia.movie),
        const AcervoItem(tmdbId: 2, estado: EstadoAcervo.watched),
      ]));

      expect(vm.podeRemover(TipoMidia.movie, 1), isTrue);
      expect(vm.estadoDe(TipoMidia.movie, 2), EstadoAcervo.watched);
      expect(vm.podeRemover(TipoMidia.movie, 2), isFalse,
          reason: 'linha antiga sem tipo: o DELETE ?tipo= não garante apagá-la');
      expect(vm.podeRemover(TipoMidia.tv, 3), isFalse);
    });
  });

  group('AcervoViewModel.remover', () {
    test('tira o título na hora e confirma com o servidor', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[_salvo]);
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> removendo = vm.remover(TipoMidia.tv, 1399);
      expect(vm.estadoDe(TipoMidia.tv, 1399), isNull);
      repo.remocoes.single.complete(const Result<void>.ok(null));

      expect(await removendo, isNull);
      expect(vm.total, 0);
      expect(repo.chamadas, <String>['remover tv:1399']);
    });

    test('404 é o objetivo alcançado: não volta o título', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[_salvo]);
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> removendo = vm.remover(TipoMidia.tv, 1399);
      repo.remocoes.single.complete(const Result<void>.error(NotFoundError()));

      expect(await removendo, isNull);
      expect(vm.estadoDe(TipoMidia.tv, 1399), isNull);
    });

    test('falha devolve o título com o estado que ele tinha', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[_salvo]);
      final AcervoViewModel vm = await _carregado(repo);

      final Future<AppError?> removendo = vm.remover(TipoMidia.tv, 1399);
      repo.remocoes.single.complete(const Result<void>.error(NetworkError()));

      expect(await removendo, isA<NetworkError>());
      expect(vm.estadoDe(TipoMidia.tv, 1399), EstadoAcervo.planToWatch);
      expect(vm.itens.single.titulo, 'Game of Thrones');
    });
  });
}
