import 'dart:async';

import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/view_model/search_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cada busca fica pendente até o teste responder: é como se prova a corrida.
class _FakeBusca implements TituloRepository {
  final List<String> consultas = <String>[];
  final List<Completer<Result<List<TmdbItem>>>> pendentes =
      <Completer<Result<List<TmdbItem>>>>[];

  void responder(int i, Result<List<TmdbItem>> r) => pendentes[i].complete(r);

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) {
    consultas.add(q);
    final Completer<Result<List<TmdbItem>>> c = Completer<Result<List<TmdbItem>>>();
    pendentes.add(c);
    return c.future;
  }

  @override
  Future<Result<List<TmdbItem>>> emAlta() => throw UnimplementedError();

  @override
  Future<Result<List<TmdbItem>>> populares() => throw UnimplementedError();

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// Fura o contrato: um repository nunca lança, mas a tela não pode girar se lançar.
class _FakeQueLanca extends _FakeBusca {
  @override
  Future<Result<List<TmdbItem>>> buscar(String q) async => throw StateError('cast quebrado');
}

const TmdbItem _filme = TmdbItem(id: 1, tipo: TipoMidia.movie, titulo: 'Pokémon: O Filme');
const TmdbItem _serie = TmdbItem(id: 2, tipo: TipoMidia.tv, titulo: 'Pokémon');

Result<List<TmdbItem>> _ok(List<TmdbItem> itens) => Result<List<TmdbItem>>.ok(itens);

/// Deixa o timer da espera disparar e a resposta chegar.
Future<void> _esperar() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await pumpEventQueue();
}

void main() {
  late _FakeBusca repo;
  late SearchViewModel vm;

  setUp(() {
    repo = _FakeBusca();
    vm = SearchViewModel(repo, espera: const Duration(milliseconds: 10));
  });

  tearDown(() => vm.dispose());

  group('SearchViewModel', () {
    test('começa ocioso, sem pedir nada', () {
      expect(vm.estado, EstadoBusca.ocioso);
      expect(repo.consultas, isEmpty);
    });

    test('menos de 3 letras não sai do app', () async {
      vm.setConsulta('po');
      await _esperar();

      expect(vm.estado, EstadoBusca.ocioso);
      expect(repo.consultas, isEmpty, reason: 'o backend responderia 400 query_too_short');
    });

    test('mais de 100 letras vira erro de busca inválida, sem rede e sem retry', () async {
      vm.setConsulta('a' * (kBuscaMax + 1));
      await _esperar();

      expect(vm.estado, EstadoBusca.erro);
      expect(vm.erro, const BuscaInvalidaError().mensagem);
      expect(vm.podeTentarDeNovo, isFalse);
      expect(repo.consultas, isEmpty);
    });

    test('espera parar de digitar: uma requisição por pausa, não por tecla', () async {
      vm.setConsulta('pok');
      vm.setConsulta('poke');
      vm.setConsulta('pokem');
      expect(vm.estado, EstadoBusca.carregando);

      await _esperar();

      expect(repo.consultas, <String>['pokem']);
    });

    test('manda a consulta sem os espaços das pontas', () async {
      vm.setConsulta('  pokemon  ');
      await _esperar();

      expect(repo.consultas, <String>['pokemon']);
    });

    test('com resultado mostra os títulos', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, _ok(<TmdbItem>[_filme, _serie]));
      await pumpEventQueue();

      expect(vm.estado, EstadoBusca.resultados);
      expect(vm.resultados, <TmdbItem>[_filme, _serie]);
    });

    test('sem resultado vira estado vazio, não lista em branco', () async {
      vm.setConsulta('xyzxyz');
      await _esperar();
      repo.responder(0, _ok(<TmdbItem>[]));
      await pumpEventQueue();

      expect(vm.estado, EstadoBusca.vazio);
    });

    test('erro de rede mostra a frase e permite tentar de novo', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, const Result<List<TmdbItem>>.error(NetworkError()));
      await pumpEventQueue();

      expect(vm.estado, EstadoBusca.erro);
      expect(vm.erro, const NetworkError().mensagem);
      expect(vm.podeTentarDeNovo, isTrue);

      final Future<void> retry = vm.tentarDeNovo();
      expect(vm.estado, EstadoBusca.carregando);
      repo.responder(1, _ok(<TmdbItem>[_serie]));
      await retry;

      expect(vm.estado, EstadoBusca.resultados);
      expect(repo.consultas, <String>['pokemon', 'pokemon']);
    });

    test('limite de requisições aparece como erro, não como tela vazia', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, const Result<List<TmdbItem>>.error(RateLimitError()));
      await pumpEventQueue();

      expect(vm.estado, EstadoBusca.erro);
      expect(vm.erro, const RateLimitError().mensagem);
    });

    test('resposta antiga chegando depois não sobrescreve a consulta nova', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      vm.setConsulta('office');
      await _esperar();

      repo.responder(1, _ok(<TmdbItem>[_serie]));
      await pumpEventQueue();
      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();

      expect(vm.resultados, <TmdbItem>[_serie]);
    });

    test('resposta em voo de consulta apagada não pinta a tela', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      vm.setConsulta('');

      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();

      expect(vm.estado, EstadoBusca.ocioso);
    });

    test('a mesma consulta já respondida não pede de novo', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();

      vm.setConsulta('pokemon ');
      await _esperar();

      expect(repo.consultas, hasLength(1));
      expect(vm.estado, EstadoBusca.resultados);
    });

    test('reset descarta a resposta que ainda estava em voo', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      vm.reset();

      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();

      expect(vm.estado, EstadoBusca.ocioso, reason: 'a tela reaberta começa na dica');
      expect(vm.resultados, isEmpty);
    });

    test('reset cancela a espera: a consulta digitada não sai', () async {
      vm.setConsulta('pokemon');
      vm.reset();
      await _esperar();

      expect(repo.consultas, isEmpty);
    });

    test('cancelar ao sair da tela: nem a espera nem a resposta em voo valem', () async {
      vm.setConsulta('office');
      vm.cancelar();
      await _esperar();
      expect(repo.consultas, isEmpty, reason: 'a espera não pode disparar depois de sair');

      vm.setConsulta('pokemon');
      await _esperar();
      int avisos = 0;
      vm.addListener(() => avisos++);
      vm.cancelar();
      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();

      expect(avisos, 0, reason: 'a resposta de uma tela fechada não notifica ninguém');
    });

    test('depois de um erro, a mesma consulta pede de novo', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, const Result<List<TmdbItem>>.error(NetworkError()));
      await pumpEventQueue();

      vm.setConsulta('pokemon ');
      await _esperar();

      expect(repo.consultas, <String>['pokemon', 'pokemon']);
    });

    test('maiúscula ou minúscula é a mesma busca: não pede de novo', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();

      vm.setConsulta('POKEMON');
      await _esperar();
      vm.setConsulta('Pokemon');
      await _esperar();

      expect(repo.consultas, <String>['pokemon']);
      expect(vm.resultados, <TmdbItem>[_filme]);
    });

    test('espaço no fim durante a espera não pede o mesmo termo duas vezes', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      vm.setConsulta('pokemon ');
      await _esperar();

      expect(repo.consultas, <String>['pokemon']);
      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();
      expect(vm.estado, EstadoBusca.resultados);
    });

    test('repository que lança não deixa a tela girando', () async {
      final SearchViewModel quebrado =
          SearchViewModel(_FakeQueLanca(), espera: const Duration(milliseconds: 10));
      quebrado.setConsulta('pokemon');
      await _esperar();

      expect(quebrado.estado, EstadoBusca.erro);
      expect(quebrado.erro, const ServerError().mensagem);
      quebrado.dispose();
    });

    test('reset limpa a busca anterior sem avisar a View', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();
      vm.setFiltro(TipoFiltro.filmes);

      int avisos = 0;
      vm.addListener(() => avisos++);
      vm.reset();

      expect(vm.estado, EstadoBusca.ocioso);
      expect(vm.consulta, isEmpty);
      expect(vm.filtro, TipoFiltro.todos);
      expect(avisos, 0, reason: 'reset roda no initState: não pode notificar');
    });
  });

  group('SearchViewModel — filtro por tipo (AP-36)', () {
    Future<void> carregar() async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, _ok(<TmdbItem>[_filme, _serie]));
      await pumpEventQueue();
    }

    test('Séries e Filmes filtram o resultado sem nova requisição', () async {
      await carregar();

      vm.setFiltro(TipoFiltro.series);
      expect(vm.resultados, <TmdbItem>[_serie]);

      vm.setFiltro(TipoFiltro.filmes);
      expect(vm.resultados, <TmdbItem>[_filme]);

      vm.setFiltro(TipoFiltro.todos);
      expect(vm.resultados, hasLength(2));
      expect(repo.consultas, hasLength(1));
    });

    test('filtro sem nenhum título do tipo vira estado vazio', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();

      vm.setFiltro(TipoFiltro.series);

      expect(vm.estado, EstadoBusca.vazio);
    });
  });
}
