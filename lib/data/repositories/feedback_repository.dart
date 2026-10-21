import '../../utils/result.dart';
import '../api_models/feedback_item.dart';

/// Contract of the taste signal (👍/👎).
///
/// The same shape as the shelf: the ViewModel depends on this, always gets a
/// `Result`, and a fake can answer in tests without any network.
abstract class FeedbackRepository {
  Future<Result<List<FeedbackItem>>> listar();

  /// Grava ou troca o sinal. `peso` 2 é forte, 1 é fraco (só vale no 👎).
  ///
  /// **Substitui o registro, não faz merge**: um re-PUT sem `origem` grava
  /// `fechamento` e sem `peso` grava 2. Quem quer preservar a origem lê o item
  /// e repassa o valor atual.
  Future<Result<FeedbackItem>> marcar(
    TipoMidia tipo,
    int tmdbId,
    SinalGosto sinal, {
    int peso = 2,
    OrigemFeedback origem = OrigemFeedback.fechamento,
  });

  /// Apaga o sinal **daquele** tipo (o `tipo` é obrigatório aqui, então o app
  /// nunca apaga os dois tipos de uma vez).
  ///
  /// O backend responde `404 not_found` quando o sinal já não estava lá: para
  /// quem chama, isso é o objetivo alcançado — a tela pode tratar como sucesso.
  ///
  /// `tipo` é obrigatório: um `FeedbackItem` com `tipo` nulo (linha anterior à
  /// migração 008) não tem como ser removido por aqui, então a tela não deve
  /// oferecer a ação para ele.
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId);
}
