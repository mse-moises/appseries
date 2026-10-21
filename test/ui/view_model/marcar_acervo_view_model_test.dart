import 'dart:async';

import 'package:appseries/data/api_models/acervo_item.dart';
import 'package:appseries/data/api_models/feedback_item.dart';
import 'package:appseries/data/api_models/motivo_abandono.dart';
import 'package:appseries/data/repositories/acervo_repository.dart';
import 'package:appseries/data/repositories/feedback_repository.dart';
import 'package:appseries/ui/view_model/marcar_acervo_view_model.dart';
import 'package:appseries/utils/app_error.dart';
import 'package:appseries/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dublê do acervo: guarda o que foi mandado e deixa o teste escolher a
/// resposta. Um `Completer` segura a resposta para testar reentrância.
class _FakeAcervoRepository implements AcervoRepository {
  _FakeAcervoRepository({this.resposta, this.lanca});

  Result<AcervoItem>? resposta;
  Object? lanca;
  Completer<void>? segurar;

  final List<String> chamadas = <String>[];
  TipoMidia? tipoRecebido;
  int? idRecebido;
  EstadoAcervo? estadoRecebido;

  @override
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) async {
    chamadas.add('marcar');
    tipoRecebido = tipo;
    idRecebido = tmdbId;
    estadoRecebido = estado;
    if (segurar != null) await segurar!.future;
    if (lanca != null) throw lanca!;
    return resposta!;
  }

  @override
  Future<Result<List<AcervoItem>>> listar() async =>
      const Result<List<AcervoItem>>.ok(<AcervoItem>[]);

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

/// Dublê do gosto: registra exatamente o que o ViewModel mandou.
class _FakeFeedbackRepository implements FeedbackRepository {
  _FakeFeedbackRepository({this.resposta, this.lanca});

  Result<FeedbackItem>? resposta;
  Object? lanca;

  final List<String> chamadas = <String>[];
  TipoMidia? tipoRecebido;
  int? idRecebido;
  SinalGosto? sinalRecebido;
  int? pesoRecebido;
  OrigemFeedback? origemRecebida;

  @override
  Future<Result<FeedbackItem>> marcar(
    TipoMidia tipo,
    int tmdbId,
    SinalGosto sinal, {
    int peso = 2,
    OrigemFeedback origem = OrigemFeedback.fechamento,
  }) async {
    chamadas.add('marcar');
    tipoRecebido = tipo;
    idRecebido = tmdbId;
    sinalRecebido = sinal;
    pesoRecebido = peso;
    origemRecebida = origem;
    if (lanca != null) throw lanca!;
    return resposta!;
  }

  @override
  Future<Result<List<FeedbackItem>>> listar() async =>
      const Result<List<FeedbackItem>>.ok(<FeedbackItem>[]);

  @override
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId) => throw UnimplementedError();
}

AcervoItem _item({EstadoAcervo estado = EstadoAcervo.dropped}) =>
    AcervoItem(tmdbId: 550, estado: estado, tipo: TipoMidia.movie);

FeedbackItem _sinal({int peso = 2}) => FeedbackItem(
      tmdbId: 550,
      sinal: SinalGosto.dislike,
      peso: peso,
      origem: OrigemFeedback.abandono,
      tipo: TipoMidia.movie,
    );

void main() {
  group('MotivoAbandono', () {
    test('os pesos são os do contrato: sem tempo é fraco, não gostei é forte', () {
      expect(MotivoAbandono.semTempo.peso, 1);
      expect(MotivoAbandono.naoGostei.peso, 2);
    });
  });

  group('MarcarAcervoViewModel', () {
    test('marca o estado escolhido e não grava gosto fora do abandono', () async {
      final _FakeAcervoRepository acervo =
          _FakeAcervoRepository(resposta: Result<AcervoItem>.ok(_item(estado: EstadoAcervo.watched)));
      final _FakeFeedbackRepository feedback =
          _FakeFeedbackRepository(resposta: Result<FeedbackItem>.ok(_sinal()));
      final MarcarAcervoViewModel vm =
          MarcarAcervoViewModel(acervo: acervo, feedback: feedback);

      final bool salvou = await vm.marcarAcervo(TipoMidia.movie, 550, EstadoAcervo.watched);

      expect(salvou, isTrue);
      expect(acervo.estadoRecebido, EstadoAcervo.watched);
      expect(acervo.tipoRecebido, TipoMidia.movie);
      expect(acervo.idRecebido, 550);
      expect(feedback.chamadas, isEmpty,
          reason: 'quem escolheu "assistido" não deu motivo nenhum para gravar');
      expect(vm.erro, isNull);
      expect(vm.salvando, isFalse);
    });

    test('abandono com "sem tempo" grava dislike fraco, origem abandono', () async {
      final _FakeAcervoRepository acervo =
          _FakeAcervoRepository(resposta: Result<AcervoItem>.ok(_item()));
      final _FakeFeedbackRepository feedback =
          _FakeFeedbackRepository(resposta: Result<FeedbackItem>.ok(_sinal(peso: 1)));
      final MarcarAcervoViewModel vm =
          MarcarAcervoViewModel(acervo: acervo, feedback: feedback);

      expect(await vm.marcarAcervo(TipoMidia.tv, 1399, EstadoAcervo.dropped), isTrue);
      await vm.registrarMotivo(TipoMidia.tv, 1399, MotivoAbandono.semTempo);

      expect(acervo.estadoRecebido, EstadoAcervo.dropped, reason: 'o abandono salva antes');
      expect(feedback.sinalRecebido, SinalGosto.dislike);
      expect(feedback.pesoRecebido, 1);
      expect(feedback.origemRecebida, OrigemFeedback.abandono);
      expect(feedback.tipoRecebido, TipoMidia.tv);
      expect(feedback.idRecebido, 1399);
      expect(vm.motivoNaoRegistrado, isFalse);
    });

    test('abandono com "não gostei" veta: peso 2', () async {
      final _FakeAcervoRepository acervo =
          _FakeAcervoRepository(resposta: Result<AcervoItem>.ok(_item()));
      final _FakeFeedbackRepository feedback =
          _FakeFeedbackRepository(resposta: Result<FeedbackItem>.ok(_sinal()));
      final MarcarAcervoViewModel vm =
          MarcarAcervoViewModel(acervo: acervo, feedback: feedback);

      await vm.marcarAcervo(TipoMidia.movie, 550, EstadoAcervo.dropped);
      await vm.registrarMotivo(TipoMidia.movie, 550, MotivoAbandono.naoGostei);

      expect(feedback.pesoRecebido, 2);
      expect(feedback.origemRecebida, OrigemFeedback.abandono);
    });

    test('falha do acervo vira erro na tela e não é sucesso', () async {
      final _FakeAcervoRepository acervo =
          _FakeAcervoRepository(resposta: const Result<AcervoItem>.error(NetworkError()));
      final _FakeFeedbackRepository feedback =
          _FakeFeedbackRepository(resposta: Result<FeedbackItem>.ok(_sinal()));
      final MarcarAcervoViewModel vm =
          MarcarAcervoViewModel(acervo: acervo, feedback: feedback);

      final bool salvou = await vm.marcarAcervo(TipoMidia.movie, 550, EstadoAcervo.dropped);

      expect(salvou, isFalse);
      expect(vm.erro, const NetworkError().mensagem);
      expect(vm.salvando, isFalse);
    });

    test('falha do motivo NÃO desfaz o abandono: aviso, sem erro', () async {
      final _FakeAcervoRepository acervo =
          _FakeAcervoRepository(resposta: Result<AcervoItem>.ok(_item()));
      final _FakeFeedbackRepository feedback =
          _FakeFeedbackRepository(resposta: const Result<FeedbackItem>.error(ServerError()));
      final MarcarAcervoViewModel vm =
          MarcarAcervoViewModel(acervo: acervo, feedback: feedback);

      expect(await vm.marcarAcervo(TipoMidia.movie, 550, EstadoAcervo.dropped), isTrue);
      await vm.registrarMotivo(TipoMidia.movie, 550, MotivoAbandono.naoGostei);

      expect(vm.motivoNaoRegistrado, isTrue,
          reason: 'a tela avisa que o motivo ficou de fora');
      expect(vm.erro, isNull,
          reason: 'o abandono foi salvo: não há erro de acervo para mostrar');
    });

    test('motivo que lança também vira aviso, sem escapar exceção', () async {
      final _FakeAcervoRepository acervo =
          _FakeAcervoRepository(resposta: Result<AcervoItem>.ok(_item()));
      final _FakeFeedbackRepository feedback =
          _FakeFeedbackRepository(lanca: StateError('contrato quebrado'));
      final MarcarAcervoViewModel vm =
          MarcarAcervoViewModel(acervo: acervo, feedback: feedback);

      expect(await vm.marcarAcervo(TipoMidia.movie, 550, EstadoAcervo.dropped), isTrue);
      await vm.registrarMotivo(TipoMidia.movie, 550, MotivoAbandono.semTempo);

      expect(vm.motivoNaoRegistrado, isTrue);
      expect(vm.erro, isNull);
    });

    test('repository que lança não deixa "salvando" preso nem escapa exceção', () async {
      final _FakeAcervoRepository acervo =
          _FakeAcervoRepository(lanca: StateError('contrato quebrado'));
      final _FakeFeedbackRepository feedback =
          _FakeFeedbackRepository(resposta: Result<FeedbackItem>.ok(_sinal()));
      final MarcarAcervoViewModel vm =
          MarcarAcervoViewModel(acervo: acervo, feedback: feedback);

      final bool salvou = await vm.marcarAcervo(TipoMidia.movie, 550, EstadoAcervo.watched);

      expect(salvou, isFalse);
      expect(vm.salvando, isFalse);
      expect(vm.erro, const ServerError().mensagem);
    });

    test('dois toques seguidos viram uma gravação só', () async {
      final _FakeAcervoRepository acervo =
          _FakeAcervoRepository(resposta: Result<AcervoItem>.ok(_item()));
      acervo.segurar = Completer<void>();
      final _FakeFeedbackRepository feedback =
          _FakeFeedbackRepository(resposta: Result<FeedbackItem>.ok(_sinal()));
      final MarcarAcervoViewModel vm =
          MarcarAcervoViewModel(acervo: acervo, feedback: feedback);

      final Future<bool> primeiro = vm.marcarAcervo(TipoMidia.movie, 550, EstadoAcervo.watched);
      final Future<bool> segundo = vm.marcarAcervo(TipoMidia.movie, 550, EstadoAcervo.dropped);

      expect(await segundo, isFalse, reason: 'o segundo toque não duplica a gravação');

      acervo.segurar!.complete();
      expect(await primeiro, isTrue);
      expect(acervo.chamadas, hasLength(1));
    });
  });
}
