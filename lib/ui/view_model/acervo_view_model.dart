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

  bool _isLoading = false;
  String? _error;
  List<AcervoItem> _itens = const <AcervoItem>[];
  Map<String, EstadoAcervo> _estados = const <String, EstadoAcervo>{};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AcervoItem> get itens => _itens;
  int get total => _itens.length;

  /// `null` means "not on the shelf" (or not loaded yet).
  EstadoAcervo? estadoDe(TipoMidia? tipo, int tmdbId) => _estados[chaveEstado(tipo, tmdbId)];

  Future<void> load() async {
    // Reset before asking: this ViewModel is created once at the root, so
    // without it a new account would see the previous one's shelf for a frame.
    _itens = const <AcervoItem>[];
    _estados = const <String, EstadoAcervo>{};
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      switch (await _repository.listar()) {
        case Ok<List<AcervoItem>>(:final value):
          _itens = List<AcervoItem>.unmodifiable(value);
          _estados = _mapaDeEstados(_itens);
        case Error<List<AcervoItem>>(:final error):
          _error = error.mensagem;
      }
    } on Exception catch (error) {
      // Same contract as the other ViewModels: a repository answers a `Result`
      // and never throws. Without the `finally` below, a contract break would
      // leave the shelf loading forever, with no retry.
      debugPrint('[AppSeries] acervo fora do contrato: $error');
      _error = const ServerError().mensagem;
    } finally {
      _isLoading = false;
      notifyListeners();
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
