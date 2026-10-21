import '../../utils/result.dart';
import '../api_models/titulo_detalhe.dart';
import '../api_models/tmdb_item.dart';

/// Contract of the catalogue (the two home carousels).
///
/// The ViewModel depends on **this**, never on the implementation: that is what
/// lets a test pass a fake, and what lets a cached/offline version come later
/// without touching the screen.
abstract class TituloRepository {
  Future<Result<List<TmdbItem>>> emAlta();

  Future<Result<List<TmdbItem>>> populares();

  /// Searches the TMDB catalogue. The caller guarantees `q` has 3+ characters.
  Future<Result<List<TmdbItem>>> buscar(String q);

  /// Full sheet of one title; `tipo` disambiguates movie from series.
  Future<Result<TituloDetalhe>> titulo(TipoMidia tipo, int tmdbId);
}
