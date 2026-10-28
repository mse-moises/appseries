import 'package:flutter/foundation.dart';

import '../../data/api_models/tmdb_item.dart';
import '../../data/repositories/titulo_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';
import 'tipo_filtro.dart';
import 'secao_titulos.dart';

export 'tipo_filtro.dart';

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
  SecaoTitulos _popularesCrus = const SecaoTitulos(carregando: true);
  int _geracao = 0;
  TipoFiltro _filtro = TipoFiltro.todos;

  TipoFiltro get filtro => _filtro;

  SecaoTitulos get emAlta => _filtrada(_emAlta);

  /// "Populares" without what "Em alta" already shows.
  ///
  /// Derived on read, not stored: a snapshot taken during the load goes stale as
  /// soon as the other carousel reloads (the server cache is 60 s, the TMDB
  /// changes), and the same title would show in both rows.
  SecaoTitulos get populares => _filtrada(_popularesSemRepetidos);

  SecaoTitulos get _popularesSemRepetidos {
    final SecaoTitulos crus = _popularesCrus;
    if (crus.carregando || crus.erro != null || _emAlta.itens.isEmpty) return crus;

    final Set<String> vistos = <String>{
      for (final TmdbItem item in _emAlta.itens) chaveTitulo(item.tipo, item.id),
    };
    return SecaoTitulos(
      itens: List<TmdbItem>.unmodifiable(<TmdbItem>[
        for (final TmdbItem item in crus.itens)
          if (!vistos.contains(chaveTitulo(item.tipo, item.id))) item,
      ]),
    );
  }

  /// Filters the lists already loaded: no new request, and the two carousels
  /// follow the same choice.
  void setFiltro(TipoFiltro filtro) {
    if (filtro == _filtro) return;
    _filtro = filtro;
    notifyListeners();
  }

  /// Keeps only the titles of the chosen kind, preserving loading and error.
  SecaoTitulos _filtrada(SecaoTitulos secao) {
    final TipoMidia? tipo = tipoDoFiltro(_filtro);
    if (tipo == null) return secao;

    return SecaoTitulos(
      carregando: secao.carregando,
      erro: secao.erro,
      itens: List<TmdbItem>.unmodifiable(<TmdbItem>[
        for (final TmdbItem item in secao.itens)
          if (item.tipo == tipo) item,
      ]),
    );
  }

  /// Clears the previous session's state **without notifying**.
  ///
  /// Called from `initState`, before the first build: notifying there is not
  /// allowed, and without the reset the new account would see the previous one's
  /// titles for a frame. `load()` right after does the notifying.
  ///
  /// The filter goes back to "Todos" too: it is a choice of the previous
  /// account, not of the next one.
  void reset() {
    _geracao++;
    _filtro = TipoFiltro.todos;
    _emAlta = const SecaoTitulos(carregando: true);
    _popularesCrus = const SecaoTitulos(carregando: true);
  }

  /// Loads both carousels, one after the other.
  ///
  /// Sequential on purpose: the second carousel is deduplicated against the
  /// first. The `finally` is what guarantees it still runs when the first one
  /// fails or blows up.
  Future<void> load() async {
    final int geracao = ++_geracao;
    _emAlta = const SecaoTitulos(carregando: true);
    _popularesCrus = const SecaoTitulos(carregando: true);
    notifyListeners();

    try {
      await _carregaEmAlta(geracao);
    } finally {
      await _carregaPopulares(geracao);
    }
  }

  /// Retry of a single section: the other one keeps what it has.
  Future<void> recarregarEmAlta() async {
    // Keep the current items: \"Populares\" is deduplicated against this list, and
    // emptying it here would show the duplicates again while the retry runs.
    _emAlta = SecaoTitulos(carregando: true, itens: _emAlta.itens);
    notifyListeners();
    await _carregaEmAlta(_geracao);
  }

  Future<void> recarregarPopulares() async {
    _popularesCrus = SecaoTitulos(carregando: true, itens: _popularesCrus.itens);
    notifyListeners();
    await _carregaPopulares(_geracao);
  }

  Future<void> _carregaEmAlta(int geracao) async {
    // First thing: a request from a session that already ended must not touch
    // the state at all. Touching it first is what left the section spinning
    // forever, because the answer is discarded right after.
    if (geracao != _geracao) return;

    final Result<List<TmdbItem>> resultado = await _resultado(() => _repository.emAlta());
    if (geracao != _geracao) return;

    _emAlta = _secaoDe(resultado);
    notifyListeners();
  }

  Future<void> _carregaPopulares(int geracao) async {
    if (geracao != _geracao) return;

    final Result<List<TmdbItem>> resultado = await _resultado(() => _repository.populares());
    if (geracao != _geracao) return;

    _popularesCrus = _secaoDe(resultado);
    notifyListeners();
  }

  /// A repository answers a `Result` and never throws; the guard exists so a
  /// contract break becomes a sentence on the screen instead of a section stuck
  /// in "loading".
  ///
  /// `catch` and not `on Exception`: a cast error or a `StateError` is an
  /// `Error`, and it would escape `on Exception` and leave the section loading.
  Future<Result<List<TmdbItem>>> _resultado(
    Future<Result<List<TmdbItem>>> Function() chamada,
  ) async {
    try {
      return await chamada();
    } catch (error, stack) {
      debugPrint('[AppSeries] home fora do contrato: $error\n$stack');
      return const Result<List<TmdbItem>>.error(ServerError());
    }
  }

  static SecaoTitulos _secaoDe(Result<List<TmdbItem>> resultado) => switch (resultado) {
        Ok<List<TmdbItem>>(:final value) => SecaoTitulos(itens: List<TmdbItem>.unmodifiable(value)),
        Error<List<TmdbItem>>(:final error) => SecaoTitulos(erro: error.mensagem),
      };
}
