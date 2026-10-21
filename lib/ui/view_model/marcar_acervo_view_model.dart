import 'package:flutter/foundation.dart';

import '../../data/api_models/acervo_item.dart';
import '../../data/api_models/feedback_item.dart';
import '../../data/api_models/motivo_abandono.dart';
import '../../data/repositories/acervo_repository.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';

/// Salva a marcação do acervo e, quando a escolha é "abandonei", o motivo.
///
/// O motivo não tem coluna no acervo: ele vira o **peso** do sinal de gosto
/// (`dislike`, origem `abandono`), que é o único dado que a recomendação lê.
/// "Sem tempo" é fraco (informa, não veta) e "Não gostei" é forte (veta).
///
/// São **duas** gravações independentes de propósito: o abandono vale por si,
/// e uma falha ao registrar o motivo não desfaz o estado nem trava a tela.
class MarcarAcervoViewModel extends ChangeNotifier {
  MarcarAcervoViewModel({
    required AcervoRepository acervo,
    required FeedbackRepository feedback,
  })  : _acervo = acervo,
        _feedback = feedback;

  final AcervoRepository _acervo;
  final FeedbackRepository _feedback;

  bool _salvando = false;
  String? _erro;
  bool _motivoNaoRegistrado = false;

  bool get salvando => _salvando;

  /// Frase para a tela quando o **acervo** não salvou (o abandono em si falhou).
  String? get erro => _erro;

  /// O abandono foi salvo, mas o motivo não: a tela avisa e nada é desfeito.
  bool get motivoNaoRegistrado => _motivoNaoRegistrado;

  void limparAvisos() {
    _erro = null;
    _motivoNaoRegistrado = false;
  }

  /// Grava o estado. Devolve `false` quando não salvou — por falha (o motivo
  /// está em [erro]) ou por já haver uma gravação em curso (aí é silencioso).
  Future<bool> marcarAcervo(TipoMidia tipo, int tmdbId, EstadoAcervo estado) async {
    // Reentrância: dois toques seguidos no menu não podem virar duas gravações
    // com resultados fora de ordem.
    if (_salvando) return false;

    _salvando = true;
    _erro = null;
    _motivoNaoRegistrado = false;
    notifyListeners();

    try {
      final Result<AcervoItem> resultado = await _acervo.marcar(tipo, tmdbId, estado);
      switch (resultado) {
        case Ok<AcervoItem>():
          return true;
        case Error<AcervoItem>(:final error):
          _erro = error.mensagem;
          return false;
      }
    } catch (error) {
      // O contrato do repository é responder `Result` e não lançar; se ele
      // quebrar, a tela não pode ficar sem saber (nem o `salvando` preso).
      debugPrint('[AppSeries] acervo fora do contrato: $error');
      _erro = const ServerError().mensagem;
      return false;
    } finally {
      _salvando = false;
      notifyListeners();
    }
  }

  /// Grava o motivo como peso do gosto. Só faz sentido depois de [marcarAcervo]
  /// com [EstadoAcervo.dropped] ter dado certo — quem chama é que ordena.
  ///
  /// Uma falha aqui **não** apaga o abandono: marca [motivoNaoRegistrado].
  Future<void> registrarMotivo(TipoMidia tipo, int tmdbId, MotivoAbandono motivo) async {
    try {
      final Result<FeedbackItem> resultado = await _feedback.marcar(
        tipo,
        tmdbId,
        SinalGosto.dislike,
        peso: motivo.peso,
        origem: OrigemFeedback.abandono,
      );
      switch (resultado) {
        case Ok<FeedbackItem>():
          _motivoNaoRegistrado = false;
        case Error<FeedbackItem>(:final error):
          debugPrint('[AppSeries] motivo do abandono não registrado: ${error.codigo}');
          _motivoNaoRegistrado = true;
      }
    } catch (error) {
      debugPrint('[AppSeries] feedback fora do contrato: $error');
      _motivoNaoRegistrado = true;
    }
    notifyListeners();
  }
}
