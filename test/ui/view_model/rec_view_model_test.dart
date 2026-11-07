import 'dart:async';

import 'package:appseries/data/api_models/carta_rec.dart';
import 'package:appseries/data/repositories/rec_repository.dart';
import 'package:appseries/ui/view_model/rec_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRec implements RecRepository {
  _FakeRec(this.respostas);

  final List<Future<Result<RecResult>>> respostas;
  int chamadas = 0;
  String? ultimoMomento;

  @override
  Future<Result<RecResult>> recomendar({String? momento}) {
    ultimoMomento = momento;
    final int i = chamadas < respostas.length ? chamadas : respostas.length - 1;
    chamadas++;
    return respostas[i];
  }
}

Result<RecResult> _ok(List<CartaRec> cartas, {OrigemRec origem = OrigemRec.llm}) =>
    Result<RecResult>.ok(RecResult(cartas: cartas, origem: origem));

const CartaRec _carta = CartaRec(
  tmdbId: 1399,
  tipo: TipoMidia.tv,
  titulo: 'Game of Thrones',
  ano: '2011',
  justificativa: 'Combina com o seu momento',
);

void main() {
  group('RecViewModel', () {
    test('abre ocioso: nenhuma chamada antes de gerar', () {
      final _FakeRec repo = _FakeRec(<Future<Result<RecResult>>>[
        Future<Result<RecResult>>.value(_ok(<CartaRec>[_carta])),
      ]);
      final RecViewModel vm = RecViewModel(repo);

      expect(vm.carregando, isFalse);
      expect(vm.cartas, isEmpty);
      expect(vm.semCartas, isFalse, reason: 'ainda não carregou, então não é "nada encontrado"');
      expect(repo.chamadas, 0);
    });

    test('gerar guarda as cartas, a origem e repassa o momento', () async {
      final _FakeRec repo = _FakeRec(<Future<Result<RecResult>>>[
        Future<Result<RecResult>>.value(_ok(<CartaRec>[_carta], origem: OrigemRec.emAlta)),
      ]);
      final RecViewModel vm = RecViewModel(repo);

      await vm.gerar(momento: 'algo leve');

      expect(vm.carregando, isFalse);
      expect(vm.erro, isNull);
      expect(vm.cartas.single.titulo, 'Game of Thrones');
      expect(vm.origem, OrigemRec.emAlta);
      expect(repo.ultimoMomento, 'algo leve');
    });

    test('lista vazia é "sem cartas", não erro', () async {
      final _FakeRec repo = _FakeRec(<Future<Result<RecResult>>>[
        Future<Result<RecResult>>.value(_ok(const <CartaRec>[])),
      ]);
      final RecViewModel vm = RecViewModel(repo);

      await vm.gerar();

      expect(vm.semCartas, isTrue);
      expect(vm.erro, isNull);
    });

    test('erro vira frase na tela e limpa as cartas anteriores', () async {
      final _FakeRec repo = _FakeRec(<Future<Result<RecResult>>>[
        Future<Result<RecResult>>.value(_ok(<CartaRec>[_carta])),
        Future<Result<RecResult>>.value(
          const Result<RecResult>.error(RateLimitError()),
        ),
      ]);
      final RecViewModel vm = RecViewModel(repo);

      await vm.gerar();
      expect(vm.cartas, hasLength(1));

      await vm.gerar();

      expect(vm.cartas, isEmpty);
      expect(vm.erro, const RateLimitError().mensagem);
      expect(vm.semCartas, isFalse, reason: 'erro não é "nada encontrado"');
    });

    test('toque duplo não gasta duas das 20 do dia', () async {
      final Completer<Result<RecResult>> pendente = Completer<Result<RecResult>>();
      final _FakeRec repo = _FakeRec(<Future<Result<RecResult>>>[pendente.future]);
      final RecViewModel vm = RecViewModel(repo);

      final Future<void> primeira = vm.gerar(momento: 'a');
      final Future<void> segunda = vm.gerar(momento: 'b');

      expect(repo.chamadas, 1, reason: 'a segunda chamada sai antes da primeira responder');

      pendente.complete(_ok(<CartaRec>[_carta]));
      await primeira;
      await segunda;
      expect(vm.carregando, isFalse);
      expect(repo.ultimoMomento, 'a');
    });

    test('teto do dia não oferece retry; falha de rede oferece', () async {
      final _FakeRec repo = _FakeRec(<Future<Result<RecResult>>>[
        Future<Result<RecResult>>.value(const Result<RecResult>.error(RateLimitError())),
        Future<Result<RecResult>>.value(const Result<RecResult>.error(NetworkError())),
      ]);
      final RecViewModel vm = RecViewModel(repo);

      await vm.gerar();
      expect(vm.podeTentarDeNovo, isFalse, reason: 'o 429 responde igual até amanhã');

      await vm.gerar();
      expect(vm.podeTentarDeNovo, isTrue, reason: 'a rede pode voltar');
    });

    test('reset descarta a resposta da sessão anterior', () async {
      final Completer<Result<RecResult>> emVoo = Completer<Result<RecResult>>();
      final _FakeRec repo = _FakeRec(<Future<Result<RecResult>>>[emVoo.future]);
      final RecViewModel vm = RecViewModel(repo);

      final Future<void> chamada = vm.gerar(momento: 'antiga');
      vm.reset();
      emVoo.complete(_ok(<CartaRec>[_carta]));
      await chamada;

      expect(vm.cartas, isEmpty, reason: 'a resposta da conta anterior não pode repovoar a tela');
      expect(vm.carregando, isFalse, reason: 'o reset já desligou o carregando');
    });
  });
}
