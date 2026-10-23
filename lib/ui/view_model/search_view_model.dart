import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/api_models/tmdb_item.dart';
import '../../data/repositories/titulo_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';
import 'filtro_tipo.dart';

export 'filtro_tipo.dart';

/// Where the search screen is. Each one has its own screen: none of them is a
/// blank page.
enum EstadoBusca {
  /// Nothing to ask yet: fewer than [kBuscaMin] letters.
  ocioso,
  carregando,
  resultados,

  /// The server answered and nothing matched (or nothing of the chosen kind).
  vazio,
  erro,
}

/// State of the search screen (AP-44): the query, the server's answer and the
/// kind filter (AP-36).
///
/// The search runs **on the server** (`/busca`), so it reaches the whole
/// catalogue, not only what the home loaded. It waits for her to stop typing
/// before asking: one request per pause, not one per key.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel(this._repository, {this.espera = const Duration(milliseconds: 400)});

  final TituloRepository _repository;

  /// How long to wait after the last key before asking the server.
  final Duration espera;

  Timer? _timer;
  int _geracao = 0;
  String _consulta = '';
  String? _consultaFeita;
  bool _carregando = false;
  AppError? _erro;
  List<TmdbItem> _resultados = const <TmdbItem>[];
  FiltroTipo _filtro = FiltroTipo.todos;

  String get consulta => _consulta;
  FiltroTipo get filtro => _filtro;
  String? get erro => _erro?.mensagem;

  /// Only a failure that asking again can fix gets a retry: an invalid query
  /// would fail the same way.
  bool get podeTentarDeNovo => _erro != null && _erro is! BuscaInvalidaError;

  /// What the server answered, narrowed by the kind filter. Local: switching
  /// the filter does not ask the server again.
  List<TmdbItem> get resultados {
    final tipo = tipoDoFiltro(_filtro);
    if (tipo == null) return _resultados;
    return List<TmdbItem>.unmodifiable(<TmdbItem>[
      for (final TmdbItem item in _resultados)
        if (item.tipo == tipo) item,
    ]);
  }

  EstadoBusca get estado {
    if (_erro != null) return EstadoBusca.erro;
    if (_carregando) return EstadoBusca.carregando;
    if (_consultaFeita == null) return EstadoBusca.ocioso;
    return resultados.isEmpty ? EstadoBusca.vazio : EstadoBusca.resultados;
  }

  /// Called on every key. Short queries never leave the app (the backend would
  /// answer `400 query_too_short`); long ones fail here, with the same sentence.
  void setConsulta(String texto) {
    _consulta = texto;
    final String termo = texto.trim();
    if (termo == _consultaFeita && _erro == null) return;

    // Any change invalidates the request in flight: its answer is about a query
    // that is no longer in the box.
    _timer?.cancel();
    final int geracao = ++_geracao;

    if (termo.length < kBuscaMin) {
      _limparResposta();
      notifyListeners();
      return;
    }
    if (termo.length > kBuscaMax) {
      _limparResposta();
      _erro = const BuscaInvalidaError();
      notifyListeners();
      return;
    }
    // Spinner already while waiting: the old results are about another query.
    _limparResposta();
    _carregando = true;
    notifyListeners();
    _timer = Timer(espera, () => _buscar(termo, geracao));
  }

  void setFiltro(FiltroTipo filtro) {
    if (filtro == _filtro) return;
    _filtro = filtro;
    notifyListeners();
  }

  Future<void> tentarDeNovo() async {
    final String termo = _consulta.trim();
    if (termo.length < kBuscaMin || termo.length > kBuscaMax) return;
    _timer?.cancel();
    final int geracao = ++_geracao;
    _limparResposta();
    _carregando = true;
    notifyListeners();
    await _buscar(termo, geracao);
  }

  /// Clears the previous visit **without notifying** (called from `initState`).
  ///
  /// This ViewModel lives at the root, so without it the screen would open on
  /// the last search, possibly from another account.
  void reset() {
    _timer?.cancel();
    _geracao++;
    _consulta = '';
    _filtro = FiltroTipo.todos;
    _limparResposta();
  }

  Future<void> _buscar(String termo, int geracao) async {
    Result<List<TmdbItem>> resultado;
    try {
      resultado = await _repository.buscar(termo);
    } catch (error, stack) {
      // `catch`, not `on Exception`: a broken cast is an `Error`, and escaping
      // here would leave the screen spinning.
      debugPrint('[AppSeries] busca fora do contrato: $error\n$stack');
      resultado = const Result<List<TmdbItem>>.error(ServerError());
    }
    // A slower answer to an older query must not overwrite the newer one.
    if (geracao != _geracao) return;

    _carregando = false;
    _consultaFeita = termo;
    switch (resultado) {
      case Ok<List<TmdbItem>>(:final value):
        _resultados = List<TmdbItem>.unmodifiable(value);
      case Error<List<TmdbItem>>(:final error):
        _erro = error;
    }
    notifyListeners();
  }

  void _limparResposta() {
    _carregando = false;
    _erro = null;
    _consultaFeita = null;
    _resultados = const <TmdbItem>[];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
