import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/api_models/titulo_detalhe.dart';
import 'package:appseries/data/api_models/tmdb_item.dart';
import 'package:appseries/data/repositories/feedback_repository.dart';
import 'package:appseries/data/repositories/titulo_repository.dart';
import 'package:appseries/ui/navegacao/titulo_ref.dart';
import 'package:appseries/ui/view_model/title_detail_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cada pedido de ficha fica pendente até o teste responder: é como se prova a
/// corrida entre dois títulos.
class _FakeTitulos implements TituloRepository {
  final List<String> pedidos = <String>[];
  final List<Completer<Result<TituloDetalhe>>> pendentes = <Completer<Result<TituloDetalhe>>>[];

  void responder(int i, Result<TituloDetalhe> r) => pendentes[i].complete(r);

  @override
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId) {
    pedidos.add('${tipo.name}:$tmdbId');
    final Completer<Result<TituloDetalhe>> c = Completer<Result<TituloDetalhe>>();
    pendentes.add(c);
    return c.future;
  }

  @override
  Future<Result<List<TmdbItem>>> buscar(String q) => throw UnimplementedError();

  @override
  Future<Result<List<TmdbItem>>> emAlta() => throw UnimplementedError();

  @override
  Future<Result<List<TmdbItem>>> populares() => throw UnimplementedError();
}

/// Guarda o que foi gravado (sinal, peso, origem) e responde o que o teste mandar.
class _FakeFeedback implements FeedbackRepository {
  _FakeFeedback({this.lista = const Result<List<FeedbackItem>>.ok(<FeedbackItem>[])});

  final Result<List<FeedbackItem>> lista;
  final List<String> gravados = <String>[];
  Result<FeedbackItem>? respostaMarcar;
  Result<void> respostaRemover = const Result<void>.ok(null);

  /// Quando presentes, seguram a resposta até o teste completar.
  Completer<Result<List<FeedbackItem>>>? listaPendente;
  Completer<Result<FeedbackItem>>? marcarPendente;

  @override
  Future<Result<List<FeedbackItem>>> listar() => listaPendente?.future ?? Future.value(lista);

  @override
  Future<Result<FeedbackItem>> marcar(
    TipoMidia tipo,
    int tmdbId,
    SinalGosto sinal, {
    int peso = 2,
    OrigemFeedback origem = OrigemFeedback.fechamento,
  }) async {
    gravados.add('${tipo.name}:$tmdbId ${sinal.name} peso $peso ${origem.name}');
    if (marcarPendente != null) return marcarPendente!.future;
    return respostaMarcar ??
        Result<FeedbackItem>.ok(
          FeedbackItem(tmdbId: tmdbId, sinal: sinal, peso: peso, origem: origem, tipo: tipo),
        );
  }

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) async {
    gravados.add('remover ${tipo.name}:$tmdbId');
    return respostaRemover;
  }
}

const TituloRef _got = TituloRef(tipo: TipoMidia.tv, id: 1399);

const TituloDetalhe _ficha = TituloDetalhe(
  id: 1399,
  tipo: TipoMidia.tv,
  titulo: 'Game of Thrones',
  ano: '2011',
  sinopse: 'Nove famílias nobres lutam pelo controle de Westeros.',
  nota: 8.4,
  generos: <String>['Drama', 'Fantasia'],
);

Future<(TitleDetailViewModel, _FakeTitulos, _FakeFeedback)> _aberto({_FakeFeedback? feedback}) async {
  final _FakeTitulos titulos = _FakeTitulos();
  final _FakeFeedback fb = feedback ?? _FakeFeedback();
  final TitleDetailViewModel vm = TitleDetailViewModel(titulos, fb);
  final Future<void> carga = vm.load(_got);
  titulos.responder(0, const Result<TituloDetalhe>.ok(_ficha));
  await carga;
  return (vm, titulos, fb);
}

void main() {
  group('TitleDetailViewModel — ficha (AP-47)', () {
    test('começa carregando, pede o par que recebeu e mostra a ficha', () async {
      final _FakeTitulos titulos = _FakeTitulos();
      final TitleDetailViewModel vm = TitleDetailViewModel(titulos, _FakeFeedback());
      expect(vm.carregando, isTrue);

      final Future<void> carga = vm.load(_got);
      expect(titulos.pedidos, <String>['tv:1399'], reason: 'sem o tipo o backend responde 400');
      titulos.responder(0, const Result<TituloDetalhe>.ok(_ficha));
      await carga;

      expect(vm.carregando, isFalse);
      expect(vm.erro, isNull);
      expect(vm.detalhe?.titulo, 'Game of Thrones');
    });

    test('erro mostra a frase, para de carregar e permite tentar de novo', () async {
      final _FakeTitulos titulos = _FakeTitulos();
      final TitleDetailViewModel vm = TitleDetailViewModel(titulos, _FakeFeedback());

      final Future<void> carga = vm.load(_got);
      titulos.responder(0, const Result<TituloDetalhe>.error(CatalogoIndisponivelError()));
      await carga;

      expect(vm.carregando, isFalse, reason: 'nunca a impressão de travamento (AP-79)');
      expect(vm.erro, const CatalogoIndisponivelError().mensagem);
      expect(vm.podeTentarDeNovo, isTrue);

      final Future<void> retry = vm.tentarDeNovo();
      expect(vm.carregando, isTrue);
      titulos.responder(1, const Result<TituloDetalhe>.ok(_ficha));
      await retry;

      expect(vm.detalhe?.titulo, 'Game of Thrones');
      expect(titulos.pedidos, <String>['tv:1399', 'tv:1399']);
    });

    test('nova falha depois do retry volta a oferecer o retry', () async {
      final _FakeTitulos titulos = _FakeTitulos();
      final TitleDetailViewModel vm = TitleDetailViewModel(titulos, _FakeFeedback());

      final Future<void> carga = vm.load(_got);
      titulos.responder(0, const Result<TituloDetalhe>.error(CatalogoIndisponivelError()));
      await carga;
      final Future<void> retry = vm.tentarDeNovo();
      titulos.responder(1, const Result<TituloDetalhe>.error(CatalogoIndisponivelError()));
      await retry;

      expect(vm.carregando, isFalse);
      expect(vm.podeTentarDeNovo, isTrue);
    });

    test('rota sem par vira erro sem retry, sem pedir nada ao servidor', () async {
      final _FakeTitulos titulos = _FakeTitulos();
      final TitleDetailViewModel vm = TitleDetailViewModel(titulos, _FakeFeedback());

      await vm.load(null);

      expect(vm.erro, const TituloIndisponivelError().mensagem);
      expect(vm.podeTentarDeNovo, isFalse);
      expect(titulos.pedidos, isEmpty);
    });

    test('a resposta de um título antigo não pinta o título novo', () async {
      final _FakeTitulos titulos = _FakeTitulos();
      final TitleDetailViewModel vm = TitleDetailViewModel(titulos, _FakeFeedback());

      final Future<void> primeira = vm.load(_got);
      final Future<void> segunda = vm.load(const TituloRef(tipo: TipoMidia.movie, id: 550));
      titulos.responder(1, const Result<TituloDetalhe>.ok(
        TituloDetalhe(id: 550, tipo: TipoMidia.movie, titulo: 'Clube da Luta'),
      ));
      await segunda;
      titulos.responder(0, const Result<TituloDetalhe>.ok(_ficha));
      await primeira;

      expect(vm.detalhe?.titulo, 'Clube da Luta');
    });

    test('o reset limpa o título anterior sem avisar a View', () async {
      final (TitleDetailViewModel vm, _, _) = await _aberto();
      int avisos = 0;
      vm.addListener(() => avisos++);

      vm.reset();

      expect(vm.detalhe, isNull);
      expect(vm.carregando, isTrue, reason: 'o primeiro frame é o spinner, não o título antigo');
      expect(vm.sinal, isNull);
      expect(avisos, 0);
    });

    test('lê o sinal que ela já deu neste par, e só neste', () async {
      final (TitleDetailViewModel vm, _, _) = await _aberto(
        feedback: _FakeFeedback(
          lista: const Result<List<FeedbackItem>>.ok(<FeedbackItem>[
            FeedbackItem(tmdbId: 1399, sinal: SinalGosto.dislike, tipo: TipoMidia.movie),
            FeedbackItem(tmdbId: 1399, sinal: SinalGosto.like, tipo: TipoMidia.tv),
          ]),
        ),
      );

      expect(vm.sinal, SinalGosto.like, reason: 'o filme 1399 não é a série 1399');
    });

    test('a ficha aparece sem esperar o sinal de gosto', () async {
      final _FakeTitulos titulos = _FakeTitulos();
      final _FakeFeedback fb = _FakeFeedback()
        ..listaPendente = Completer<Result<List<FeedbackItem>>>();
      final TitleDetailViewModel vm = TitleDetailViewModel(titulos, fb);

      unawaited(vm.load(_got));
      titulos.responder(0, const Result<TituloDetalhe>.ok(_ficha));
      await pumpEventQueue();

      expect(vm.carregando, isFalse, reason: 'um /feedback lento não pode segurar a ficha');
      expect(vm.detalhe?.titulo, 'Game of Thrones');

      fb.listaPendente!.complete(const Result<List<FeedbackItem>>.ok(<FeedbackItem>[
        FeedbackItem(tmdbId: 1399, sinal: SinalGosto.like, tipo: TipoMidia.tv),
      ]));
      await pumpEventQueue();
      expect(vm.sinal, SinalGosto.like, reason: 'o sinal chega depois e entra');
    });

    test('o sinal lido na abertura não sobrescreve o toque que ela já deu', () async {
      final _FakeTitulos titulos = _FakeTitulos();
      final _FakeFeedback fb = _FakeFeedback()
        ..listaPendente = Completer<Result<List<FeedbackItem>>>();
      final TitleDetailViewModel vm = TitleDetailViewModel(titulos, fb);

      unawaited(vm.load(_got));
      titulos.responder(0, const Result<TituloDetalhe>.ok(_ficha));
      await pumpEventQueue();
      await vm.darSinal(SinalGosto.dislike, estado: EstadoAcervo.watched);

      fb.listaPendente!.complete(const Result<List<FeedbackItem>>.ok(<FeedbackItem>[
        FeedbackItem(tmdbId: 1399, sinal: SinalGosto.like, tipo: TipoMidia.tv),
      ]));
      await pumpEventQueue();

      expect(vm.sinal, SinalGosto.dislike);
    });

    test('falha ao ler o sinal não derruba a ficha', () async {
      final (TitleDetailViewModel vm, _, _) = await _aberto(
        feedback: _FakeFeedback(lista: const Result<List<FeedbackItem>>.error(NetworkError())),
      );

      expect(vm.erro, isNull);
      expect(vm.detalhe, isNotNull);
      expect(vm.sinal, isNull);
    });
  });

  group('TitleDetailViewModel — 👍/👎 (AP-48)', () {
    test('👍 depois de assistido grava like, peso 2, origem fechamento', () async {
      final (TitleDetailViewModel vm, _, _FakeFeedback fb) = await _aberto();

      final AppError? erro = await vm.darSinal(SinalGosto.like, estado: EstadoAcervo.watched);

      expect(erro, isNull);
      expect(fb.gravados, <String>['tv:1399 like peso 2 fechamento']);
      expect(vm.sinal, SinalGosto.like);
    });

    test('"não curti" no abandono grava dislike, peso 2, origem abandono', () async {
      final (TitleDetailViewModel vm, _, _FakeFeedback fb) = await _aberto();

      await vm.darSinal(SinalGosto.dislike, estado: EstadoAcervo.dropped);

      expect(fb.gravados, <String>['tv:1399 dislike peso 2 abandono']);
      expect(vm.sinal, SinalGosto.dislike);
    });

    test('👍 depois de abandonar continua com origem fechamento (só o "não curti" é abandono)',
        () async {
      final (TitleDetailViewModel vm, _, _FakeFeedback fb) = await _aberto();

      await vm.darSinal(SinalGosto.like, estado: EstadoAcervo.dropped);

      expect(fb.gravados, <String>['tv:1399 like peso 2 fechamento']);
    });

    test('o 👍 de um título não aparece no título aberto depois', () async {
      final _FakeTitulos titulos = _FakeTitulos();
      final _FakeFeedback fb = _FakeFeedback()..marcarPendente = Completer<Result<FeedbackItem>>();
      final TitleDetailViewModel vm = TitleDetailViewModel(titulos, fb);
      final Future<void> a = vm.load(_got);
      titulos.responder(0, const Result<TituloDetalhe>.ok(_ficha));
      await a;

      final Future<AppError?> sinalDeA = vm.darSinal(SinalGosto.like, estado: EstadoAcervo.watched);
      final Future<void> b = vm.load(const TituloRef(tipo: TipoMidia.movie, id: 550));
      titulos.responder(1, const Result<TituloDetalhe>.ok(
        TituloDetalhe(id: 550, tipo: TipoMidia.movie, titulo: 'Clube da Luta'),
      ));
      await b;
      fb.marcarPendente!.complete(const Result<FeedbackItem>.ok(
        FeedbackItem(tmdbId: 1399, sinal: SinalGosto.like, tipo: TipoMidia.tv),
      ));
      await sinalDeA;

      expect(vm.detalhe?.titulo, 'Clube da Luta');
      expect(vm.sinal, isNull);
      expect(vm.enviandoSinal, isFalse);
    });

    test('tocar no sinal que já está dado desfaz, com o tipo na chamada', () async {
      final (TitleDetailViewModel vm, _, _FakeFeedback fb) = await _aberto();
      await vm.darSinal(SinalGosto.like, estado: EstadoAcervo.watched);

      await vm.darSinal(SinalGosto.like, estado: EstadoAcervo.watched);

      expect(fb.gravados.last, 'remover tv:1399');
      expect(vm.sinal, isNull);
    });

    test('desfazer um sinal que já não existia (404) conta como desfeito', () async {
      final (TitleDetailViewModel vm, _, _FakeFeedback fb) = await _aberto();
      await vm.darSinal(SinalGosto.like, estado: EstadoAcervo.watched);
      fb.respostaRemover = const Result<void>.error(NotFoundError());

      final AppError? erro = await vm.darSinal(SinalGosto.like, estado: EstadoAcervo.watched);

      expect(erro, isNull);
      expect(vm.sinal, isNull);
    });

    test('erro 400 nunca é engolido: devolve o erro e mantém o sinal anterior', () async {
      final (TitleDetailViewModel vm, _, _FakeFeedback fb) = await _aberto();
      await vm.darSinal(SinalGosto.like, estado: EstadoAcervo.watched);
      fb.respostaMarcar = const Result<FeedbackItem>.error(FeedbackIndisponivelError());

      final AppError? erro = await vm.darSinal(SinalGosto.dislike, estado: EstadoAcervo.watched);

      expect(erro, isA<FeedbackIndisponivelError>());
      expect(vm.sinal, SinalGosto.like);
      expect(vm.enviandoSinal, isFalse);
    });

    test('sem ficha carregada não grava nada', () async {
      final _FakeFeedback fb = _FakeFeedback();
      final TitleDetailViewModel vm = TitleDetailViewModel(_FakeTitulos(), fb);

      final AppError? erro = await vm.darSinal(SinalGosto.like, estado: EstadoAcervo.watched);

      expect(erro, isNull);
      expect(fb.gravados, isEmpty);
    });
  });
}
