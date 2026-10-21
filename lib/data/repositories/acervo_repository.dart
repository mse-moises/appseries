import '../../utils/result.dart';
import '../api_models/acervo_item.dart';

/// Contract of the shelf resource.
///
/// The ViewModel depends on **this**, never on [AcervoRepositoryImpl] — that is
/// what lets a test pass a fake and what lets a cached/offline implementation
/// come later (AP-77) without touching any screen.
abstract class AcervoRepository {
  Future<Result<List<AcervoItem>>> listar();
}
