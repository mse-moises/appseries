import '../../utils/result.dart';
import '../api_models/tmdb_item.dart';

/// Contract of the catalogue (the two home carousels).
///
/// The ViewModel depends on **this**, never on the implementation: that is what
/// lets a test pass a fake, and what lets a cached/offline version come later
/// without touching the screen.
abstract class TituloRepository {
  Future<Result<List<TmdbItem>>> emAlta();

  Future<Result<List<TmdbItem>>> populares();
}
