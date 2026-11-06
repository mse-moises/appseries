import '../../utils/result.dart';

/// Local mark of "this account already went through the taste screen" (AP-38).
///
/// It exists because the server cannot tell the two cases apart: skipping and
/// never having seen the screen both leave `generos` empty. Without the mark,
/// whoever skips gets the screen back on every login.
///
/// Per account (by `uid`): another person signing in on the same device still
/// gets their own first access.
abstract class PrimeiroAcessoRepository {
  Future<Result<bool>> jaPassou(String uid);

  Future<Result<void>> marcar(String uid);
}
