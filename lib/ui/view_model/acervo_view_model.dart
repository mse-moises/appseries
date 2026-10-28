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

  /// Titles with a write on its way, by [chaveEstado]. The button reads it to
  /// show progress and refuse a second tap.
  final Set<String> _enviando = <String>{};

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

  bool enviando(TipoMidia tipo, int tmdbId) => _enviando.contains(chaveEstado(tipo, tmdbId));

  /// "Remover" is only offered for a line with `tipo`.
  ///
  /// A line from before migration 008 has no `tipo`, and `DELETE ?tipo=` is not
  /// known to remove it: offering the action would leave the state on screen
  /// after a "success". Changing its state is fine — the typed line it creates
  /// wins in [estadoDe].
  bool podeRemover(TipoMidia tipo, int tmdbId) => _linha(tipo, tmdbId) != null;

  /// Puts a title in a state, at once on screen, and saves it (AP-51).
  ///
  /// Optimistic: the new state shows before the server answers, and the
  /// previous one comes back if it fails. Answers the failure (or `null`) so
  /// the screen can say that it did not save — it never pretends it did.
  Future<AppError?> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado) => _gravar(
        tipo,
        tmdbId,
        otimista: AcervoItem(tmdbId: tmdbId, estado: estado, tipo: tipo),
        chamada: () async => switch (await _repository.marcar(tipo, tmdbId, estado)) {
          // The server's line, with title, year and poster, replaces ours.
          Ok<AcervoItem>(:final value) => (value, null),
          Error<AcervoItem>(:final error) => (null, error),
        },
      );

  /// Takes a title off the shelf: the fifth choice of the detail (AP-48).
  ///
  /// A `404` means it was not there anymore, which is what she asked for.
  Future<AppError?> remover(TipoMidia tipo, int tmdbId) => _gravar(
        tipo,
        tmdbId,
        otimista: null,
        chamada: () async => switch (await _repository.remover(tipo, tmdbId)) {
          Ok<void>() => (null, null),
          Error<void>(error: NotFoundError()) => (null, null),
          Error<void>(:final error) => (null, error),
        },
      );

  /// One write for [marcar] and [remover]: apply, call, keep or roll back.
  ///
  /// The rollback restores only **this** title's line, not a snapshot of the
  /// whole shelf: a snapshot would also undo a write to another title that
  /// finished in between.
  Future<AppError?> _gravar(
    TipoMidia tipo,
    int tmdbId, {
    required AcervoItem? otimista,
    required Future<(AcervoItem?, AppError?)> Function() chamada,
  }) async {
    // A type this app cannot translate has no line to touch, and the server
    // would refuse it: fail before changing anything on screen.
    if (tipo == TipoMidia.desconhecido) return const AcervoIndisponivelError();

    final String chave = chaveEstado(tipo, tmdbId);
    if (_enviando.contains(chave)) return null;

    final int geracao = _geracao;
    final AcervoItem? anterior = _linha(tipo, tmdbId);
    // Where the line was, so a rolled-back removal returns to the same place.
    final int posicao = anterior == null ? 0 : _itens.indexOf(anterior);
    _enviando.add(chave);
    _aplicar(tipo, tmdbId, otimista);
    notifyListeners();

    AppError? erro;
    AcervoItem? salvo;
    try {
      (salvo, erro) = await chamada();
    } catch (error, stack) {
      // `catch`, not `on Exception`: a broken cast is an `Error`, and escaping
      // here would leave the button spinning with the optimistic state.
      debugPrint('[AppSeries] acervo fora do contrato ao gravar: $error\n$stack');
      erro = const ServerError();
    }

    // A sign-out or a reload in between owns the state now: the answer is
    // about a shelf that is no longer on screen.
    if (geracao != _geracao) return erro;

    _enviando.remove(chave);
    if (erro != null) {
      _aplicar(tipo, tmdbId, anterior, posicao: posicao);
    } else if (otimista != null) {
      _aplicar(tipo, tmdbId, salvo ?? otimista);
    }
    notifyListeners();
    return erro;
  }

  /// The typed line of `(tipo, tmdbId)`, if any.
  AcervoItem? _linha(TipoMidia tipo, int tmdbId) {
    for (final AcervoItem item in _itens) {
      if (item.tipo == tipo && item.tmdbId == tmdbId) return item;
    }
    return null;
  }

  /// Replaces (or removes, with `null`) the typed line of `(tipo, tmdbId)`.
  ///
  /// Keeps the list's order (most recent first): a changed line stays where it
  /// was, a new one goes to the top, and a rolled-back removal returns to
  /// [posicao]. An old line without `tipo` is left alone: it is not the one
  /// being written, and the typed line already wins over it in [estadoDe].
  void _aplicar(TipoMidia tipo, int tmdbId, AcervoItem? item, {int posicao = 0}) {
    final List<AcervoItem> lista = List<AcervoItem>.of(_itens);
    final int i = lista.indexWhere((AcervoItem l) => l.tipo == tipo && l.tmdbId == tmdbId);
    if (i >= 0) {
      if (item == null) {
        lista.removeAt(i);
      } else {
        lista[i] = item;
      }
    } else if (item != null) {
      lista.insert(posicao.clamp(0, lista.length), item);
    }
    _itens = List<AcervoItem>.unmodifiable(lista);
    _estados = _mapaDeEstados(_itens);
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
    _enviando.clear();
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
    _enviando.clear();
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
