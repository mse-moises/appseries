import '../../utils/result.dart';
import '../api_models/acervo_item.dart';

/// Contract of the shelf resource.
///
/// The ViewModel depends on **this**, never on [AcervoRepositoryImpl] — that is
/// what lets a test pass a fake and what lets a cached/offline implementation
/// come later (AP-77) without touching any screen.
abstract class AcervoRepository {
  Future<Result<List<AcervoItem>>> listar();

  /// Marks a title (creates or updates the line) and answers the saved item.
  /// There is no offline cache yet, so a failure here is a failure the person
  /// sees: the screen cannot pretend the state was saved.
  Future<Result<AcervoItem>> marcar(TipoMidia tipo, int tmdbId, EstadoAcervo estado);

  /// Removes the line of that `(tipo, tmdbId)` only.
  Future<Result<void>> remover(TipoMidia tipo, int tmdbId);
}
