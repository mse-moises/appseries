import 'package:flutter/foundation.dart';

import '../../data/api_models/tmdb_item.dart';
import '../../data/repositories/titulo_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';
import 'secao_titulos.dart';

/// State of the home screen: two independent carousels.
///
/// Each section has its own loading/error, so a failure in "Populares" still
/// shows "Em alta". Talks only to the repository **contract**.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._repository);

  final TituloRepository _repository;

  // Start loading: this ViewModel is created once at the root, so on the next
  // login the first frame must not draw the previous account's carousels.
  SecaoTitulos _emAlta = const SecaoTitulos(carregando: true);
  SecaoTitulos _populares = const SecaoTitulos(carregando: true);
  int _geracao = 0;

  SecaoTitulos get emAlta => _emAlta;
  SecaoTitulos get populares => _populares;

  /// Clears the previous session's state **without notifying**.
  ///
  /// Called from `initState`, before the first build: notifying there is not
  /// allowed, and without the reset the new account would see the previous
  /// one's titles for a frame. `load()` right after does the notifying.
  void reset() {
    _geracao++;
    _emAlta = const SecaoTitulos(carregando: true);
    _populares = const SecaoTitulos(carregando: true);
  }

  /// Loads both carousels, one after the other.
  ///
  /// Sequential on purpose: "Populares" drops what "Em alta" already shows, so
  /// it needs the first list in hand.
  Future<void> load() async {
    final int geracao = ++_geracao;
    _emAlta = const SecaoTitulos(carregando: true);
    _populares = const SecaoTitulos(carregando: true);
    notifyListeners();

    await _carregaEmAlta(geracao);
    await _carregaPopulares(geracao);
  }

  /// Retry of a single section: the other one keeps what it has.
  Future<void> recarregarEmAlta() => _carregaEmAlta(_geracao);

  Future<void> recarregarPopulares() => _carregaPopulares(_geracao);

  Future<void> _carregaEmAlta(int geracao) async {
    _emAlta = const SecaoTitulos(carregando: true);
    notifyListeners();

    final Result<List<TmdbItem>> resultado = await _resultado(() => _repository.emAlta());
    if (geracao != _geracao) return;

    _emAlta = _secaoDe(resultado);
    notifyListeners();
  }

  Future<void> _carregaPopulares(int geracao) async {
    _populares = const SecaoTitulos(carregando: true);
    notifyListeners();

    final Result<List<TmdbItem>> resultado = await _resultado(() => _repository.populares());
    if (geracao != _geracao) return;

    switch (resultado) {
      case Ok<List<TmdbItem>>(:final value):
        // The TMDB repeats titles between the two lists: the second carousel
        // never shows what the first one already showed.
        final Set<int> jaMostrados = <int>{for (final TmdbItem item in _emAlta.itens) item.id};
        _populares = SecaoTitulos(
          itens: List<TmdbItem>.unmodifiable(
            <TmdbItem>[for (final TmdbItem item in value) if (!jaMostrados.contains(item.id)) item],
          ),
        );
      case Error<List<TmdbItem>>():
        _populares = _secaoDe(resultado);
    }
    notifyListeners();
  }

  /// A repository answers a `Result` and never throws; the guard exists so a
  /// contract break becomes a sentence on the screen instead of a section stuck
  /// in "loading".
  Future<Result<List<TmdbItem>>> _resultado(
    Future<Result<List<TmdbItem>>> Function() chamada,
  ) async {
    try {
      return await chamada();
    } on Exception catch (error) {
      debugPrint('[AppSeries] home fora do contrato: $error');
      return const Result<List<TmdbItem>>.error(ServerError());
    }
  }

  static SecaoTitulos _secaoDe(Result<List<TmdbItem>> resultado) => switch (resultado) {
        Ok<List<TmdbItem>>(:final value) => SecaoTitulos(itens: List<TmdbItem>.unmodifiable(value)),
        Error<List<TmdbItem>>(:final error) => SecaoTitulos(erro: error.mensagem),
      };
}
