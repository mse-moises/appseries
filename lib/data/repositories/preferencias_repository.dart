import '../../utils/result.dart';
import '../api_models/preferencias.dart';

/// Contract of the person's taste (moment + genres).
///
/// The screen depends on this, so the onboarding (AP-37) can be built against a
/// fake before the endpoint is exercised.
abstract class PreferenciasRepository {
  Future<Result<Preferencias>> ler();

  Future<Result<Preferencias>> salvar(Preferencias preferencias);
}
