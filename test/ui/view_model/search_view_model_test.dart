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

    test('limite do TMDB aparece como erro com retry, não como tela vazia', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, const Result<List<TmdbItem>>.error(CatalogoOcupadoError()));
      await pumpEventQueue();

      expect(vm.estado, EstadoBusca.erro);
      expect(vm.erro, const CatalogoOcupadoError().mensagem);
      expect(vm.podeTentarDeNovo, isTrue, reason: 'o limite do TMDB passa em segundos');
    });

    test('Enter busca na hora, sem esperar a pausa', () async {
      final SearchViewModel lento = SearchViewModel(repo, espera: const Duration(hours: 1));
      lento.setConsulta('pokemon');
      expect(repo.consultas, isEmpty);

      lento.buscarAgora();
      await pumpEventQueue();

      expect(repo.consultas, <String>['pokemon']);
      lento.buscarAgora();
      await pumpEventQueue();
      expect(repo.consultas, hasLength(1), reason: 'a consulta já está no ar');
      lento.dispose();
    });

    test('Enter com menos de 3 letras não sai do app', () async {
      vm.setConsulta('po');
      vm.buscarAgora();
      await _esperar();

      expect(repo.consultas, isEmpty);
    });

    // P3 do #13: o guard antigo saía sempre que não havia timer, e "nada
    // pendente" incluía "já respondido". Enter é "buscar": depois de uma
    // resposta ou de um erro, pergunta de novo.
    test('Enter depois da resposta refaz a busca, sem perder consulta nem filtro', () async {
      vm.setConsulta('pokemon');
      vm.setFiltro(TipoFiltro.series);
      await _esperar();
      repo.responder(0, _ok(<TmdbItem>[_filme, _serie]));
      await pumpEventQueue();
      expect(vm.resultados, <TmdbItem>[_serie]);

      vm.buscarAgora();
      await pumpEventQueue();

      expect(repo.consultas, <String>['pokemon', 'pokemon']);
      expect(vm.estado, EstadoBusca.carregando,
          reason: 'a lista antiga não fica na tela fingindo ser a resposta nova');

      repo.responder(1, _ok(<TmdbItem>[_serie, _filme]));
      await pumpEventQueue();

      expect(vm.estado, EstadoBusca.resultados);
      expect(vm.resultados, <TmdbItem>[_serie], reason: 'o filtro de séries continua valendo');
      expect(vm.consulta, 'pokemon');
      expect(vm.filtro, TipoFiltro.series);
    });

    test('Enter depois de um erro refaz a busca', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, const Result<List<TmdbItem>>.error(ServerError()));
      await pumpEventQueue();
      expect(vm.estado, EstadoBusca.erro);

      vm.buscarAgora();
      await pumpEventQueue();

      expect(repo.consultas, <String>['pokemon', 'pokemon']);
      expect(vm.erro, isNull, reason: 'o erro antigo sai enquanto pergunta de novo');

      repo.responder(1, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();
      expect(vm.resultados, <TmdbItem>[_filme]);
    });

    test('Enter repetido com a busca já no ar não manda outra', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();

      vm.buscarAgora();
      vm.buscarAgora();
      await pumpEventQueue();

      expect(repo.consultas, <String>['pokemon', 'pokemon'],
          reason: 'a segunda tecla chega com a primeira ainda em voo');
    });

    test('Enter não repete consulta que o servidor recusou como inválida', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      repo.responder(0, const Result<List<TmdbItem>>.error(BuscaInvalidaError()));
      await pumpEventQueue();
      expect(vm.podeTentarDeNovo, isFalse);

      vm.buscarAgora();
      await pumpEventQueue();

      expect(repo.consultas, <String>['pokemon'], reason: 'mandaria o mesmo 400 de novo');
      expect(vm.erro, const BuscaInvalidaError().mensagem);
    });

    test('depois de cancelar(), nada conta como pendente: Enter pergunta de novo', () async {
      vm.setConsulta('pokemon');
      await _esperar();
      expect(repo.consultas, <String>['pokemon']);
      vm.cancelar();

      vm.buscarAgora();
      await pumpEventQueue();

      expect(repo.consultas, <String>['pokemon', 'pokemon'],
          reason: 'a cancelada não volta a pintar a tela, então nada está pendente');
      repo.responder(0, _ok(<TmdbItem>[_serie]));
      repo.responder(1, _ok(<TmdbItem>[_filme]));
      await pumpEventQueue();
      expect(vm.resultados, <TmdbItem>[_filme]);
    });

    test('Enter com consulta longa demais não sai do app', () async {
      vm.setConsulta('a' * (kBuscaMax + 1));
      vm.buscarAgora();
      await _esperar();

      expect(repo.consultas, isEmpty);
      expect(vm.erro, const BuscaInvalidaError().mensagem,
          reason: 'repetir uma consulta inválida falha igual');
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
