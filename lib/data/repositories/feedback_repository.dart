import '../../utils/result.dart';
import '../api_models/feedback_item.dart';

/// Contract of the taste signal (👍/👎).
///
/// The same shape as the shelf: the ViewModel depends on this, always gets a
/// `Result`, and a fake can answer in tests without any network.
abstract class FeedbackRepository {
  Future<Result<List<FeedbackItem>>> listar();

  /// Grava ou troca o sinal. `peso` 2 é forte, 1 é fraco (só vale no 👎).
  Future<Result<FeedbackItem>> marcar(
    TipoMidia tipo,
    int tmdbId,
    SinalGosto sinal, {
    int peso = 2,
    OrigemFeedback origem = OrigemFeedback.fechamento,
  });

  /// Apaga o sinal **daquele** tipo; sem o tipo o servidor apaga todas as linhas
  /// daquele id.
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId);
}
