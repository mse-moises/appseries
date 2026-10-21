import '../../data/api_models/tmdb_item.dart';

/// Immutable state of one carousel.
///
/// One section failing must not take the other down, so each carousel owns its
/// own loading/error/list instead of the screen having a single state.
class SecaoTitulos {
  const SecaoTitulos({
    this.carregando = false,
    this.erro,
    this.itens = const <TmdbItem>[],
  });

  final bool carregando;
  final String? erro;
  final List<TmdbItem> itens;

  /// Loaded, without error and without titles: the section shows "nada aqui".
  bool get vazio => !carregando && erro == null && itens.isEmpty;
}
