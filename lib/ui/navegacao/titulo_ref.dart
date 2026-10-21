import '../../data/api_models/tipo_midia.dart';

export '../../data/api_models/tipo_midia.dart';

/// What the screens pass to `/detalhe`: the pair `(tipo, id)`.
///
/// Not a `Map<String, dynamic>`: the TMDB numbers movie and series separately,
/// so an `int` alone is ambiguous, and a typed object makes the mistake a
/// compile error instead of a runtime one.
class TituloRef {
  const TituloRef({required this.tipo, required this.id});

  final TipoMidia tipo;
  final int id;

  String get chave => chaveTitulo(tipo, id);

  @override
  String toString() => 'TituloRef(${tipo.name}, $id)';
}
