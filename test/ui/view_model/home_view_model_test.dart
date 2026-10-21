import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/view_model/home_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

/// Fura o contrato em "em alta" e responde normal em "populares".
class _FakeQueLanca implements TituloRepository {
  @override
  Future<Result<List<TmdbItem>>> emAlta() async => throw const FormatException('contrato furado');

  @override
  Future<Result<List<TmdbItem>>> populares() async =>
      Result<List<TmdbItem>>.ok(<TmdbItem>[_item(9)]);
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

    test('a segunda carga não devolve os títulos da sessão anterior', () async {
      final repo = _FakeTituloRepository(
        respostaEmAlta: _ok(<int>[1, 2, 3]),
        respostaPopulares: _ok(<int>[4, 5, 6]),
      );
      final vm = HomeViewModel(repo);

      await vm.load();
      expect(vm.emAlta.itens, hasLength(3));

      repo.respostaEmAlta = _ok(<int>[]);
      repo.respostaPopulares = _ok(<int>[]);
      await vm.load();

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
      expect(avisos, 0, reason: 'reset roda no initState: não pode notificar');
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
