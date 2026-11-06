import '../../utils/result.dart';
import '../api_models/carta_rec.dart';

/// Contrato da recomendação por momento.
///
/// A tela depende desta interface, então ela pode ser construída e testada com
/// dublê antes de exercitar o servidor.
abstract class RecRepository {
  /// Sem [momento] (ou com ele em branco) o servidor usa o momento salvo nas
  /// preferências; com [momento] ele vale **só nesta chamada**.
  Future<Result<RecResult>> recomendar({String? momento});
}
