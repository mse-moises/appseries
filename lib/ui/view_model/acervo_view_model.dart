import 'package:flutter/foundation.dart';

import '../../data/api_models/acervo_item.dart';
import '../../data/repositories/acervo_repository.dart';
import '../../utils/app_error.dart';
import '../../utils/result.dart';

/// State of the user's shelf.
///
/// Owns the list and the lookup that the screens actually use
/// (`estadoDe(tipo, tmdbId)`), and talks only to the repository **contract**.
class AcervoViewModel extends ChangeNotifier {
  AcervoViewModel(this._repository);

  final AcervoRepository _repository;

  // Starts loading: this ViewModel outlives the screen (it is created once in
  // `main.dart`), so on the next login the first frame must not draw the
  // previous account's shelf while the new request is on its way.
  bool _isLoading = true;
  String? _error;
  List<AcervoItem> _itens = const <AcervoItem>[];
  Map<String, EstadoAcervo> _estados = const <String, EstadoAcervo>{};
  int _geracao = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AcervoItem> get itens => _itens;
  int get total => _itens.length;

  /// `null` means "not on the shelf" (or not loaded yet).
  ///
  /// The type is required: the id alone is ambiguous (movie 550 and series 550
  /// are different titles), so a caller that does not know the type cannot ask
  /// this question — it has to wait for the title's data.
  EstadoAcervo? estadoDe(TipoMidia tipo, int tmdbId) {
    if (tipo != TipoMidia.desconhecido) {
      return _estados[chaveEstado(tipo, tmdbId)];
    }
    // A type this app cannot translate: look in both spaces, the same rule the
    // ambiguous line follows on write. Only `null` when it is in neither.
    return _estados[chaveEstado(TipoMidia.movie, tmdbId)] ??
        _estados[chaveEstado(TipoMidia.tv, tmdbId)];
  }

  /// Clears the previous session's state **without notifying**.
  ///
  /// The screen calls this from `initState`, before its first build: the
  /// ViewModel is created once at the root, so on the second login it still
  /// holds the previous account's shelf, and notifying during `initState` is not
  /// allowed. Clearing it here is what keeps the old count off the first frame;
  /// `load()` right after does the notifying.
  void reset() {
    // Also invalidates a request that is still in flight: whoever calls reset
    // does not want an answer from the session that just ended.
    _geracao++;
    _itens = const <AcervoItem>[];
    _estados = const <String, EstadoAcervo>{};
    _error = null;
    _isLoading = true;
  }

  Future<void> load() async {
    // Generation counter: a request from the previous account can answer after
    // the new one (the app does not cancel it on sign-out), and applying it
    // would repopulate the shelf with someone else's titles. Only the newest
    // call is allowed to write state.
    final int geracao = ++_geracao;

    // Reset before asking: without it a new account could see the previous
    // one's shelf while the request is on its way.
    _itens = const <AcervoItem>[];
    _estados = const <String, EstadoAcervo>{};
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Result<List<AcervoItem>> resultado = await _repository.listar();
      if (geracao != _geracao) return;
      switch (resultado) {
        case Ok<List<AcervoItem>>(:final value):
          _itens = List<AcervoItem>.unmodifiable(value);
          _estados = _mapaDeEstados(_itens);
        case Error<List<AcervoItem>>(:final error):
          _error = error.mensagem;
      }
    } on Exception catch (error) {
      if (geracao != _geracao) return;
      // Same contract as the other ViewModels: a repository answers a `Result`
      // and never throws. Without the `finally` below, a contract break would
      // leave the shelf loading forever, with no retry.
      debugPrint('[AppSeries] acervo fora do contrato: $error');
      _error = const ServerError().mensagem;
    } finally {
      if (geracao == _geracao) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Builds the `(tipo, tmdbId) -> estado` lookup.
  ///
  /// A line written before migration 008 has no `tipo`, and we cannot know
  /// which space the id belongs to: it answers for both, the same rule the
  /// backend uses when vetoing recommendations. Typed lines are written last so
  /// they win over the ambiguous one.
  static Map<String, EstadoAcervo> _mapaDeEstados(List<AcervoItem> itens) {
    final Map<String, EstadoAcervo> mapa = <String, EstadoAcervo>{};

    for (final AcervoItem item in itens) {
      if (item.tipo == null || item.tipo == TipoMidia.desconhecido) {
        mapa[chaveEstado(TipoMidia.movie, item.tmdbId)] = item.estado;
        mapa[chaveEstado(TipoMidia.tv, item.tmdbId)] = item.estado;
      }
    }

    for (final AcervoItem item in itens) {
      final TipoMidia? tipo = item.tipo;
      if (tipo != null && tipo != TipoMidia.desconhecido) {
        mapa[chaveEstado(tipo, item.tmdbId)] = item.estado;
      }
    }

    return Map<String, EstadoAcervo>.unmodifiable(mapa);
  }
}
