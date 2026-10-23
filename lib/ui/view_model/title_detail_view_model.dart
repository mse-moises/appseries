import 'package:flutter/foundation.dart';

import '../../data/api_models/acervo_item.dart';
import '../../data/api_models/feedback_item.dart';
import '../../data/api_models/titulo_detalhe.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/repositories/titulo_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';
import '../navegacao/titulo_ref.dart';

/// State of the detail page (AP-47 / AP-48): the title's sheet and her 👍/👎.
///
/// The shelf state is **not** here: it lives in `AcervoViewModel`, shared with
/// the home and the search, so a mark made on the detail shows everywhere. The
/// page passes that state in when it matters ([darSinal]).
class TitleDetailViewModel extends ChangeNotifier {
  TitleDetailViewModel(this._titulos, this._feedback);

  final TituloRepository _titulos;
  final FeedbackRepository _feedback;

  TituloRef? _ref;
  int _geracao = 0;
  bool _carregando = true;
  AppError? _erro;
  TituloDetalhe? _detalhe;
  SinalGosto? _sinal;
  bool _enviandoSinal = false;

  bool get carregando => _carregando;
  String? get erro => _erro?.mensagem;
  TituloDetalhe? get detalhe => _detalhe;

  /// Her current 👍/👎 on this title, or `null`.
  SinalGosto? get sinal => _sinal;
  bool get enviandoSinal => _enviandoSinal;

  /// Only a failure that asking again can fix gets a retry: a title without a
  /// valid pair would fail the same way.
  bool get podeTentarDeNovo => _erro != null && _erro is! TituloIndisponivelError;

  /// Clears the previous title **without notifying** (called from `initState`).
  ///
  /// Lives at the root, so without it the page would open on the last title,
  /// possibly from another account, for a frame.
  void reset() {
    _geracao++;
    _ref = null;
    _carregando = true;
    _erro = null;
    _detalhe = null;
    _sinal = null;
    _enviandoSinal = false;
  }

  /// Loads the sheet of `ref`. `null` (a route opened without arguments) is an
  /// error screen, never a blank one.
  Future<void> load(TituloRef? ref) async {
    final int geracao = ++_geracao;
    _ref = ref;
    _carregando = true;
    _erro = null;
    _detalhe = null;
    _sinal = null;
    notifyListeners();

    if (ref == null) {
      _erro = const TituloIndisponivelError();
      _carregando = false;
      notifyListeners();
      return;
    }

    // Both at once: the signal is a detail of the page, not a step before it.
    final Future<Result<TituloDetalhe>> ficha = _seguro(() => _titulos.titulo(ref.tipo, ref.id));
    final Future<SinalGosto?> sinal = _sinalDe(ref);
    final Result<TituloDetalhe> resultado = await ficha;
    final SinalGosto? sinalAtual = await sinal;
    if (geracao != _geracao) return;

    switch (resultado) {
      case Ok<TituloDetalhe>(:final value):
        _detalhe = value;
        _sinal = sinalAtual;
      case Error<TituloDetalhe>(:final error):
        _erro = error;
    }
    _carregando = false;
    notifyListeners();
  }

  Future<void> tentarDeNovo() => load(_ref);

  /// 👍 or 👎 (AP-48). Tapping the signal she already gave takes it back.
  ///
  /// The origin follows the card: given after "Abandonei" it is `abandono` —
  /// so "não curti" on an abandoned title is a strong 👎 that vetoes it from the
  /// recommendations — and otherwise `fechamento`. Weight is always 2 here: the
  /// weak 👎 ("sem tempo") is not offered on this page.
  ///
  /// Answers the failure (or `null`) for the page to say it did not save; the
  /// signal on screen only changes when the server confirms.
  Future<AppError?> darSinal(SinalGosto escolhido, {required EstadoAcervo? estado}) async {
    final TituloRef? ref = _ref;
    if (ref == null || _detalhe == null || _enviandoSinal) return null;

    final int geracao = _geracao;
    _enviandoSinal = true;
    notifyListeners();

    final bool desfazer = escolhido == _sinal;
    AppError? erro;
    SinalGosto? novo = _sinal;
    try {
      if (desfazer) {
        switch (await _feedback.remover(ref.tipo, ref.id)) {
          // 404: it was not there anymore, which is what she asked for.
          case Ok<void>() || Error<void>(error: NotFoundError()):
            novo = null;
          case Error<void>(:final error):
            erro = error;
        }
      } else {
        final OrigemFeedback origem =
            estado == EstadoAcervo.dropped ? OrigemFeedback.abandono : OrigemFeedback.fechamento;
        switch (await _feedback.marcar(ref.tipo, ref.id, escolhido, origem: origem)) {
          case Ok<FeedbackItem>(:final value):
            novo = value.sinal;
          case Error<FeedbackItem>(:final error):
            erro = error;
        }
      }
    } catch (error, stack) {
      debugPrint('[AppSeries] feedback fora do contrato: $error\n$stack');
      erro = const ServerError();
    }

    if (geracao != _geracao) return erro;
    _enviandoSinal = false;
    // On failure `novo` is still the previous signal: the screen keeps it.
    _sinal = novo;
    notifyListeners();
    return erro;
  }

  /// Her signal on this exact `(tipo, id)`. A failure here does not take the
  /// page down: the sheet is what she came for, and the buttons start empty.
  Future<SinalGosto?> _sinalDe(TituloRef ref) async {
    try {
      final Result<List<FeedbackItem>> lista = await _feedback.listar();
      for (final FeedbackItem item in lista.valueOrNull ?? const <FeedbackItem>[]) {
        if (item.tipo == ref.tipo && item.tmdbId == ref.id) return item.sinal;
      }
    } catch (error) {
      debugPrint('[AppSeries] feedback fora do contrato ao listar: $error');
    }
    return null;
  }

  /// A repository answers a `Result` and never throws; the guard keeps a
  /// contract break from leaving the page spinning.
  static Future<Result<TituloDetalhe>> _seguro(
    Future<Result<TituloDetalhe>> Function() chamada,
  ) async {
    try {
      return await chamada();
    } catch (error, stack) {
      debugPrint('[AppSeries] detalhe fora do contrato: $error\n$stack');
      return const Result<TituloDetalhe>.error(ServerError());
    }
  }
}
