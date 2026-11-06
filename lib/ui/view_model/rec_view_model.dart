import 'package:flutter/foundation.dart';

import '../../data/api_models/carta_rec.dart';
import '../../data/repositories/rec_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';

/// Estado da tela "O que assistir agora".
///
/// A tela abre **ociosa**: nada é pedido ao servidor até a pessoa tocar em
/// "Recomendar". O teto é de 20 recomendações por dia e cada abertura de tela
/// gastaria uma delas sem ela ter pedido nada.
class RecViewModel extends ChangeNotifier {
  RecViewModel(this._repository);

  final RecRepository _repository;

  bool _carregando = false;
  String? _erro;
  List<CartaRec> _cartas = const <CartaRec>[];
  OrigemRec _origem = OrigemRec.desconhecida;

  /// Distingue "ainda não pedi nada" de "pedi e não veio nada": a tela abre
  /// com o convite, não com a frase de lista vazia.
  bool _buscou = false;

  /// Só a resposta da chamada mais recente escreve no estado.
  int _geracao = 0;

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<CartaRec> get cartas => _cartas;
  OrigemRec get origem => _origem;

  /// Já carregou e o servidor não achou nada: a tela explica, não fica vazia.
  bool get semCartas => _buscou && !_carregando && _erro == null && _cartas.isEmpty;

  /// Limpa o estado da sessão anterior **sem notificar**.
  ///
  /// Chamado do `initState`, antes do primeiro build: notificar ali não é
  /// permitido, e sem o reset a próxima conta veria as cartas da anterior.
  void reset() {
    _geracao++;
    _carregando = false;
    _erro = null;
    _cartas = const <CartaRec>[];
    _origem = OrigemRec.desconhecida;
    _buscou = false;
  }

  /// Pede uma rodada nova. [momento] em branco deixa o servidor usar o momento
  /// salvo nas preferências.
  Future<void> gerar({String? momento}) async {
    // Guarda de reentrância: toque duplo não gasta duas das 20 do dia.
    if (_carregando) return;

    final int geracao = ++_geracao;
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      final Result<RecResult> resultado = await _repository.recomendar(momento: momento);
      if (geracao != _geracao) return;

      switch (resultado) {
        case Ok<RecResult>(:final value):
          _cartas = List<CartaRec>.unmodifiable(value.cartas);
          _origem = value.origem;
          _erro = null;
          _buscou = true;
        case Error<RecResult>(:final error):
          _cartas = const <CartaRec>[];
          _origem = OrigemRec.desconhecida;
          _erro = error.mensagem;
          _buscou = true;
      }
    } catch (error, stack) {
      // O repositório nunca estoura, mas um cast quebrado estouraria: sem este
      // `catch` a tela ficaria girando para sempre.
      if (geracao != _geracao) return;
      debugPrint('[AppSeries] rec fora do contrato: $error\n$stack');
      _cartas = const <CartaRec>[];
      _origem = OrigemRec.desconhecida;
      _erro = const ServerError().mensagem;
    } finally {
      if (geracao == _geracao) {
        _carregando = false;
        notifyListeners();
      }
    }
  }
}
