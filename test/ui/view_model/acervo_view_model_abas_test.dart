import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/ui/view_model/acervo_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lista fixa na leitura; gravações ficam pendentes até o teste responder.
class _FakeAcervo implements AcervoRepository {
  _FakeAcervo(this.inicial);

  final List<AcervoItem> inicial;
  final List<Completer<Result<AcervoItem>>> marcacoes = <Completer<Result<AcervoItem>>>[];
  final List<Completer<Result<void>>> remocoes = <Completer<Result<void>>>[];

  @override
  Future<Result<List<AcervoItem>>> listar() async => Result<List<AcervoItem>>.ok(inicial);

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) {
    final Completer<Result<AcervoItem>> c = Completer<Result<AcervoItem>>();
    marcacoes.add(c);
    return c.future;
  }

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) {
    final Completer<Result<void>> c = Completer<Result<void>>();
    remocoes.add(c);
    return c.future;
  }
}

/// Linha completa, como o servidor devolve.
AcervoItem _linha(int id, EstadoAcervo estado, {TipoMidia? tipo = TipoMidia.movie}) => AcervoItem(
  tmdbId: id,
  estado: estado,
  tipo: tipo,
  titulo: 'Título $id',
  ano: '20${id.toString().padLeft(2, '0')}',
  posterPath: '/p$id.jpg',
  atualizadoEm: DateTime.utc(2026, 10, id),
);

Future<AcervoViewModel> _carregado(List<AcervoItem> itens) async {
  final AcervoViewModel vm = AcervoViewModel(_FakeAcervo(itens));
  await vm.load();
  return vm;
}

List<int> _ids(List<AcervoItem> itens) => itens.map((AcervoItem i) => i.tmdbId).toList();

void main() {
  group('AcervoViewModel — abas (AP-59)', () {
    test('cada estado vai para a sua aba; abandonado fica com o assistido', () async {
      final AcervoViewModel vm = await _carregado(<AcervoItem>[
        _linha(1, EstadoAcervo.planToWatch),
        _linha(2, EstadoAcervo.watched),
        _linha(3, EstadoAcervo.watching),
        _linha(4, EstadoAcervo.dropped),
        _linha(5, EstadoAcervo.planToWatch, tipo: TipoMidia.tv),
      ]);

      expect(_ids(vm.queroVer), <int>[1, 5]);
      expect(_ids(vm.assistindo), <int>[3]);
      expect(_ids(vm.assistidos), <int>[2, 4], reason: 'AP-58: o abandonado é um título fechado');
    });

    test('a aba mantém a ordem do servidor (mais recente primeiro) e a linha inteira', () async {
      final AcervoViewModel vm = await _carregado(<AcervoItem>[
        _linha(9, EstadoAcervo.watched),
        _linha(3, EstadoAcervo.watched),
        _linha(7, EstadoAcervo.watched),
      ]);

      expect(_ids(vm.assistidos), <int>[9, 3, 7], reason: 'não reordena por id nem por título');
      final AcervoItem primeira = vm.assistidos.first;
      expect(primeira.titulo, 'Título 9');
      expect(primeira.ano, '2009');
      expect(primeira.posterPath, '/p9.jpg');
      expect(primeira.atualizadoEm, DateTime.utc(2026, 10, 9));
    });

    test('acervo vazio: as três abas vazias', () async {
      final AcervoViewModel vm = await _carregado(const <AcervoItem>[]);

      expect(vm.queroVer, isEmpty);
      expect(vm.assistindo, isEmpty);
      expect(vm.assistidos, isEmpty);
    });

    test('estado que o app não conhece não entra em aba nenhuma, mas conta no total', () async {
      final AcervoViewModel vm = await _carregado(<AcervoItem>[
        _linha(1, EstadoAcervo.desconhecido),
        _linha(2, EstadoAcervo.watching),
      ]);

      expect(_ids(vm.queroVer) + _ids(vm.assistindo) + _ids(vm.assistidos), <int>[2]);
      expect(vm.total, 2);
    });

    test('linha antiga sem tipo aparece sozinha; com a tipada do mesmo id, só a tipada', () async {
      final AcervoViewModel sozinha = await _carregado(<AcervoItem>[
        _linha(1, EstadoAcervo.watched, tipo: null),
      ]);
      expect(_ids(sozinha.assistidos), <int>[1]);

      final AcervoViewModel comTipada = await _carregado(<AcervoItem>[
        _linha(1, EstadoAcervo.watching, tipo: TipoMidia.tv),
        _linha(1, EstadoAcervo.watched, tipo: null),
        _linha(2, EstadoAcervo.watched, tipo: TipoMidia.desconhecido),
      ]);
      expect(_ids(comTipada.assistindo), <int>[1]);
      expect(_ids(comTipada.assistidos), <int>[
        2,
      ], reason: 'a antiga do id 1 não pode aparecer de novo em outra aba');
    });

    test('duas linhas antigas sem tipo do mesmo id: só a última, a que o estadoDe lê', () async {
      final AcervoViewModel vm = await _carregado(<AcervoItem>[
        _linha(1, EstadoAcervo.watched, tipo: null),
        _linha(1, EstadoAcervo.watching, tipo: null),
      ]);

      expect(vm.estadoDe(TipoMidia.movie, 1), EstadoAcervo.watching);
      expect(_ids(vm.assistindo), <int>[1]);
      expect(vm.assistidos, isEmpty, reason: 'o mesmo título não aparece em duas abas');
    });

    test('marcar muda o título de aba na hora, e a falha devolve', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[_linha(1, EstadoAcervo.watching)]);
      final AcervoViewModel vm = AcervoViewModel(repo);
      await vm.load();

      final Future<AppError?> gravando = vm.marcar(TipoMidia.movie, 1, EstadoAcervo.watched);
      expect(vm.assistindo, isEmpty);
      expect(_ids(vm.assistidos), <int>[1]);
      expect(
        vm.assistidos.single.titulo,
        'Título 1',
        reason: 'a linha não perde a ficha ao mudar de aba',
      );

      repo.marcacoes.single.complete(const Result<AcervoItem>.error(NetworkError()));
      await gravando;

      expect(_ids(vm.assistindo), <int>[1]);
      expect(vm.assistidos, isEmpty);
    });

    test('remover tira o título da aba na hora', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[
        _linha(1, EstadoAcervo.planToWatch),
        _linha(2, EstadoAcervo.planToWatch),
      ]);
      final AcervoViewModel vm = AcervoViewModel(repo);
      await vm.load();

      unawaited(vm.remover(TipoMidia.movie, 1));

      expect(_ids(vm.queroVer), <int>[2]);
    });

    test('as abas são só leitura: a tela não consegue mexer na lista', () async {
      final AcervoViewModel vm = await _carregado(<AcervoItem>[_linha(1, EstadoAcervo.watching)]);

      expect(() => vm.assistindo.clear(), throwsUnsupportedError);
    });
  });

  group('AcervoViewModel.historico (AP-73)', () {
    AcervoItem assistido(
      int id,
      DateTime? em, {
      EstadoAcervo estado = EstadoAcervo.watched,
      TipoMidia? tipo = TipoMidia.movie,
    }) => AcervoItem(
      tmdbId: id,
      estado: estado,
      tipo: tipo,
      titulo: 'Título $id',
      ano: '2010',
      posterPath: '/p$id.jpg',
      atualizadoEm: em,
    );

    test('só os assistidos, do marcado mais recente para o mais antigo', () async {
      final AcervoViewModel vm = await _carregado(<AcervoItem>[
        // ordem do servidor diferente da ordem das datas, de propósito
        assistido(1, DateTime.utc(2026, 10, 5)),
        assistido(2, DateTime.utc(2026, 10, 20)),
        assistido(3, DateTime.utc(2026, 10, 9), estado: EstadoAcervo.dropped),
        assistido(4, DateTime.utc(2026, 10, 30), estado: EstadoAcervo.watching),
        assistido(5, DateTime.utc(2026, 10, 12), tipo: TipoMidia.tv),
      ]);

      expect(
        _ids(vm.historico),
        <int>[2, 5, 1],
        reason: 'abandonado não foi assistido até o fim; "Assistindo" ainda não acabou',
      );
      expect(vm.historico.first.titulo, 'Título 2');
      expect(vm.historico.first.posterPath, '/p2.jpg');
    });

    test('assistido sem data vai para o fim, na ordem do servidor', () async {
      final AcervoViewModel vm = await _carregado(<AcervoItem>[
        assistido(7, null),
        assistido(1, DateTime.utc(2026, 10, 5)),
        assistido(6, null),
        assistido(2, DateTime.utc(2026, 10, 20)),
      ]);

      expect(_ids(vm.historico), <int>[2, 1, 7, 6]);
    });

    test('mesmo instante: vale a ordem do servidor', () async {
      final DateTime mesmo = DateTime.utc(2026, 10, 20, 12);
      final AcervoViewModel vm = await _carregado(<AcervoItem>[
        for (int id = 1; id <= 40; id++) assistido(id, mesmo),
      ]);

      expect(_ids(vm.historico), <int>[for (int id = 1; id <= 40; id++) id]);
    });

    test('linha antiga sem tipo segue a regra das abas', () async {
      final AcervoViewModel vm = await _carregado(<AcervoItem>[
        assistido(1, DateTime.utc(2026, 10, 20), tipo: TipoMidia.tv),
        assistido(1, DateTime.utc(2025, 1, 1), tipo: null),
        assistido(2, DateTime.utc(2025, 1, 2), tipo: null),
      ]);

      expect(_ids(vm.historico), <int>[1, 2]);
      expect(vm.historico.first.tipo, TipoMidia.tv, reason: 'a antiga do id 1 não aparece de novo');
    });

    test('marcar "Assistido" põe o título no topo na hora; a falha tira', () async {
      final _FakeAcervo repo = _FakeAcervo(<AcervoItem>[
        assistido(1, DateTime.utc(2026, 10, 20)),
        assistido(2, DateTime.utc(2026, 10, 5), estado: EstadoAcervo.watching),
      ]);
      final AcervoViewModel vm = AcervoViewModel(repo, agora: () => DateTime.utc(2026, 10, 31));
      await vm.load();

      final Future<AppError?> gravando = vm.marcar(TipoMidia.movie, 2, EstadoAcervo.watched);
      expect(_ids(vm.historico), <int>[2, 1], reason: 'a data provisória é agora');

      repo.marcacoes.single.complete(const Result<AcervoItem>.error(NetworkError()));
      await gravando;
      expect(_ids(vm.historico), <int>[1]);
    });

    test('o histórico é só leitura', () async {
      final AcervoViewModel vm = await _carregado(<AcervoItem>[assistido(1, DateTime.utc(2026))]);

      expect(() => vm.historico.clear(), throwsUnsupportedError);
    });
  });
}
